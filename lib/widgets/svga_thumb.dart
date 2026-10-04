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

  // Tiles just outside the viewport are kept alive (and decoded) by the
  // grid's cache area, but only the ones actually on screen animate.
  ScrollPosition? _position;
  bool _onScreen = true;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Started here rather than in initState because it looks up the
    // enclosing Scrollable.
    if (!_started) {
      _started = true;
      _load();
    }
    final position = Scrollable.maybeOf(context)?.position;
    if (position == _position) return;
    _position?.removeListener(_checkOnScreen);
    _position = position?..addListener(_checkOnScreen);
  }

  void _checkOnScreen() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return;
    final view = View.of(context);
    final screenHeight = view.physicalSize.height / view.devicePixelRatio;
    final top = box.localToGlobal(Offset.zero).dy;
    _onScreen = top + box.size.height > 0 && top < screenHeight;
    _syncPlayback();
  }

  void _syncPlayback() {
    if (!_ready) return;
    final shouldPlay = widget.animate && _onScreen;
    if (shouldPlay == _controller.isAnimating) return;
    if (shouldPlay) {
      _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  Future<void> _load() async {
    // Don't decode tiles that are only flying past during a fast scroll.
    while (mounted && Scrollable.recommendDeferredLoadingForContext(context)) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
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
      setState(() => _ready = true);
      // Layout may not have happened yet, so check once this frame is done.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _checkOnScreen();
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      _DecodeGate.release();
    }
  }

  @override
  void didUpdateWidget(SvgaThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The grid can move tiles on or off screen without a scroll (a filter
    // change, a deleted item), so re-check after it has laid out again.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkOnScreen();
    });
    if (!_ready || oldWidget.animate == widget.animate) return;
    _syncPlayback();
    if (!widget.animate) _controller.value = 0;
  }

  @override
  void dispose() {
    _position?.removeListener(_checkOnScreen);
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
