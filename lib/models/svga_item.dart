class SvgaItem {
  SvgaItem({
    required this.id,
    required this.name,
    required this.fileName,
    required this.bytes,
    required this.addedAt,
    this.favorite = false,
    this.source,
    this.externalPath,
    this.width = 0,
    this.height = 0,
    this.fps = 0,
    this.frames = 0,
  });

  final String id;
  String name;

  /// File name inside the library directory (the absolute path is not stored
  /// because the app container path can change between installs).
  final String fileName;
  final int bytes;
  final DateTime addedAt;
  bool favorite;

  /// URL the animation was downloaded from, if any.
  final String? source;

  /// Set for files found by the device scan: they stay where they are instead
  /// of being copied into the library directory.
  final String? externalPath;

  // Zero until the file has been decoded once (device files are not decoded
  // during the scan).
  int width;
  int height;
  int fps;
  int frames;

  bool get onDevice => externalPath != null;
  bool get hasMeta => frames > 0;

  Duration get duration => fps <= 0
      ? Duration.zero
      : Duration(milliseconds: (frames / fps * 1000).round());

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'fileName': fileName,
    'bytes': bytes,
    'addedAt': addedAt.millisecondsSinceEpoch,
    'favorite': favorite,
    if (source != null) 'source': source,
    if (externalPath != null) 'externalPath': externalPath,
    'width': width,
    'height': height,
    'fps': fps,
    'frames': frames,
  };

  factory SvgaItem.fromJson(Map<String, dynamic> json) => SvgaItem(
    id: json['id'] as String,
    name: json['name'] as String,
    fileName: json['fileName'] as String,
    bytes: json['bytes'] as int,
    addedAt: DateTime.fromMillisecondsSinceEpoch(json['addedAt'] as int),
    favorite: json['favorite'] as bool? ?? false,
    source: json['source'] as String?,
    externalPath: json['externalPath'] as String?,
    width: json['width'] as int? ?? 0,
    height: json['height'] as int? ?? 0,
    fps: json['fps'] as int? ?? 0,
    frames: json['frames'] as int? ?? 0,
  );
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String formatSeconds(Duration d) =>
    '${(d.inMilliseconds / 1000).toStringAsFixed(1)}s';
