import 'package:flutter/services.dart';

/// Haptic feedback — mirrors hapticService.ts.
void hapticLight() => HapticFeedback.lightImpact();
void hapticMedium() => HapticFeedback.mediumImpact();
void hapticHeavy() => HapticFeedback.heavyImpact();
void hapticSuccess() => HapticFeedback.mediumImpact();
void hapticError() => HapticFeedback.vibrate();
void hapticSelection() => HapticFeedback.selectionClick();
