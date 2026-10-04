import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';

import '../theme.dart';

/// Caps how many files are decoded at once so scrolling the grid stays smooth.
abstract final class _DecodeGate {
  static const _maxActive = 3;
  static int _active = 0;
  static final _waiting = Queue<Completer<void>>();

  static Future<void> acquire() async {
    if (_active < _maxActive) {
      _active++;
      return;
    }
    final completer = Completer<void>();
    _waiting.add(completer);
    await completer.future;
  }

  static void release() {
    if (_waiting.isNotEmpty) {
      _waiting.removeFirst().complete();
    } else {
      _active--;
    }
  }
}

/// A muted, looping preview of an SVGA file for use in the grid.
class SvgaThumb extends StatefulWidget {
  const SvgaThumb({
    super.key,
    required this.path,
    this.animate = true,
    this.onDecoded,
  });

  final String path;
  final ValueChanged<MovieEntity>? onDecoded;

  /// When false only the first frame is shown.
  final bool animate;

  @override
  State<SvgaThumb> createState() => _SvgaThumbState();
}

class _SvgaThumbState extends State<SvgaThumb>
    with SingleTickerProviderStateMixin {
  late final SVGAAnimationController _controller = SVGAAnimationController(
    vsync: this,
  )..isMute = true;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _DecodeGate.acquire();
    try {
      if (!mounted) return;
      final bytes = await File(widget.path).readAsBytes();
      final movie = await SVGAParser.shared.decodeFromBuffer(bytes);
      if (!mounted) {
        movie.dispose();
        return;
      }
      widget.onDecoded?.call(movie);
      _controller.videoItem = movie;
      if (widget.animate) _controller.repeat();
      setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      _DecodeGate.release();
    }
  }

  @override
  void didUpdateWidget(SvgaThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_ready || oldWidget.animate == widget.animate) return;
    if (widget.animate) {
      _controller.repeat();
    } else {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (_failed) {
      child = const Center(
        child: Icon(Icons.broken_image_outlined, color: AppColors.textMuted),
      );
    } else if (!_ready) {
      child = const Center(
        child: SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.textMuted,
          ),
        ),
      );
    } else {
      child = RepaintBoundary(
        child: SVGAImage(_controller, clearsAfterStop: false),
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: SizedBox.expand(key: ValueKey(_ready || _failed), child: child),
    );
  }
}
