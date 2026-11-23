import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Files the operating system hands to the app: "Open with" on Android,
/// Windows and macOS, and the Android share sheet.
///
/// The native side queues files until [listen] asks for them, so files the
/// app was launched with are not lost while Flutter starts.
abstract final class OpenedFiles {
  static const _channel = MethodChannel('svga_gallery/open');

  static bool get supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isWindows || Platform.isMacOS);

  /// Calls [onFiles] with the files the app was launched with, then again
  /// each time the running app is asked to open more.
  static Future<void> listen(ValueChanged<List<String>> onFiles) async {
    if (!supported) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'open') _deliver(call.arguments, onFiles);
    });
    try {
      _deliver(await _channel.invokeMethod<Object?>('takePending'), onFiles);
    } on MissingPluginException {
      // A runner without the channel (tests, an older native build).
    }
  }

  static void _deliver(Object? arguments, ValueChanged<List<String>> onFiles) {
    final paths = [
      if (arguments is List)
        for (final path in arguments)
          if (path is String && path.isNotEmpty) path,
    ];
    if (paths.isNotEmpty) onFiles(paths);
  }
}
