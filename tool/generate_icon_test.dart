// Draws the launcher icon sources into assets/icon/. Run with:
//   flutter test tool/generate_icon_test.dart
//   dart run flutter_launcher_icons
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const _size = 1024.0;
const _violet = Color(0xFF7C5CFF);
const _pink = Color(0xFFFF5CAA);

void _background(Canvas canvas) {
  const rect = Rect.fromLTWH(0, 0, _size, _size);
  canvas.drawRect(
    rect,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF6A4BFF), Color(0xFFB04DF2), _pink],
        stops: [0, 0.55, 1],
      ).createShader(rect),
  );
  canvas.drawRect(
    rect,
    Paint()
      ..shader = const RadialGradient(
        center: Alignment(0.9, 1.0),
        radius: 0.9,
        colors: [Color(0x99FFB85C), Color(0x00FFB85C)],
      ).createShader(rect),
  );
  canvas.drawRect(
    rect,
    Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.8, -0.9),
        radius: 0.8,
        colors: [Color(0x55FFFFFF), Color(0x00FFFFFF)],
      ).createShader(rect),
  );
}

/// A stack of frames (the gallery) with a play mark on the front one.
void _art(Canvas canvas) {
  const card = 470.0;
  final shape = RRect.fromRectAndRadius(
    Rect.fromCenter(center: Offset.zero, width: card, height: card),
    const Radius.circular(120),
  );

  void frame(
    Offset center,
    double degrees,
    Paint paint, {
    bool shadow = false,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(degrees * math.pi / 180);
    if (shadow) {
      canvas.drawRRect(
        shape.shift(const Offset(0, 26)),
        Paint()
          ..color = const Color(0x552A0A5E)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 38),
      );
    }
    canvas.drawRRect(shape, paint);
    canvas.restore();
  }

  frame(const Offset(418, 428), -17, Paint()..color = const Color(0x40FFFFFF));
  frame(const Offset(468, 470), -8, Paint()..color = const Color(0x73FFFFFF));
  const front = Offset(540, 536);
  frame(front, 0, Paint()..color = const Color(0xFFFFFFFF), shadow: true);

  // Play triangle, optically centred, with rounded corners.
  final play = Path()
    ..moveTo(front.dx - 62, front.dy - 108)
    ..lineTo(front.dx + 112, front.dy)
    ..lineTo(front.dx - 62, front.dy + 108)
    ..close();
  final bounds = play.getBounds().inflate(30);
  final shader = const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [_violet, _pink],
  ).createShader(bounds);
  canvas.drawPath(play, Paint()..shader = shader);
  canvas.drawPath(
    play,
    Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = 56
      ..strokeJoin = StrokeJoin.round,
  );

  // Sparkle: the "animation" hint.
  void sparkle(Offset c, double r) {
    final path = Path()..moveTo(c.dx, c.dy - r);
    for (var i = 1; i <= 4; i++) {
      final a = -math.pi / 2 + i * math.pi / 2;
      final mid = a - math.pi / 4;
      path.quadraticBezierTo(
        c.dx + math.cos(mid) * r * 0.12,
        c.dy + math.sin(mid) * r * 0.12,
        c.dx + math.cos(a) * r,
        c.dy + math.sin(a) * r,
      );
    }
    canvas.drawPath(path, Paint()..color = const Color(0xFFFFFFFF));
  }

  sparkle(const Offset(792, 236), 78);
  sparkle(const Offset(690, 148), 34);
}

Future<void> _write(String name, void Function(Canvas canvas) draw) async {
  final recorder = ui.PictureRecorder();
  draw(Canvas(recorder));
  final image = await recorder.endRecording().toImage(
    _size.toInt(),
    _size.toInt(),
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File('assets/icon/$name.png');
  await file.create(recursive: true);
  await file.writeAsBytes(data!.buffer.asUint8List());
}

void _scaled(Canvas canvas, double scale, void Function() draw) {
  canvas.save();
  canvas.translate(_size / 2, _size / 2);
  canvas.scale(scale);
  canvas.translate(-_size / 2, -_size / 2);
  draw();
  canvas.restore();
}

void main() {
  testWidgets('generate launcher icon sources', (tester) async {
    await tester.runAsync(() async {
      // Full-bleed icon (iOS, legacy Android).
      await _write('icon', (canvas) {
        _background(canvas);
        _art(canvas);
      });
      // Android adaptive layers; the foreground stays inside the safe zone.
      await _write('icon_background', _background);
      await _write(
        'icon_foreground',
        (canvas) => _scaled(canvas, 0.68, () => _art(canvas)),
      );
      // macOS icons carry their own rounded shape and margin.
      await _write('icon_macos', (canvas) {
        const inset = 100.0;
        final shape = RRect.fromRectAndRadius(
          const Rect.fromLTWH(
            inset,
            inset,
            _size - inset * 2,
            _size - inset * 2,
          ),
          const Radius.circular(186),
        );
        canvas.drawRRect(
          shape.shift(const Offset(0, 10)),
          Paint()
            ..color = const Color(0x40000000)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
        );
        canvas.clipRRect(shape);
        _scaled(canvas, (_size - inset * 2) / _size, () {
          _background(canvas);
          _art(canvas);
        });
      });
    });
  });
}
