import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/svga_item.dart';
import 'device_scanner.dart';

class ImportResult {
  const ImportResult({this.added = 0, this.duplicates = 0, this.failed = 0});

  final int added;
  final int duplicates;
  final int failed;

  ImportResult operator +(ImportResult other) => ImportResult(
    added: added + other.added,
    duplicates: duplicates + other.duplicates,
    failed: failed + other.failed,
  );

  String get message {
    final parts = <String>[
      if (added > 0) 'Added $added animation${added == 1 ? '' : 's'}',
      if (duplicates > 0) '$duplicates already in gallery',
      if (failed > 0) '$failed not a valid SVGA 2.x file',
    ];
    return parts.isEmpty ? 'Nothing to import' : parts.join(' · ');
  }
}

/// The user's SVGA library: files copied into app storage plus a JSON index.
class LibraryStore extends ChangeNotifier {
  LibraryStore._(this._prefs, this._dir);

  static const _indexKey = 'library_v1';
  static const _liveKey = 'live_previews';
  static const _denseKey = 'dense_grid';

  static const sampleBaseUrl =
      'https://raw.githubusercontent.com/svga/SVGA-Samples/master/';
  static const sampleNames = [
    'angel',
    'rose',
    'kingset',
    'posche',
    'heartbeat',
    'halloween',
    'EmptyState',
    'TwitterHeart',
    'Walkthrough',
    'PinJump',
  ];

  final SharedPreferences _prefs;
  final Directory _dir;
  final List<SvgaItem> _items = [];
  int _idCounter = 0;

  /// Non-null while a long-running import is in progress.
  String? busyLabel;

  /// Whether the app may read shared storage (always false off Android).
  bool deviceAccess = false;
  bool _scanning = false;

  /// Device files are left out while storage access is missing: they cannot
  /// be read, and come back untouched (favorites included) once it returns.
  List<SvgaItem> get items =>
      List.unmodifiable(_items.where((e) => deviceAccess || !e.onDevice));
  int get totalBytes => items.fold(0, (sum, e) => sum + e.bytes);

  bool get livePreviews => _prefs.getBool(_liveKey) ?? true;
  set livePreviews(bool value) {
    _prefs.setBool(_liveKey, value);
    notifyListeners();
  }

  bool get denseGrid => _prefs.getBool(_denseKey) ?? false;
  set denseGrid(bool value) {
    _prefs.setBool(_denseKey, value);
    notifyListeners();
  }

  static Future<LibraryStore> open() async {
    final prefs = await SharedPreferences.getInstance();
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'library'));
    await dir.create(recursive: true);
    final store = LibraryStore._(prefs, dir);
    if (DeviceScanner.supported) {
      store.deviceAccess = await DeviceScanner.hasAccess();
    }
    final raw = prefs.getString(_indexKey);
    if (raw != null) {
      for (final entry in jsonDecode(raw) as List) {
        final item = SvgaItem.fromJson(entry as Map<String, dynamic>);
        // Device files are reconciled by [syncDevice], which also knows
        // whether storage access is currently granted.
        if (item.onDevice || File(store.pathOf(item)).existsSync()) {
          store._items.add(item);
        }
      }
    }
    return store;
  }

  String pathOf(SvgaItem item) =>
      item.externalPath ?? p.join(_dir.path, item.fileName);

  String _newId() => '${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';

  /// Re-checks storage access and, when granted, mirrors every `.svga` file
  /// on the device into the gallery. Returns how many new files were found.
  Future<int> syncDevice() async {
    if (!DeviceScanner.supported || _scanning || busyLabel != null) return 0;
    _scanning = true;
    try {
      deviceAccess = await DeviceScanner.hasAccess();
      if (!deviceAccess) {
        notifyListeners();
        return 0;
      }
      _setBusy('Scanning device…');
      final found = {for (final f in await DeviceScanner.scan()) f.path: f};
      _items.removeWhere(
        (e) => e.onDevice && !found.containsKey(e.externalPath),
      );
      final known = {for (final e in _items) e.externalPath};
      var added = 0;
      for (final file in found.values) {
        if (known.contains(file.path)) continue;
        _items.add(
          SvgaItem(
            id: _newId(),
            name: p.basenameWithoutExtension(file.path),
            fileName: '',
            bytes: file.bytes,
            addedAt: file.modified,
            externalPath: file.path,
          ),
        );
        added++;
      }
      await _save();
      return added;
    } finally {
      _scanning = false;
      _setBusy(null);
    }
  }

  Future<void> requestDeviceAccess() async {
    if (await DeviceScanner.requestAccess()) await syncDevice();
  }

  /// Fills in metadata for items that were added without being decoded.
  void updateMeta(SvgaItem item, MovieEntity movie) {
    if (item.hasMeta || !_items.contains(item)) return;
    final params = movie.params;
    item
      ..width = params.viewBoxWidth.round()
      ..height = params.viewBoxHeight.round()
      ..fps = params.fps == 0 ? 20 : params.fps
      ..frames = params.frames;
    notifyListeners();
    _save();
  }

  Future<void> _save() => _prefs.setString(
    _indexKey,
    jsonEncode(_items.map((e) => e.toJson()).toList()),
  );

  Future<ImportResult> importFiles(List<String> paths) async {
    var result = const ImportResult();
    _setBusy('Importing…');
    try {
      for (final path in paths) {
        try {
          final bytes = await File(path).readAsBytes();
          result += await _importBytes(p.basenameWithoutExtension(path), bytes);
        } catch (_) {
          result += const ImportResult(failed: 1);
        }
      }
    } finally {
      _setBusy(null);
    }
    return result;
  }

  Future<ImportResult> importUrl(String url) async {
    _setBusy('Downloading…');
    try {
      return await _importUrl(url);
    } finally {
      _setBusy(null);
    }
  }

  Future<ImportResult> importSamples() async {
    var result = const ImportResult();
    try {
      for (var i = 0; i < sampleNames.length; i++) {
        _setBusy('Downloading samples ${i + 1}/${sampleNames.length}…');
        result += await _importUrl('$sampleBaseUrl${sampleNames[i]}.svga');
      }
    } finally {
      _setBusy(null);
    }
    return result;
  }

  Future<ImportResult> _importUrl(String url) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse(url);
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        return const ImportResult(failed: 1);
      }
      final bytes = await consolidateHttpClientResponseBytes(response);
      final segment = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
      final name = p.basenameWithoutExtension(segment);
      return await _importBytes(
        name.isEmpty ? 'animation' : name,
        bytes,
        source: url,
      );
    } catch (_) {
      return const ImportResult(failed: 1);
    } finally {
      client.close();
    }
  }

  Future<ImportResult> _importBytes(
    String name,
    Uint8List bytes, {
    String? source,
  }) async {
    if (_items.any((e) => e.name == name && e.bytes == bytes.length)) {
      return const ImportResult(duplicates: 1);
    }
    // Decoding validates the file and gives us its metadata up front.
    final MovieEntity movie;
    try {
      movie = await SVGAParser.shared.decodeFromBuffer(bytes);
    } catch (_) {
      return const ImportResult(failed: 1);
    }
    final params = movie.params;
    final id = _newId();
    final item = SvgaItem(
      id: id,
      name: name,
      fileName: '$id.svga',
      bytes: bytes.length,
      addedAt: DateTime.now(),
      source: source,
      width: params.viewBoxWidth.round(),
      height: params.viewBoxHeight.round(),
      fps: params.fps == 0 ? 20 : params.fps,
      frames: params.frames,
    );
    movie.dispose();
    await File(pathOf(item)).writeAsBytes(bytes, flush: true);
    _items.add(item);
    await _save();
    notifyListeners();
    return const ImportResult(added: 1);
  }

  Future<void> toggleFavorite(SvgaItem item) async {
    item.favorite = !item.favorite;
    notifyListeners();
    await _save();
  }

  Future<void> rename(SvgaItem item, String name) async {
    item.name = name;
    notifyListeners();
    await _save();
  }

  Future<void> delete(SvgaItem item) async {
    _items.remove(item);
    notifyListeners();
    await _save();
    try {
      final file = File(pathOf(item));
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // A device file we may not delete; the next scan brings it back.
    }
  }

  void _setBusy(String? label) {
    busyLabel = label;
    notifyListeners();
  }
}
