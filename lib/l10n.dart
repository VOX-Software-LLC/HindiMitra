import 'package:flutter/widgets.dart';

/// App UI language. English and Hindi are live; the rest are listed in
/// Settings as "coming soon". Strings are written inline with [tr].
class AppLang {
  static String code = 'en';
  static bool get isHindi => code == 'hi';

  static const live = [('en', 'English', 'English'), ('hi', 'हिन्दी', 'Hindi')];
  static const upcoming = [
    ('mr', 'मराठी', 'Marathi'), ('bn', 'বাংলা', 'Bengali'), ('ta', 'தமிழ்', 'Tamil'),
    ('te', 'తెలుగు', 'Telugu'), ('gu', 'ગુજરાતી', 'Gujarati'), ('pa', 'ਪੰਜਾਬੀ', 'Punjabi'),
    ('kn', 'ಕನ್ನಡ', 'Kannada'), ('ml', 'മലയാളം', 'Malayalam'), ('ur', 'اردو', 'Urdu'),
    ('or', 'ଓଡ଼ିଆ', 'Odia'), ('es', 'Español', 'Spanish'), ('fr', 'Français', 'French'),
    ('ar', 'العربية', 'Arabic'), ('de', 'Deutsch', 'German'), ('ja', '日本語', 'Japanese'),
  ];

  /// Switches language and rebuilds every widget in place.
  static void apply(String c) {
    if (c == code) return;
    code = c;
    rebuildAllWidgets();
  }
}

/// [en] or [hi] depending on the app language.
String tr(String en, String hi) => AppLang.isHindi ? hi : en;

/// Marks every element dirty so values read during build (theme colours,
/// language) update everywhere without closing any screen.
void rebuildAllWidgets() {
  final root = WidgetsBinding.instance.rootElement;
  if (root == null) return;
  void mark(Element e) { e.markNeedsBuild(); e.visitChildren(mark); }
  mark(root);
}
