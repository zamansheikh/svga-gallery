import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../data/library_store.dart';
import '../models/svga_item.dart';
import '../theme.dart';

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Opens the system share sheet with the animation file.
Future<void> shareItem(
  BuildContext context,
  LibraryStore store,
  SvgaItem item,
) async {
  // iPad and macOS anchor the share popover to this rectangle.
  final box = context.findRenderObject() as RenderBox?;
  final origin = box == null || !box.hasSize
      ? null
      : box.localToGlobal(Offset.zero) & box.size;
  try {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(store.pathOf(item))],
        // Library files are stored under an id, so restore the real name.
        fileNameOverrides: ['${item.name}.svga'],
        sharePositionOrigin: origin,
      ),
    );
  } catch (_) {
    if (context.mounted) _toast(context, 'Could not share this file');
  }
}

/// Lets the user pick where to save a copy of the animation file.
Future<void> saveItem(
  BuildContext context,
  LibraryStore store,
  SvgaItem item,
) async {
  try {
    final bytes = await File(store.pathOf(item)).readAsBytes();
    final saved = await FilePicker.saveFile(
      dialogTitle: 'Save animation',
      fileName: '${item.name}.svga',
      bytes: bytes,
    );
    if (saved != null && context.mounted) {
      _toast(context, 'Saved ${item.name}.svga');
    }
  } catch (_) {
    if (context.mounted) _toast(context, 'Could not save this file');
  }
}

String _formatDate(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)} '
      '${two(d.hour)}:${two(d.minute)}';
}

/// Shows everything known about [item], including where the file lives.
void showItemInfo(BuildContext context, LibraryStore store, SvgaItem item) {
  final path = store.pathOf(item);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item.name,
              style: Theme.of(sheetContext).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.folder_outlined,
              label: 'Location',
              value: path,
              copyable: true,
            ),
            _InfoRow(
              icon: item.onDevice
                  ? Icons.smartphone_rounded
                  : Icons.inventory_2_outlined,
              label: 'Storage',
              value: item.onDevice ? 'On this device' : 'App library',
            ),
            if (item.source != null)
              _InfoRow(
                icon: Icons.link_rounded,
                label: 'Downloaded from',
                value: item.source!,
                copyable: true,
              ),
            _InfoRow(
              icon: Icons.sd_storage_outlined,
              label: 'File size',
              value: '${formatBytes(item.bytes)} (${item.bytes} bytes)',
            ),
            if (item.hasMeta) ...[
              _InfoRow(
                icon: Icons.aspect_ratio_rounded,
                label: 'Dimensions',
                value: '${item.width} × ${item.height} px',
              ),
              _InfoRow(
                icon: Icons.speed_rounded,
                label: 'Frame rate',
                value: '${item.fps} fps',
              ),
              _InfoRow(
                icon: Icons.layers_rounded,
                label: 'Frames',
                value:
                    '${item.frames} frames · ${formatSeconds(item.duration)}',
              ),
            ],
            _InfoRow(
              icon: Icons.schedule_rounded,
              label: item.onDevice ? 'Modified' : 'Added',
              value: _formatDate(item.addedAt),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Builder(
                    builder: (buttonContext) => FilledButton.icon(
                      onPressed: () => shareItem(buttonContext, store, item),
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text('Share'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => saveItem(sheetContext, store, item),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Save a copy'),
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.copyable = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 18, color: AppColors.violet),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          if (copyable)
            IconButton(
              tooltip: 'Copy',
              visualDensity: VisualDensity.compact,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: value));
                if (context.mounted) _toast(context, '$label copied');
              },
              icon: const Icon(
                Icons.copy_rounded,
                size: 18,
                color: AppColors.textMuted,
              ),
            ),
        ],
      ),
    );
  }
}
