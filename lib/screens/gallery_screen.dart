import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart'
    show MovieEntity;

import '../data/device_scanner.dart';
import '../data/library_store.dart';
import '../models/svga_item.dart';
import '../theme.dart';
import '../widgets/about_sheet.dart';
import '../widgets/dialogs.dart';
import '../widgets/item_actions.dart';
import '../widgets/preview_backdrop.dart';
import '../widgets/svga_thumb.dart';
import 'viewer_screen.dart';

enum SortMode {
  newest('Newest first', Icons.schedule_rounded),
  name('Name', Icons.sort_by_alpha_rounded),
  size('File size', Icons.data_usage_rounded);

  const SortMode(this.label, this.icon);
  final String label;
  final IconData icon;
}

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key, required this.store});

  final LibraryStore store;

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

enum _Filter { all, favorites, device }

class _GalleryScreenState extends State<GalleryScreen>
    with WidgetsBindingObserver {
  String _query = '';
  _Filter _filter = _Filter.all;
  SortMode _sort = SortMode.newest;

  LibraryStore get _store => widget.store;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _store.syncDevice();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Picks up access granted on the system settings screen, and files
    // added or removed while the app was in the background.
    if (state == AppLifecycleState.resumed) _store.syncDevice();
  }

  Future<void> _scanDevice() async {
    if (!_store.deviceAccess) {
      await _store.requestDeviceAccess();
      return;
    }
    final added = await _store.syncDevice();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            added == 0
                ? 'No new SVGA files found'
                : 'Found $added new file${added == 1 ? '' : 's'}',
          ),
        ),
      );
  }

  List<SvgaItem> _visibleItems() {
    final query = _query.toLowerCase();
    final items = _store.items
        .where(
          (e) => switch (_filter) {
            _Filter.all => true,
            _Filter.favorites => e.favorite,
            _Filter.device => e.onDevice,
          },
        )
        .where((e) => query.isEmpty || e.name.toLowerCase().contains(query))
        .toList();
    switch (_sort) {
      case SortMode.newest:
        items.sort((a, b) => b.addedAt.compareTo(a.addedAt));
      case SortMode.name:
        items.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case SortMode.size:
        items.sort((a, b) => b.bytes.compareTo(a.bytes));
    }
    return items;
  }

  void _report(ImportResult result) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> _importFiles() async {
    // .svga has no registered MIME type, so a custom extension filter hides
    // the files on Android; pick anything and filter here instead.
    final picked = await FilePicker.pickFiles(dialogTitle: 'Choose SVGA files');
    final paths = [
      for (final file in picked)
        if (file.path != null) file.path!,
    ];
    if (paths.isEmpty) return;
    final svga = paths.where((e) => e.toLowerCase().endsWith('.svga')).toList();
    final result = await _store.importFiles(svga);
    _report(result + ImportResult(failed: paths.length - svga.length));
  }

  Future<void> _importUrl() async {
    final url = await promptText(
      context,
      title: 'Import from URL',
      action: 'Import',
      hint: 'https://example.com/animation.svga',
      keyboardType: TextInputType.url,
    );
    if (url == null) return;
    _report(await _store.importUrl(url));
  }

  Future<void> _importSamples() async => _report(await _store.importSamples());

  void _showImportSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        void run(Future<void> Function() action) {
          Navigator.pop(sheetContext);
          action();
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (DeviceScanner.supported)
                  _SheetAction(
                    icon: Icons.travel_explore_rounded,
                    title: 'Scan device',
                    subtitle: 'Find every .svga file on this phone',
                    onTap: () => run(_scanDevice),
                  ),
                _SheetAction(
                  icon: Icons.folder_open_rounded,
                  title: 'From files',
                  subtitle: 'Pick one or more .svga files',
                  onTap: () => run(_importFiles),
                ),
                _SheetAction(
                  icon: Icons.link_rounded,
                  title: 'From URL',
                  subtitle: 'Download an animation by link',
                  onTap: () => run(_importUrl),
                ),
                _SheetAction(
                  icon: Icons.auto_awesome_rounded,
                  title: 'Sample pack',
                  subtitle:
                      '${LibraryStore.sampleNames.length} open-source demo animations',
                  onTap: () => run(_importSamples),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showItemSheet(SvgaItem item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SheetAction(
                icon: item.favorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                title: item.favorite ? 'Remove favorite' : 'Add to favorites',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _store.toggleFavorite(item);
                },
              ),
              _SheetAction(
                icon: Icons.share_rounded,
                title: 'Share',
                onTap: () {
                  Navigator.pop(sheetContext);
                  shareItem(context, _store, item);
                },
              ),
              _SheetAction(
                icon: Icons.download_rounded,
                title: 'Save a copy',
                onTap: () {
                  Navigator.pop(sheetContext);
                  saveItem(context, _store, item);
                },
              ),
              _SheetAction(
                icon: Icons.info_outline_rounded,
                title: 'Info',
                onTap: () {
                  Navigator.pop(sheetContext);
                  showItemInfo(context, _store, item);
                },
              ),
              _SheetAction(
                icon: Icons.edit_rounded,
                title: 'Rename',
                onTap: () {
                  Navigator.pop(sheetContext);
                  renameItem(context, _store, item);
                },
              ),
              _SheetAction(
                icon: Icons.delete_outline_rounded,
                title: 'Delete',
                danger: true,
                onTap: () {
                  Navigator.pop(sheetContext);
                  confirmDelete(context, _store, item);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _open(List<SvgaItem> items, int index) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            ViewerScreen(store: _store, items: items, initialIndex: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ListenableBuilder(
        listenable: _store,
        builder: (context, _) {
          final items = _visibleItems();
          final busy = _store.busyLabel;
          return Scaffold(
            floatingActionButton: busy != null
                ? null
                : _GradientFab(onPressed: _showImportSheet),
            body: Stack(
              children: [
                const _AmbientGlow(),
                SafeArea(
                  bottom: false,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: _buildHeader()),
                      if (DeviceScanner.supported && !_store.deviceAccess)
                        SliverToBoxAdapter(
                          child: _AccessBanner(
                            onAllow: _store.requestDeviceAccess,
                          ),
                        ),
                      if (_store.items.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _EmptyState(
                            onImport: _showImportSheet,
                            onSamples: busy == null ? _importSamples : null,
                          ),
                        )
                      else if (items.isEmpty)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: _NoMatches(),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                          sliver: SliverGrid.builder(
                            gridDelegate:
                                SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: _store.denseGrid
                                      ? 140
                                      : 220,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: 0.82,
                                ),
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final item = items[index];
                              return _SvgaCard(
                                key: ValueKey(item.id),
                                item: item,
                                path: _store.pathOf(item),
                                onDecoded: (movie) =>
                                    _store.updateMeta(item, movie),
                                animate: _store.livePreviews,
                                compact: _store.denseGrid,
                                onTap: () => _open(items, index),
                                onLongPress: () => _showItemSheet(item),
                                onFavorite: () => _store.toggleFavorite(item),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                if (busy != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 28 + MediaQuery.paddingOf(context).bottom,
                    child: Center(child: _BusyPill(label: busy)),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    final count = _store.items.length;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GradientMask(
                      child: Text(
                        'SVGA Gallery',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      count == 0
                          ? 'Preview your animations'
                          : '$count animation${count == 1 ? '' : 's'} · '
                                '${formatBytes(_store.totalBytes)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: _store.livePreviews
                    ? 'Pause previews'
                    : 'Play previews',
                onPressed: () => _store.livePreviews = !_store.livePreviews,
                icon: Icon(
                  _store.livePreviews
                      ? Icons.motion_photos_on_rounded
                      : Icons.motion_photos_paused_rounded,
                ),
              ),
              IconButton(
                tooltip: _store.denseGrid ? 'Large tiles' : 'Small tiles',
                onPressed: () => _store.denseGrid = !_store.denseGrid,
                icon: Icon(
                  _store.denseGrid
                      ? Icons.grid_view_rounded
                      : Icons.apps_rounded,
                ),
              ),
              IconButton(
                tooltip: 'About',
                onPressed: () => showAboutSheet(context),
                icon: const Icon(Icons.info_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextField(
              onChanged: (value) => setState(() => _query = value.trim()),
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Search animations',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterPill(
                        label: 'All',
                        selected: _filter == _Filter.all,
                        onTap: () => setState(() => _filter = _Filter.all),
                      ),
                      const SizedBox(width: 8),
                      _FilterPill(
                        label: 'Favorites',
                        icon: Icons.favorite_rounded,
                        selected: _filter == _Filter.favorites,
                        onTap: () =>
                            setState(() => _filter = _Filter.favorites),
                      ),
                      if (DeviceScanner.supported) ...[
                        const SizedBox(width: 8),
                        _FilterPill(
                          label: 'Device',
                          icon: Icons.smartphone_rounded,
                          selected: _filter == _Filter.device,
                          onTap: () => setState(() => _filter = _Filter.device),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              PopupMenuButton<SortMode>(
                tooltip: 'Sort',
                initialValue: _sort,
                onSelected: (value) => setState(() => _sort = value),
                color: AppColors.surfaceHigh,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                itemBuilder: (_) => [
                  for (final mode in SortMode.values)
                    PopupMenuItem(
                      value: mode,
                      child: Row(
                        children: [
                          Icon(mode.icon, size: 18),
                          const SizedBox(width: 12),
                          Text(mode.label),
                        ],
                      ),
                    ),
                ],
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.swap_vert_rounded,
                        size: 20,
                        color: AppColors.textMuted,
                      ),
                      // The label only fits beside the pills on wide screens.
                      if (MediaQuery.sizeOf(context).width >= 520) ...[
                        const SizedBox(width: 4),
                        Text(
                          _sort.label,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.9, -1.1),
            radius: 1.1,
            colors: [Color(0x557C5CFF), Color(0x00000000)],
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(1.2, -0.8),
              radius: 0.9,
              colors: [Color(0x33FF5CAA), Color(0x00000000)],
            ),
          ),
          child: SizedBox.expand(),
        ),
      ),
    );
  }
}

class _SvgaCard extends StatelessWidget {
  const _SvgaCard({
    super.key,
    required this.item,
    required this.path,
    required this.onDecoded,
    required this.animate,
    required this.compact,
    required this.onTap,
    required this.onLongPress,
    required this.onFavorite,
  });

  final SvgaItem item;
  final String path;
  final ValueChanged<MovieEntity> onDecoded;
  final bool animate;
  final bool compact;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(compact ? 18 : 22);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: AppColors.outline),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const BackdropFill(PreviewBackdrop.checker, cell: 10),
            Padding(
              padding: EdgeInsets.fromLTRB(10, 10, 10, compact ? 34 : 52),
              child: SvgaThumb(
                path: path,
                animate: animate,
                onDecoded: onDecoded,
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(12, 22, 12, compact ? 8 : 10),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x000A0A12), Color(0xF20A0A12)],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: compact ? 12 : 14,
                      ),
                    ),
                    if (!compact)
                      Text(
                        item.hasMeta
                            ? '${item.width}×${item.height} · '
                                  '${formatSeconds(item.duration)} · '
                                  '${formatBytes(item.bytes)}'
                            : formatBytes(item.bytes),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(onTap: onTap, onLongPress: onLongPress),
            ),
            if (!compact || item.favorite)
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: item.favorite ? 'Remove favorite' : 'Favorite',
                  onPressed: onFavorite,
                  icon: Icon(
                    item.favorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    size: 20,
                    color: item.favorite ? AppColors.pink : Colors.white70,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AccessBanner extends StatelessWidget {
  const _AccessBanner({required this.onAllow});

  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          const GradientMask(
            gradient: AppColors.accentGradient,
            child: Icon(Icons.travel_explore_rounded, size: 28),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Find SVGA files automatically',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 2),
                Text(
                  'Allow file access to show every .svga on this device.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(onPressed: onAllow, child: const Text('Allow')),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.accentGradient : null,
          color: selected ? null : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? Colors.transparent : AppColors.outline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: Colors.white),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientFab extends StatelessWidget {
  const _GradientFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppColors.accentGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x667C5CFF),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onPressed,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Import',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? Colors.redAccent : Colors.white;
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: danger ? color : AppColors.violet, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w700, color: color),
      ),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: const TextStyle(color: AppColors.textMuted)),
    );
  }
}

class _BusyPill extends StatelessWidget {
  const _BusyPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.outline),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onImport, required this.onSamples});

  final VoidCallback onImport;
  final VoidCallback? onSamples;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 80),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
              border: Border.all(color: AppColors.outline),
            ),
            child: const GradientMask(
              gradient: AppColors.accentGradient,
              child: Icon(Icons.animation_rounded, size: 52),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Your gallery is empty',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Import .svga files from your device or a link,\n'
            'or start with the sample pack.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onImport,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Import animations'),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onSamples,
            icon: const Icon(Icons.auto_awesome_rounded, size: 18),
            label: const Text('Add sample pack'),
          ),
        ],
      ),
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 80),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 44, color: AppColors.textMuted),
          SizedBox(height: 12),
          Text(
            'No animations match',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
