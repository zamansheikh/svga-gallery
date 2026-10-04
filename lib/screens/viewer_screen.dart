import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';

import '../data/library_store.dart';
import '../models/svga_item.dart';
import '../theme.dart';
import '../widgets/dialogs.dart';
import '../widgets/item_actions.dart';
import '../widgets/preview_backdrop.dart';

const _speeds = [0.5, 1.0, 2.0];

/// Full-screen player; swipe horizontally to move between [items].
class ViewerScreen extends StatefulWidget {
  const ViewerScreen({
    super.key,
    required this.store,
    required this.items,
    required this.initialIndex,
  });

  final LibraryStore store;
  final List<SvgaItem> items;
  final int initialIndex;

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  late final List<SvgaItem> _items = List.of(widget.items);
  late int _index = widget.initialIndex;
  late final _pages = PageController(initialPage: widget.initialIndex);

  // Playback settings are shared by every page so they survive swiping.
  PreviewBackdrop _backdrop = PreviewBackdrop.checker;
  bool _loop = true;
  bool _muted = false;
  double _speed = 1.0;

  SvgaItem get _current => _items[_index];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final item = _current;
    if (!await confirmDelete(context, widget.store, item) || !mounted) return;
    if (_items.length == 1) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _items.remove(item);
      if (_index >= _items.length) _index = _items.length - 1;
    });
  }

  PopupMenuItem<VoidCallback> _menuItem(
    IconData icon,
    String label,
    VoidCallback action,
  ) {
    return PopupMenuItem(
      value: action,
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }

  void _cycleSpeed() {
    final next = (_speeds.indexOf(_speed) + 1) % _speeds.length;
    setState(() => _speed = _speeds[next]);
  }

  @override
  Widget build(BuildContext context) {
    final onLight =
        _backdrop == PreviewBackdrop.light || _backdrop == PreviewBackdrop.mint;
    final foreground = onLight ? Colors.black87 : Colors.white;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: onLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) {
            final item = _current;
            return Stack(
              children: [
                PageView.builder(
                  controller: _pages,
                  itemCount: _items.length,
                  onPageChanged: (index) => setState(() => _index = index),
                  itemBuilder: (context, index) {
                    final pageItem = _items[index];
                    return _ViewerPage(
                      key: ValueKey(pageItem.id),
                      item: pageItem,
                      path: widget.store.pathOf(pageItem),
                      onDecoded: (movie) =>
                          widget.store.updateMeta(pageItem, movie),
                      backdrop: _backdrop,
                      loop: _loop,
                      muted: _muted,
                      speed: _speed,
                      onBackdrop: (value) => setState(() => _backdrop = value),
                      onToggleLoop: () => setState(() => _loop = !_loop),
                      onToggleMute: () => setState(() => _muted = !_muted),
                      onCycleSpeed: _cycleSpeed,
                    );
                  },
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Back',
                          color: foreground,
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: foreground,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17,
                                ),
                              ),
                              Text(
                                '${_index + 1} of ${_items.length}',
                                style: TextStyle(
                                  color: foreground.withValues(alpha: 0.6),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: item.favorite
                              ? 'Remove favorite'
                              : 'Favorite',
                          onPressed: () => widget.store.toggleFavorite(item),
                          icon: Icon(
                            item.favorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: item.favorite ? AppColors.pink : foreground,
                          ),
                        ),
                        Builder(
                          builder: (buttonContext) => IconButton(
                            tooltip: 'Share',
                            color: foreground,
                            onPressed: () =>
                                shareItem(buttonContext, widget.store, item),
                            icon: const Icon(Icons.share_rounded),
                          ),
                        ),
                        PopupMenuButton<VoidCallback>(
                          tooltip: 'More',
                          iconColor: foreground,
                          color: AppColors.surfaceHigh,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          onSelected: (action) => action(),
                          itemBuilder: (_) => [
                            _menuItem(
                              Icons.info_outline_rounded,
                              'Info',
                              () => showItemInfo(context, widget.store, item),
                            ),
                            _menuItem(
                              Icons.download_rounded,
                              'Save a copy',
                              () => saveItem(context, widget.store, item),
                            ),
                            _menuItem(
                              Icons.edit_rounded,
                              'Rename',
                              () => renameItem(context, widget.store, item),
                            ),
                            _menuItem(
                              Icons.delete_outline_rounded,
                              'Delete',
                              _delete,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ViewerPage extends StatefulWidget {
  const _ViewerPage({
    super.key,
    required this.item,
    required this.path,
    required this.onDecoded,
    required this.backdrop,
    required this.loop,
    required this.muted,
    required this.speed,
    required this.onBackdrop,
    required this.onToggleLoop,
    required this.onToggleMute,
    required this.onCycleSpeed,
  });

  final SvgaItem item;
  final String path;
  final ValueChanged<MovieEntity> onDecoded;
  final PreviewBackdrop backdrop;
  final bool loop;
  final bool muted;
  final double speed;
  final ValueChanged<PreviewBackdrop> onBackdrop;
  final VoidCallback onToggleLoop;
  final VoidCallback onToggleMute;
  final VoidCallback onCycleSpeed;

  @override
  State<_ViewerPage> createState() => _ViewerPageState();
}

class _ViewerPageState extends State<_ViewerPage>
    with SingleTickerProviderStateMixin {
  late final SVGAAnimationController _controller = SVGAAnimationController(
    vsync: this,
  )..isMute = widget.muted;

  /// Duration at 1× speed, as reported by the file.
  Duration _baseDuration = Duration.zero;
  bool _ready = false;
  bool _failed = false;
  bool _playing = false;
  bool _resumeAfterScrub = false;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener(_onStatus);
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await File(widget.path).readAsBytes();
      final movie = await SVGAParser.shared.decodeFromBuffer(bytes);
      if (!mounted) {
        movie.dispose();
        return;
      }
      widget.onDecoded(movie);
      _controller.videoItem = movie;
      _baseDuration = _controller.duration ?? Duration.zero;
      _controller.duration = _baseDuration * (1 / widget.speed);
      setState(() => _ready = true);
      _play();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() => _playing = false);
    }
  }

  void _play() {
    if (!_ready) return;
    if (widget.loop) {
      _controller.repeat();
    } else {
      _controller.forward(from: _controller.value >= 1 ? 0 : _controller.value);
    }
    setState(() => _playing = true);
  }

  void _pause() {
    _controller.stop();
    setState(() => _playing = false);
  }

  void _step(int delta) {
    final frames = _controller.frames;
    if (frames == 0) return;
    if (_playing) _pause();
    final frame = (_controller.currentFrame + delta).clamp(0, frames - 1);
    // Aim at the middle of the frame so rounding never lands on a neighbour.
    _controller.value = (frame + 0.5) / frames;
  }

  @override
  void didUpdateWidget(_ViewerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.isMute = widget.muted;
    if (!_ready) return;
    final speedChanged = oldWidget.speed != widget.speed;
    if (speedChanged) {
      _controller.duration = _baseDuration * (1 / widget.speed);
    }
    if ((speedChanged || oldWidget.loop != widget.loop) && _playing) {
      // Restart the ticker so the new duration / loop mode takes effect.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _playing) _play();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              BackdropFill(widget.backdrop, cell: 16),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 64, 16, 16),
                  child: _buildStage(),
                ),
              ),
            ],
          ),
        ),
        _buildControls(),
      ],
    );
  }

  Widget _buildStage() {
    if (_failed) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined, size: 44, color: Colors.white54),
            SizedBox(height: 12),
            Text(
              'This file could not be decoded',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      );
    }
    if (!_ready) return const Center(child: CircularProgressIndicator());
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _playing ? _pause : _play,
      child: SVGAImage(
        _controller,
        clearsAfterStop: false,
        filterQuality: FilterQuality.medium,
      ),
    );
  }

  Widget _buildControls() {
    final item = widget.item;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (item.hasMeta) ...[
                      _MetaChip(
                        Icons.aspect_ratio_rounded,
                        '${item.width}×${item.height}',
                      ),
                      _MetaChip(Icons.speed_rounded, '${item.fps} fps'),
                      _MetaChip(Icons.layers_rounded, '${item.frames} frames'),
                      _MetaChip(
                        Icons.timer_outlined,
                        formatSeconds(item.duration),
                      ),
                    ],
                    _MetaChip(
                      Icons.sd_storage_outlined,
                      formatBytes(item.bytes),
                    ),
                    if (item.onDevice)
                      _MetaChip(Icons.folder_outlined, item.externalPath!),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final frames = _controller.frames;
                  return Row(
                    children: [
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4,
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 16,
                            ),
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 7,
                            ),
                            activeTrackColor: AppColors.violet,
                            inactiveTrackColor: AppColors.outline,
                            thumbColor: Colors.white,
                          ),
                          child: Slider(
                            value: _controller.value.clamp(0.0, 1.0),
                            onChangeStart: !_ready
                                ? null
                                : (_) {
                                    _resumeAfterScrub = _playing;
                                    if (_playing) _pause();
                                  },
                            onChanged: !_ready
                                ? null
                                : (value) => _controller.value = value,
                            onChangeEnd: !_ready
                                ? null
                                : (_) {
                                    if (_resumeAfterScrub) _play();
                                  },
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 64,
                        child: Text(
                          frames == 0
                              ? '– / –'
                              : '${_controller.currentFrame + 1} / $frames',
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    tooltip: widget.loop ? 'Loop on' : 'Loop off',
                    onPressed: widget.onToggleLoop,
                    icon: Icon(
                      widget.loop
                          ? Icons.repeat_on_rounded
                          : Icons.repeat_rounded,
                      color: widget.loop
                          ? AppColors.violet
                          : AppColors.textMuted,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Previous frame',
                    onPressed: _ready ? () => _step(-1) : null,
                    icon: const Icon(Icons.skip_previous_rounded),
                  ),
                  _PlayButton(
                    playing: _playing,
                    onPressed: !_ready ? null : (_playing ? _pause : _play),
                  ),
                  IconButton(
                    tooltip: 'Next frame',
                    onPressed: _ready ? () => _step(1) : null,
                    icon: const Icon(Icons.skip_next_rounded),
                  ),
                  TextButton(
                    onPressed: widget.onCycleSpeed,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 40),
                      padding: EdgeInsets.zero,
                    ),
                    child: Text(
                      '${widget.speed == 0.5 ? '0.5' : widget.speed.toInt()}×',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: widget.speed == 1.0
                            ? AppColors.textMuted
                            : AppColors.violet,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  for (final kind in PreviewBackdrop.values)
                    _BackdropSwatch(
                      kind: kind,
                      selected: kind == widget.backdrop,
                      onTap: () => widget.onBackdrop(kind),
                    ),
                  const Spacer(),
                  IconButton(
                    tooltip: widget.muted ? 'Unmute' : 'Mute',
                    onPressed: widget.onToggleMute,
                    icon: Icon(
                      widget.muted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.violet),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.playing, required this.onPressed});

  final bool playing;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.accentGradient,
        boxShadow: [
          BoxShadow(
            color: Color(0x557C5CFF),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: IconButton(
        tooltip: playing ? 'Pause' : 'Play',
        iconSize: 32,
        padding: const EdgeInsets.all(12),
        color: Colors.white,
        onPressed: onPressed,
        icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
      ),
    );
  }
}

class _BackdropSwatch extends StatelessWidget {
  const _BackdropSwatch({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final PreviewBackdrop kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: kind.label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(right: 10),
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? AppColors.violet : AppColors.outline,
              width: 2,
            ),
          ),
          child: ClipOval(
            child: SizedBox.square(
              dimension: 26,
              child: BackdropFill(kind, cell: 6.5),
            ),
          ),
        ),
      ),
    );
  }
}
