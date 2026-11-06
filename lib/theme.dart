import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colour tokens. Read them with `context.palette`.
@immutable
class Palette extends ThemeExtension<Palette> {
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final Color onAccent;
  final Color accent2;
  final Color success;
  final Color danger;

  const Palette({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.onAccent,
    required this.accent2,
    required this.success,
    required this.danger,
  });

  static const dark = Palette(
    background: Color(0xFF0B0C0E),
    surface: Color(0xFF16191D),
    surfaceAlt: Color(0xFF1F2328),
    border: Color(0xFF2A2F35),
    textPrimary: Color(0xFFF5F7FA),
    textSecondary: Color(0xFF9AA1A9),
    accent: Color(0xFF00E5FF),
    onAccent: Color(0xFF00282E),
    accent2: Color(0xFFFF8A3D),
    success: Color(0xFF2EE58A),
    danger: Color(0xFFFF5A4E),
  );

  static const light = Palette(
    background: Color(0xFFF3F5F7),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFE9EDF1),
    border: Color(0xFFDCE1E6),
    textPrimary: Color(0xFF12161A),
    textSecondary: Color(0xFF5B646E),
    accent: Color(0xFF00838F),
    onAccent: Color(0xFFFFFFFF),
    accent2: Color(0xFFD9560B),
    success: Color(0xFF138A4E),
    danger: Color(0xFFC62828),
  );

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(ThemeExtension<Palette>? other, double t) {
    if (other is! Palette) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return Palette(
      background: l(background, other.background),
      surface: l(surface, other.surface),
      surfaceAlt: l(surfaceAlt, other.surfaceAlt),
      border: l(border, other.border),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      accent: l(accent, other.accent),
      onAccent: l(onAccent, other.onAccent),
      accent2: l(accent2, other.accent2),
      success: l(success, other.success),
      danger: l(danger, other.danger),
    );
  }
}

extension PaletteX on BuildContext {
  Palette get palette => Theme.of(this).extension<Palette>()!;
  TextTheme get text => Theme.of(this).textTheme;
}

class AppTheme {
  /// Inter is fetched at runtime by google_fonts; tests turn this off and use
  /// the Roboto font bundled with the Flutter SDK.
  static bool useGoogleFonts = true;

  static ThemeData get dark => _build(Palette.dark, Brightness.dark);
  static ThemeData get light => _build(Palette.light, Brightness.light);

  static ThemeData _build(Palette p, Brightness b) {
    final scheme = ColorScheme(
      brightness: b,
      primary: p.accent,
      onPrimary: p.onAccent,
      secondary: p.accent2,
      onSecondary: Colors.white,
      error: p.danger,
      onError: Colors.white,
      surface: p.surface,
      onSurface: p.textPrimary,
      surfaceContainerHighest: p.surfaceAlt,
      outline: p.border,
    );
    // Every explicit TextStyle below names the family; otherwise buttons,
    // chips and snackbars fall back to the platform font.
    final family = useGoogleFonts ? GoogleFonts.inter().fontFamily : 'Roboto';
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: b,
      fontFamily: family,
    );
    final text = (useGoogleFonts ? GoogleFonts.interTextTheme(base.textTheme) : base.textTheme).apply(
      bodyColor: p.textPrimary,
      displayColor: p.textPrimary,
    );
    final radius = BorderRadius.circular(14);
    return base.copyWith(
      scaffoldBackgroundColor: p.background,
      extensions: [p],
      textTheme: text.copyWith(
        headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.3),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: p.textPrimary,
        titleTextStyle: TextStyle(fontFamily: family, fontSize: 20, fontWeight: FontWeight.w800, color: p.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: p.border)),
      ),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: p.accent.withValues(alpha: 0.16),
        height: 66,
        labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
              fontFamily: family,
              fontSize: 11,
              fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
              color: s.contains(WidgetState.selected) ? p.textPrimary : p.textSecondary,
            )),
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
              color: s.contains(WidgetState.selected) ? p.accent : p.textSecondary,
            )),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: p.onAccent,
          minimumSize: const Size(48, 50),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: TextStyle(fontFamily: family, fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.textPrimary,
          minimumSize: const Size(48, 50),
          side: BorderSide(color: p.border),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: TextStyle(fontFamily: family, fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.accent,
          textStyle: TextStyle(fontFamily: family, fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.accent,
        foregroundColor: p.onAccent,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surfaceAlt,
        selectedColor: p.accent.withValues(alpha: 0.18),
        side: BorderSide(color: p.border),
        labelStyle: TextStyle(fontFamily: family, color: p.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        checkmarkColor: p.accent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceAlt,
        border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: p.accent, width: 2)),
        labelStyle: TextStyle(fontFamily: family, color: p.textSecondary),
        hintStyle: TextStyle(fontFamily: family, color: p.textSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.textPrimary,
        contentTextStyle: TextStyle(fontFamily: family, color: p.background, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: p.accent.withValues(alpha: 0.18),
          selectedForegroundColor: p.textPrimary,
          foregroundColor: p.textSecondary,
          side: BorderSide(color: p.border),
        ),
      ),
      listTileTheme: ListTileThemeData(iconColor: p.textSecondary),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
    );
  }
}
