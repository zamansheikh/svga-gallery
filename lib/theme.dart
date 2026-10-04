import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppColors {
  static const background = Color(0xFF0A0A12);
  static const surface = Color(0xFF14141F);
  static const surfaceHigh = Color(0xFF1D1D2C);
  static const outline = Color(0xFF2A2A3D);
  static const violet = Color(0xFF7C5CFF);
  static const pink = Color(0xFFFF5CAA);
  static const amber = Color(0xFFFFB85C);
  static const textMuted = Color(0xFF9A9AB5);

  static const accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [violet, pink],
  );

  static const titleGradient = LinearGradient(
    colors: [Color(0xFFB7A6FF), pink, amber],
  );
}

ThemeData buildAppTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.violet,
        brightness: Brightness.dark,
      ).copyWith(
        surface: AppColors.background,
        surfaceContainer: AppColors.surface,
        surfaceContainerHigh: AppColors.surfaceHigh,
        primary: AppColors.violet,
        secondary: AppColors.pink,
        outlineVariant: AppColors.outline,
      );
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
  );
  return base.copyWith(
    textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surfaceHigh,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      hintStyle: const TextStyle(color: AppColors.textMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.violet, width: 1.4),
      ),
    ),
  );
}

/// Paints [child] with the brand gradient (used for titles and icons).
class GradientMask extends StatelessWidget {
  const GradientMask({
    super.key,
    required this.child,
    this.gradient = AppColors.titleGradient,
  });

  final Widget child;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient.createShader(bounds),
      child: child,
    );
  }
}
