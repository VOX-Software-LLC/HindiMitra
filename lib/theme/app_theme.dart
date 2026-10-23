import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'palette.dart';

/// Baloo 2 = display, Nunito = body, Tiro Devanagari Hindi = Hindi glyphs.
///
/// GoogleFonts.xxx() does a descriptor lookup + async-load check on every call
/// and these helpers run hundreds of times per frame, so the base style for each
/// family/weight is built once and then only copyWith'd (much cheaper rebuilds).
class Fonts {
  static final Map<FontWeight, TextStyle> _display = {}, _body = {};
  static TextStyle? _hindi;
  static TextStyle display(double size, {Color? color, FontWeight w = FontWeight.w800, double? height}) =>
      (_display[w] ??= GoogleFonts.baloo2(fontWeight: w))
          .copyWith(fontSize: size, color: color ?? AppColors.textPrimary, height: height);
  // Nunito has no Devanagari glyphs; Hindi inside body text falls back to Tiro.
  static TextStyle body(double size, {Color? color, FontWeight w = FontWeight.w400, double? height}) =>
      (_body[w] ??= GoogleFonts.nunito(fontWeight: w)
              .copyWith(fontFamilyFallback: [GoogleFonts.tiroDevanagariHindi().fontFamily!]))
          .copyWith(fontSize: size, color: color ?? AppColors.textPrimary, height: height);
  static TextStyle hindi(double size, {Color? color, double? height}) =>
      (_hindi ??= GoogleFonts.tiroDevanagariHindi())
          .copyWith(fontSize: size, color: color ?? AppColors.textPrimary, height: height);

  /// Loads the bundled font files (assets/google_fonts/) before the first frame,
  /// so text never renders in a fallback font and then jumps.
  static Future<void> preload() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    for (final w in FontWeight.values.where((w) => w.value >= 400)) {
      display(14, w: w);
      body(14, w: w);
    }
    hindi(14);
    GoogleFonts.nunitoTextTheme();
    await GoogleFonts.pendingFonts();
  }
}

/// The app's "toy" depth. Called with the neutral [AppColors.toyShadowColor]
/// (cards, tiles) it gives a soft, layered lift; called with a colour (a
/// button's darker shade) it keeps a crisp 3D bottom edge plus a soft glow of
/// that colour, so buttons still look pressable.
List<BoxShadow> toyShadow(Color color, [double offset = 6]) {
  if (color == AppColors.toyShadowColor) {
    return [
      BoxShadow(color: color.withOpacity(0.07), offset: const Offset(0, 1), blurRadius: 2),
      BoxShadow(color: color.withOpacity(0.13), offset: Offset(0, offset * 0.9 + 2), blurRadius: offset * 3 + 6,
          spreadRadius: -2),
    ];
  }
  return [
    BoxShadow(color: color.withOpacity(color.a * 0.95), offset: Offset(0, offset * 0.7), blurRadius: 0),
    BoxShadow(color: color.withOpacity(color.a * 0.28), offset: Offset(0, offset + 3), blurRadius: offset * 2.5 + 4,
        spreadRadius: -2),
  ];
}

List<BoxShadow> softShadow([Color? c]) => [
      BoxShadow(
          color: (c ?? AppColors.primary).withOpacity(0.32),
          offset: const Offset(0, 14),
          blurRadius: 32,
          spreadRadius: -12),
      BoxShadow(color: AppColors.toyShadowColor.withOpacity(0.06), offset: const Offset(0, 2), blurRadius: 4),
    ];

/// Two-stop vertical gradient from a lighter tint of [c] down to [c] — the
/// fill for buttons, badges and icon tiles.
LinearGradient toneGradient(Color c) => LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Color.lerp(c, Colors.white, 0.18)!, c],
    );

/// A colour darkened by [amount] (0-1), for the 3D edge under coloured shapes.
Color shade(Color c, [double amount = 0.22]) => Color.lerp(c, Colors.black, amount)!;

ThemeData buildTheme(Brightness b) {
  final p = b == Brightness.dark ? Palette.dark : Palette.light;
  final base = ThemeData(
    useMaterial3: true,
    brightness: b,
    scaffoldBackgroundColor: p.background,
    colorScheme: ColorScheme.fromSeed(seedColor: p.primary, brightness: b)
        .copyWith(primary: p.primary, secondary: p.secondary, surface: p.card, error: p.destructive),
  );
  return base.copyWith(
    textTheme: GoogleFonts.nunitoTextTheme(base.textTheme)
        .apply(bodyColor: p.foreground, displayColor: p.foreground),
    // Screens slide up and fade in on every platform, instead of snapping.
    pageTransitionsTheme: PageTransitionsTheme(builders: {
      for (final t in TargetPlatform.values) t: const FadeUpwardsPageTransitionsBuilder(),
    }),
    splashFactory: InkSparkle.splashFactory,
  );
}
