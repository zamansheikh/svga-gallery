import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';

const _githubUrl = 'https://github.com/zamansheikh';
const _facebookUrl = 'https://fb.com/zamansheikh.404';

void showAboutSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    builder: (context) => const SafeArea(child: _AboutSheet()),
  );
}

class _AboutSheet extends StatelessWidget {
  const _AboutSheet();

  Future<void> _open(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      // Reported below.
    }
    if (!opened) {
      messenger.showSnackBar(SnackBar(content: Text('Could not open $url')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Image.asset('assets/icon/icon.png', width: 84, height: 84),
          ),
          const SizedBox(height: 14),
          GradientMask(
            child: Text(
              'SVGA Gallery',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Browse, preview and share SVGA animations',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Text(
                  'Developed by',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  'Zaman Sheikh',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () => _open(context, _githubUrl),
                        icon: const Icon(Icons.code_rounded, size: 18),
                        label: const Text('GitHub'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () => _open(context, _facebookUrl),
                        icon: const Icon(Icons.facebook_rounded, size: 18),
                        label: const Text('Facebook'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
