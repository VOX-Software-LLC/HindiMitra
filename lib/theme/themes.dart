import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../l10n.dart';

/// Background art drawn behind every page of a theme.
enum ThemePattern { none, stars, web, skyline, waves, leaves, dots, tiranga }

/// One selectable look: the colours [AppColors] reads plus the page backdrop.
/// Hero-style themes are original designs (no character names or logos).
class AppThemeDef {
  final String id, name, hindiName, emoji, tagline;
  final bool dark;
  final Color background, surface, textPrimary, textSecondary, textOnPrimary, border, muted,
      primary, primaryDark, primaryLight, secondary, shadow, patternColor;
  final List<Color> backdrop;
  final ThemePattern pattern;
  const AppThemeDef({
    required this.id, required this.name, required this.hindiName, required this.emoji, required this.tagline,
    required this.dark, required this.background, required this.surface, required this.textPrimary,
    required this.textSecondary, required this.textOnPrimary, required this.border, required this.muted,
    required this.primary, required this.primaryDark, required this.primaryLight, required this.secondary,
    required this.shadow, required this.backdrop, required this.pattern, required this.patternColor,
  });
}

class AppThemes {
  static const sunny = AppThemeDef(
    id: 'sunny', name: 'Sunny Day', hindiName: 'दिन', emoji: '☀️', tagline: 'Warm and bright',
    dark: false, background: Color(0xFFFCF9EE), surface: Color(0xFFFFFFFF), textPrimary: Color(0xFF453B2E),
    textSecondary: Color(0xFF8B7B62), textOnPrimary: Color(0xFFFEFCF4), border: Color(0xFFEBE1CB),
    muted: Color(0xFFF1EAD8), primary: Color(0xFFEE9A4C), primaryDark: Color(0xFFC97A2A),
    primaryLight: Color(0xFFF5B679), secondary: Color(0xFF6E4EDF), shadow: Color(0xFFB57140),
    backdrop: [Color(0xFFFCF9EE), Color(0xFFFCF9EE)], pattern: ThemePattern.none, patternColor: Color(0x00000000),
  );

  static const night = AppThemeDef(
    id: 'night', name: 'Starry Night', hindiName: 'रात', emoji: '🌙', tagline: 'Easy on the eyes',
    dark: true, background: Color(0xFF161B2E), surface: Color(0xFF232A44), textPrimary: Color(0xFFF3F1EA),
    textSecondary: Color(0xFFA9B0C8), textOnPrimary: Color(0xFF241A0E), border: Color(0xFF343E5E),
    muted: Color(0xFF2A3252), primary: Color(0xFFF4A55A), primaryDark: Color(0xFFC97A2A),
    primaryLight: Color(0xFFF8C48F), secondary: Color(0xFF9B85F2), shadow: Color(0xFF05070F),
    backdrop: [Color(0xFF111528), Color(0xFF1B2140)], pattern: ThemePattern.stars, patternColor: Color(0x55FFFFFF),
  );

  static const webHero = AppThemeDef(
    id: 'webHero', name: 'Web Hero', hindiName: 'जाल वीर', emoji: '🕸️', tagline: 'Red and blue, ready to swing',
    dark: false, background: Color(0xFFFFF3F3), surface: Color(0xFFFFFFFF), textPrimary: Color(0xFF1F2340),
    textSecondary: Color(0xFF66708F), textOnPrimary: Color(0xFFFFFFFF), border: Color(0xFFF0D6DA),
    muted: Color(0xFFFBE7EA), primary: Color(0xFFE23636), primaryDark: Color(0xFFA61E1E),
    primaryLight: Color(0xFFF07A7A), secondary: Color(0xFF2B59C3), shadow: Color(0xFF7A1C2B),
    backdrop: [Color(0xFFFFF1F1), Color(0xFFEAF0FF)], pattern: ThemePattern.web, patternColor: Color(0x1A1F2340),
  );

  static const guardian = AppThemeDef(
    id: 'guardian', name: 'Night Guardian', hindiName: 'रात का रक्षक', emoji: '🦇', tagline: 'Dark city, golden signal',
    dark: true, background: Color(0xFF15161B), surface: Color(0xFF24262E), textPrimary: Color(0xFFF2F0E8),
    textSecondary: Color(0xFFA7A8B2), textOnPrimary: Color(0xFF1B1B1B), border: Color(0xFF383A45),
    muted: Color(0xFF2C2E37), primary: Color(0xFFF2C230), primaryDark: Color(0xFFB58E12),
    primaryLight: Color(0xFFF7D96E), secondary: Color(0xFF6C8CFF), shadow: Color(0xFF000000),
    backdrop: [Color(0xFF101116), Color(0xFF1E2030)], pattern: ThemePattern.skyline, patternColor: Color(0xFF0B0C10),
  );

  static const ocean = AppThemeDef(
    id: 'ocean', name: 'Ocean', hindiName: 'सागर', emoji: '🌊', tagline: 'Cool blue waves',
    dark: false, background: Color(0xFFEAF7FB), surface: Color(0xFFFFFFFF), textPrimary: Color(0xFF173A4D),
    textSecondary: Color(0xFF5D7F90), textOnPrimary: Color(0xFFFFFFFF), border: Color(0xFFCDE6EF),
    muted: Color(0xFFDDF0F6), primary: Color(0xFF1E9BD7), primaryDark: Color(0xFF127AAE),
    primaryLight: Color(0xFF6CC3EA), secondary: Color(0xFF13B5A6), shadow: Color(0xFF1B6A8F),
    backdrop: [Color(0xFFEFFAFD), Color(0xFFD9F0F8)], pattern: ThemePattern.waves, patternColor: Color(0x261E9BD7),
  );

  static const jungle = AppThemeDef(
    id: 'jungle', name: 'Jungle', hindiName: 'जंगल', emoji: '🌴', tagline: 'Leafy green adventure',
    dark: false, background: Color(0xFFF0F7E7), surface: Color(0xFFFFFFFF), textPrimary: Color(0xFF233B1F),
    textSecondary: Color(0xFF66805C), textOnPrimary: Color(0xFFFFFFFF), border: Color(0xFFD6E6C6),
    muted: Color(0xFFE3F0D6), primary: Color(0xFF3FA34D), primaryDark: Color(0xFF2B7A36),
    primaryLight: Color(0xFF7CC587), secondary: Color(0xFFE39B26), shadow: Color(0xFF3E6B2E),
    backdrop: [Color(0xFFF3FAEA), Color(0xFFE2F1D2)], pattern: ThemePattern.leaves, patternColor: Color(0x2E3FA34D),
  );

  static const space = AppThemeDef(
    id: 'space', name: 'Space', hindiName: 'अंतरिक्ष', emoji: '🚀', tagline: 'Planets and stars',
    dark: true, background: Color(0xFF0E0B26), surface: Color(0xFF1D1944), textPrimary: Color(0xFFF1EEFF),
    textSecondary: Color(0xFFA8A2D0), textOnPrimary: Color(0xFFFFFFFF), border: Color(0xFF332D66),
    muted: Color(0xFF26214F), primary: Color(0xFF8B6CF6), primaryDark: Color(0xFF6243D6),
    primaryLight: Color(0xFFB19CFA), secondary: Color(0xFF3CC6E8), shadow: Color(0xFF040312),
    backdrop: [Color(0xFF0B0820), Color(0xFF1F1650)], pattern: ThemePattern.stars, patternColor: Color(0x80FFFFFF),
  );

  static const candy = AppThemeDef(
    id: 'candy', name: 'Candy', hindiName: 'मिठाई', emoji: '🍭', tagline: 'Sweet pink and purple',
    dark: false, background: Color(0xFFFFF0F6), surface: Color(0xFFFFFFFF), textPrimary: Color(0xFF4A2340),
    textSecondary: Color(0xFF93698A), textOnPrimary: Color(0xFFFFFFFF), border: Color(0xFFF6D3E3),
    muted: Color(0xFFFCE3EE), primary: Color(0xFFF2559A), primaryDark: Color(0xFFC23574),
    primaryLight: Color(0xFFF793BE), secondary: Color(0xFF8B5CF6), shadow: Color(0xFFA0436E),
    backdrop: [Color(0xFFFFF2F8), Color(0xFFF6EAFF)], pattern: ThemePattern.dots, patternColor: Color(0x22F2559A),
  );

  static const tiranga = AppThemeDef(
    id: 'tiranga', name: 'Tiranga', hindiName: 'तिरंगा', emoji: '🇮🇳', tagline: 'Saffron, white and green',
    dark: false, background: Color(0xFFFFFDF7), surface: Color(0xFFFFFFFF), textPrimary: Color(0xFF1F2A44),
    textSecondary: Color(0xFF6B7488), textOnPrimary: Color(0xFFFFFFFF), border: Color(0xFFEDE6D6),
    muted: Color(0xFFF5F0E3), primary: Color(0xFFFF9933), primaryDark: Color(0xFFD9771A),
    primaryLight: Color(0xFFFFBB73), secondary: Color(0xFF138808), shadow: Color(0xFF9C6A2E),
    backdrop: [Color(0xFFFFF4E6), Color(0xFFFFFFFF), Color(0xFFEAF6E8)], pattern: ThemePattern.tiranga,
    patternColor: Color(0x1A000080),
  );

  static const all = [sunny, night, tiranga, webHero, guardian, ocean, jungle, space, candy];

  static AppThemeDef current = sunny;

  static AppThemeDef byId(String id) => all.firstWhere((t) => t.id == id, orElse: () => sunny);

  /// Switches the look and rebuilds every widget in place (no screen is closed
  /// and no state is lost), since [AppColors] values are read during build.
  static void apply(String id) {
    final next = byId(id);
    if (identical(next, current)) return;
    current = next;
    rebuildAllWidgets();
  }
}

/// The page background for the current theme: its gradient plus pattern.
class ThemeBackdrop extends StatelessWidget {
  final Widget child;
  const ThemeBackdrop({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    final t = AppThemes.current;
    return DecoratedBox(
      decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: t.backdrop)),
      child: Stack(fit: StackFit.passthrough, children: [
        if (t.pattern != ThemePattern.none)
          Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: ThemePatternPainter(t)))),
        child,
      ]),
    );
  }
}

class ThemePatternPainter extends CustomPainter {
  final AppThemeDef theme;
  ThemePatternPainter(this.theme);

  @override
  void paint(Canvas canvas, Size size) {
    final c = theme.patternColor;
    switch (theme.pattern) {
      case ThemePattern.none:
        break;
      case ThemePattern.stars:
        final rng = math.Random(7);
        final p = Paint()..color = c;
        for (int i = 0; i < 90; i++) {
          final o = Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height);
          canvas.drawCircle(o, rng.nextDouble() * 1.6 + 0.4, p);
        }
        if (theme.id == 'space') {
          canvas.drawCircle(Offset(size.width * 0.86, size.height * 0.16), 34, Paint()..color = const Color(0x33B19CFA));
          canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.78), 22, Paint()..color = const Color(0x333CC6E8));
        } else {
          canvas.drawCircle(Offset(size.width * 0.88, 70), 26, Paint()..color = const Color(0x22FFF4D6));
        }
      case ThemePattern.web:
        final p = Paint()..color = c..style = PaintingStyle.stroke..strokeWidth = 1.2;
        for (final corner in [Offset.zero, Offset(size.width, size.height)]) {
          for (int k = 0; k < 9; k++) {
            final a = (corner == Offset.zero ? 0 : math.pi) + k * math.pi / 16;
            canvas.drawLine(corner, corner + Offset(math.cos(a), math.sin(a)) * 260, p);
          }
          for (int r = 1; r <= 5; r++) {
            final path = Path();
            for (int k = 0; k < 9; k++) {
              final a = (corner == Offset.zero ? 0 : math.pi) + k * math.pi / 16;
              final pt = corner + Offset(math.cos(a), math.sin(a)) * (r * 48.0);
              k == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
            }
            canvas.drawPath(path, p);
          }
        }
      case ThemePattern.skyline:
        final rng = math.Random(3);
        final p = Paint()..color = c;
        double x = 0;
        while (x < size.width) {
          final w = 28 + rng.nextDouble() * 46, h = 60 + rng.nextDouble() * 120;
          canvas.drawRect(Rect.fromLTWH(x, size.height - h, w, h), p);
          x += w + 2;
        }
        canvas.drawCircle(Offset(size.width * 0.82, 90), 30, Paint()..color = const Color(0x22F2C230));
      case ThemePattern.waves:
        final p = Paint()..color = c..style = PaintingStyle.stroke..strokeWidth = 2;
        for (double y = 40; y < size.height; y += 70) {
          final path = Path()..moveTo(0, y);
          for (double x = 0; x <= size.width; x += 40) {
            path.quadraticBezierTo(x + 10, y - 10, x + 20, y);
            path.quadraticBezierTo(x + 30, y + 10, x + 40, y);
          }
          canvas.drawPath(path, p);
        }
      case ThemePattern.leaves:
        final rng = math.Random(11);
        final p = Paint()..color = c;
        for (int i = 0; i < 26; i++) {
          canvas.save();
          canvas.translate(rng.nextDouble() * size.width, rng.nextDouble() * size.height);
          canvas.rotate(rng.nextDouble() * math.pi);
          canvas.drawOval(const Rect.fromLTWH(-16, -6, 32, 12), p);
          canvas.restore();
        }
      case ThemePattern.dots:
        final p = Paint()..color = c;
        for (double y = 16; y < size.height; y += 44) {
          for (double x = (y ~/ 44).isEven ? 16 : 38; x < size.width; x += 44) {
            canvas.drawCircle(Offset(x, y), 5, p);
          }
        }
      case ThemePattern.tiranga:
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 5), Paint()..color = const Color(0xFFFF9933));
        canvas.drawRect(Rect.fromLTWH(0, size.height - 5, size.width, 5), Paint()..color = const Color(0xFF138808));
        drawChakra(canvas, Offset(size.width * 0.86, size.height * 0.5), 70, c);
    }
  }

  @override
  bool shouldRepaint(covariant ThemePatternPainter old) => old.theme.id != theme.id;
}

/// Ashoka Chakra: a rim, hub and 24 spokes.
void drawChakra(Canvas canvas, Offset center, double r, Color color) {
  final rim = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = r * 0.08;
  final spoke = Paint()..color = color..strokeWidth = r * 0.035..strokeCap = StrokeCap.round;
  canvas.drawCircle(center, r, rim);
  canvas.drawCircle(center, r * 0.16, Paint()..color = color);
  for (int i = 0; i < 24; i++) {
    final a = i * 2 * math.pi / 24;
    canvas.drawLine(center, center + Offset(math.cos(a), math.sin(a)) * r * 0.94, spoke);
  }
}

/// Page transitions that put [ThemeBackdrop] behind every route.
class BackdropPageTransitionsBuilder extends PageTransitionsBuilder {
  const BackdropPageTransitionsBuilder();
  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation,
          Animation<double> secondaryAnimation, Widget child) =>
      const FadeUpwardsPageTransitionsBuilder()
          .buildTransitions(route, context, animation, secondaryAnimation, ThemeBackdrop(child: child));
}
