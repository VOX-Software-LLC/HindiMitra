import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hindi_mitra/screens/intro_screen.dart';

void main() {
  testWidgets('intro lays out at phone size without errors', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: IntroScreen(onContinue: () {})));
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('VoxCRE', findRichText: true), findsOneWidget);
    expect(find.text('Made in India'), findsOneWidget);
  });
}
