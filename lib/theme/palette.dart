import 'package:flutter/material.dart';
import 'themes.dart';
export 'themes.dart' show AppThemes, AppThemeDef;

/// Little Hindi palette — exact hex values from the React Native app.
class Palette {
  final Color background, foreground, card, primary, primaryForeground,
      secondary, muted, mutedForeground, accent, destructive, border,
      purple, green, sky, pink, sunny, sunnyForeground, shadowToy;
  const Palette({
    required this.background, required this.foreground, required this.card,
    required this.primary, required this.primaryForeground,
    required this.secondary, required this.muted, required this.mutedForeground,
    required this.accent, required this.destructive, required this.border,
    required this.purple, required this.green, required this.sky,
    required this.pink, required this.sunny, required this.sunnyForeground,
    required this.shadowToy,
  });

  static const light = Palette(
    background: Color(0xFFFCF9EE), foreground: Color(0xFF453B2E),
    card: Color(0xFFFFFFFF), primary: Color(0xFFEE9A4C),
    primaryForeground: Color(0xFFFEFCF4), secondary: Color(0xFF6E4EDF),
    muted: Color(0xFFF1EAD8), mutedForeground: Color(0xFF8B7B62),
    accent: Color(0xFF4EC58A), destructive: Color(0xFFE8452F),
    border: Color(0xFFE3D8BC), purple: Color(0xFF6E4EDF),
    green: Color(0xFF4EC58A), sky: Color(0xFF4FB2E6), pink: Color(0xFFF26E97),
    sunny: Color(0xFFF2CE58), sunnyForeground: Color(0xFF4E402F),
    shadowToy: Color(0xFFB57140),
  );

  static const dark = Palette(
    background: Color(0xFF3E3427), foreground: Color(0xFFF8F3E4),
    card: Color(0xFF4C4031), primary: Color(0xFFF4A55A),
    primaryForeground: Color(0xFF3F3125), secondary: Color(0xFF7F5EE6),
    muted: Color(0xFF544737), mutedForeground: Color(0xFFBAAA96),
    accent: Color(0xFF4EC58A), destructive: Color(0xFFEE5138),
    border: Color(0x1FFFFFFF), purple: Color(0xFF8E75EF),
    green: Color(0xFF63D296), sky: Color(0xFF5CB6E8), pink: Color(0xFFF47AA1),
    sunny: Color(0xFFF2CE58), sunnyForeground: Color(0xFF4E402F),
    shadowToy: Color(0xFF2F2519),
  );
}

/// Colour tokens used by every screen. The theme-dependent ones are getters
/// that read [AppThemes.current], so switching theme recolours the app; the
/// rest (feedback colours, stars, writing canvas) are fixed.
class AppColors {
  static AppThemeDef get _t => AppThemes.current;
  static Color get primary => _t.primary;
  static Color get primaryDark => _t.primaryDark;
  static Color get primaryLight => _t.primaryLight;
  static Color get secondary => _t.secondary;
  static Color get secondaryDark => shadeOf(_t.secondary);
  static Color get background => _t.background;
  static Color get surface => _t.surface;
  static Color get textPrimary => _t.textPrimary;
  static Color get textSecondary => _t.textSecondary;
  static Color get textMuted => _t.textSecondary;
  static Color get textOnPrimary => _t.textOnPrimary;
  static Color get border => _t.border;
  static Color get muted => _t.muted;
  static Color get starEmpty => _t.border;
  static Color get toyShadowColor => _t.shadow;
  static bool get isDark => _t.dark;
  static const writingModule = Color(0xFFFF7043);
  static const readingModule = Color(0xFF4EC58A);
  static const aiFeatures = Color(0xFF6E4EDF);
  static const success = Color(0xFF4EC58A);
  static const successDark = Color(0xFF2E9163);
  static const error = Color(0xFFE8452F);
  static const warning = Color(0xFFF2CE58);
  static const starGold = Color(0xFFF2CE58);
  static const disabled = Color(0xFFBDBDBD);
  static const canvasBackground = Color(0xFFFFFDF7);
  static const canvasGridLine = Color(0xFFFFE8CC);
  static const canvasStroke = Color(0xFFF59E2D);
  static const canvasGuideDot = Color(0xFFFF9800);
  static const canvasLetterOutline = Color(0xFFE0E0E0);
  static const canvasLetterGhost = Color(0xFFF5F5F5);
}

Color shadeOf(Color c) => Color.lerp(c, Colors.black, 0.2)!;

class Sp {
  static const xs = 4.0, sm = 8.0, md = 16.0, lg = 24.0, xl = 32.0, xxl = 48.0;
}

class Rad {
  static const sm = 8.0, md = 12.0, lg = 20.0, xl = 28.0, xl2 = 36.0, xl3 = 44.0;
}

Color hexColor(String hex) {
  var h = hex.replaceAll('#', '');
  if (h.length == 6) h = 'FF$h';
  return Color(int.parse(h, radix: 16));
}
