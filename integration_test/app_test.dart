import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:svga_gallery/data/library_store.dart';
import 'package:svga_gallery/main.dart';

// Smoke test against the real plugins and network: downloads the sample pack,
// then drives the gallery and the viewer. Screenshots are written to the app
// support directory (printed at the end).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shot(WidgetTester tester, String name) async {
    final view = tester.binding.renderViews.first;
    final layer = view.debugLayer! as OffsetLayer;
    final image = await layer.toImage(view.paintBounds);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/shot_$name.png');
    await file.writeAsBytes(data!.buffer.asUint8List());
    debugPrint('SCREENSHOT ${file.path}');
  }

  // The window may be in the background (no vsync), so drive frames by hand.
  Future<void> frames(WidgetTester tester, Duration total) async {
    const step = Duration(milliseconds: 50);
    for (var t = Duration.zero; t < total; t += step) {
      await tester.pump(step);
    }
  }

  testWidgets('import samples, browse and play', (tester) async {
    final store = await LibraryStore.open();
    await tester.pumpWidget(SvgaGalleryApp(store: store));
    await tester.pump(const Duration(seconds: 1));

    if (store.items.isEmpty) {
      await shot(tester, 'empty');
      await tester.tap(find.text('Add sample pack'));
      for (var i = 0; i < 120; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        if (store.busyLabel == null && store.items.isNotEmpty) break;
      }
    }
    expect(store.items.length, LibraryStore.sampleNames.length);

    await frames(tester, const Duration(seconds: 4));
    expect(find.byType(SVGAImage), findsWidgets);
    await shot(tester, 'gallery');

    // Newest first, so the last imported sample is the first tile.
    await tester.tap(find.text(store.items.last.name));
    await frames(tester, const Duration(seconds: 2));
    expect(find.text('1 of ${store.items.length}'), findsOneWidget);
    await shot(tester, 'viewer');

    await tester.tap(find.byTooltip('Pause'));
    await frames(tester, const Duration(milliseconds: 300));
    expect(find.byTooltip('Play'), findsOneWidget);
    final before = tester.widget<Slider>(find.byType(Slider)).value;
    await tester.tap(find.byTooltip('Next frame'));
    await frames(tester, const Duration(milliseconds: 300));
    final after = tester.widget<Slider>(find.byType(Slider)).value;
    expect(after, isNot(before));

    await tester.tap(find.byTooltip('Mint'));
    await frames(tester, const Duration(milliseconds: 400));
    await shot(tester, 'viewer_mint');

    await tester.tap(find.byTooltip('Back'));
    await frames(tester, const Duration(seconds: 1));
    expect(find.text('SVGA Gallery'), findsOneWidget);

    // Dispose the players so no frame callbacks outlive the test.
    await tester.pumpWidget(const SizedBox());
    await frames(tester, const Duration(seconds: 1));
  });
}
