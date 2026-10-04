import 'package:flutter/material.dart';

import '../data/library_store.dart';
import '../models/svga_item.dart';

/// Asks for a single line of text; resolves to null when cancelled or empty.
Future<String?> promptText(
  BuildContext context, {
  required String title,
  required String action,
  String initial = '',
  String? hint,
  TextInputType? keyboardType,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _TextPrompt(
      title: title,
      action: action,
      initial: initial,
      hint: hint,
      keyboardType: keyboardType,
    ),
  );
}

class _TextPrompt extends StatefulWidget {
  const _TextPrompt({
    required this.title,
    required this.action,
    required this.initial,
    this.hint,
    this.keyboardType,
  });

  final String title;
  final String action;
  final String initial;
  final String? hint;
  final TextInputType? keyboardType;

  @override
  State<_TextPrompt> createState() => _TextPromptState();
}

class _TextPromptState extends State<_TextPrompt> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    Navigator.pop(context, text.isEmpty ? null : text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: widget.keyboardType,
        decoration: InputDecoration(hintText: widget.hint),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.action)),
      ],
    );
  }
}

Future<void> renameItem(
  BuildContext context,
  LibraryStore store,
  SvgaItem item,
) async {
  final name = await promptText(
    context,
    title: 'Rename',
    action: 'Save',
    initial: item.name,
  );
  if (name != null) await store.rename(item, name);
}

/// Confirms and deletes [item]; resolves to true when it was deleted.
Future<bool> confirmDelete(
  BuildContext context,
  LibraryStore store,
  SvgaItem item,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete animation?'),
      content: Text(
        item.onDevice
            ? '"${item.name}" will be permanently deleted from this device.'
            : '"${item.name}" will be removed from your gallery.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (ok != true) return false;
  await store.delete(item);
  return true;
}
