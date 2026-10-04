import 'package:flutter/material.dart';

import 'data/library_store.dart';
import 'screens/gallery_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await LibraryStore.open();
  runApp(SvgaGalleryApp(store: store));
}

class SvgaGalleryApp extends StatelessWidget {
  const SvgaGalleryApp({super.key, required this.store});

  final LibraryStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SVGA Gallery',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: GalleryScreen(store: store),
    );
  }
}
