import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';

/// A `.svga` file found on device storage.
typedef ScannedFile = ({String path, int bytes, DateTime modified});

/// Finds every `.svga` file on shared storage (Android only).
abstract final class DeviceScanner {
  static const _channel = MethodChannel('svga_gallery/storage');

  static bool get supported => Platform.isAndroid;

  static Future<bool> hasAccess() async =>
      await _channel.invokeMethod<bool>('hasAccess') ?? false;

  /// Asks for storage access. On Android 11+ this opens the system "All files
  /// access" screen and returns false; check [hasAccess] again on resume.
  static Future<bool> requestAccess() async =>
      await _channel.invokeMethod<bool>('requestAccess') ?? false;

  static Future<List<ScannedFile>> scan() async {
    final roots = await _channel.invokeListMethod<String>('roots') ?? const [];
    return Isolate.run(() => _walk(roots));
  }

  static List<ScannedFile> _walk(List<String> roots) {
    final found = <ScannedFile>[];
    final pending = [for (final root in roots) Directory(root)];
    while (pending.isNotEmpty) {
      final dir = pending.removeLast();
      final List<FileSystemEntity> entries;
      try {
        entries = dir.listSync(followLinks: false);
      } on FileSystemException {
        continue; // Not readable; skip just this folder.
      }
      for (final entity in entries) {
        final path = entity.path;
        if (entity is Directory) {
          // Other apps' private folders are off limits even with full access.
          if (path.endsWith('/Android/data') || path.endsWith('/Android/obb')) {
            continue;
          }
          pending.add(entity);
        } else if (entity is File && path.toLowerCase().endsWith('.svga')) {
          try {
            final stat = entity.statSync();
            found.add((path: path, bytes: stat.size, modified: stat.modified));
          } on FileSystemException {
            // Vanished mid-scan.
          }
        }
      }
    }
    return found;
  }
}
