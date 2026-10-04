import 'package:flutter/material.dart';

/// Backgrounds an animation can be previewed against.
enum PreviewBackdrop {
  checker('Transparent'),
  dark('Black'),
  light('White'),
  aurora('Aurora'),
  mint('Mint');

  const PreviewBackdrop(this.label);
  final String label;
}

class BackdropFill extends StatelessWidget {
  const BackdropFill(this.kind, {super.key, this.cell = 12});

  final PreviewBackdrop kind;
  final double cell;

  @override
  Widget build(BuildContext context) {
    return switch (kind) {
      PreviewBackdrop.checker => CustomPaint(
        painter: _CheckerPainter(cell),
        child: const SizedBox.expand(),
      ),
      PreviewBackdrop.dark => const ColoredBox(color: Colors.black),
      PreviewBackdrop.light => const ColoredBox(color: Colors.white),
      PreviewBackdrop.aurora => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2B1B6B), Color(0xFF7A1F6E), Color(0xFF0E1A4A)],
          ),
        ),
        child: SizedBox.expand(),
      ),
      PreviewBackdrop.mint => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFB8F5DD), Color(0xFF7FD8F0)],
          ),
        ),
        child: SizedBox.expand(),
      ),
    };
  }
}

class _CheckerPainter extends CustomPainter {
  const _CheckerPainter(this.cell);

  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF16161F),
    );
    final paint = Paint()..color = const Color(0xFF20202D);
    for (var y = 0; y * cell < size.height; y++) {
      for (var x = y.isEven ? 0 : 1; x * cell < size.width; x += 2) {
        canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell, cell), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_CheckerPainter oldDelegate) => oldDelegate.cell != cell;
}
