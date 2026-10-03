// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

/// Builds the theme of the example app for [brightness].
///
/// The fallback button on Android takes its colors from the color scheme.
ThemeData buildExampleTheme(Brightness brightness) {
  final ExampleColors colors = ExampleColors.forBrightness(brightness);
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF7FA8FF),
      brightness: brightness,
    ),
    scaffoldBackgroundColor: colors.background,
  );
}

/// The colors of the example app.
@immutable
class ExampleColors {
  const ExampleColors._({
    required this.background,
    required this.text,
    required this.secondaryText,
    required this.tertiaryText,
    required this.card,
    required this.cardBorder,
    required this.divider,
    required this.emptyCardBorder,
    required this.accent,
    required this.accentSurface,
    required this.accentSurfaceText,
    required this.ring,
    required this.preciseRingFill,
    required this.approximateRingFill,
    required this.ringBackground,
    required this.spinnerTrack,
    required this.success,
    required this.successText,
    required this.successSurface,
    required this.warning,
    required this.warningText,
    required this.warningSurface,
    required this.warningBorder,
    required this.error,
    required this.errorText,
    required this.errorSurface,
    required this.codeSurface,
    required this.bannerCodeSurface,
  });

  static const ExampleColors light = ExampleColors._(
    background: Color(0xFFF6F7F9),
    text: Color(0xFF171A20),
    secondaryText: Color(0xFF5A6472),
    tertiaryText: Color(0xFF6B7482),
    card: Color(0xFFFFFFFF),
    cardBorder: Color(0xFFE2E5EA),
    divider: Color(0xFFEEF0F3),
    emptyCardBorder: Color(0xFFC9CFD8),
    accent: Color(0xFF1A5CE5),
    accentSurface: Color(0xFFEAF0FD),
    accentSurfaceText: Color(0xFF173E96),
    ring: Color(0xFF7FA8FF),
    preciseRingFill: Color(0x1A1A5CE5),
    approximateRingFill: Color(0x121A5CE5),
    ringBackground: Color(0xFFEAF0FD),
    spinnerTrack: Color(0xFFDCE4F5),
    success: Color(0xFF157F46),
    successText: Color(0xFF0E6437),
    successSurface: Color(0xFFE9F6EE),
    warning: Color(0xFF9A6200),
    warningText: Color(0xFF7A5200),
    warningSurface: Color(0xFFFFF4E0),
    warningBorder: Color(0xFFF0D9A8),
    error: Color(0xFFC03030),
    errorText: Color(0xFFA02525),
    errorSurface: Color(0xFFFBE9E9),
    codeSurface: Color(0xFFF1F3F6),
    bannerCodeSurface: Color(0x99FFFFFF),
  );

  static const ExampleColors dark = ExampleColors._(
    background: Color(0xFF0F1115),
    text: Color(0xFFEDEFF3),
    secondaryText: Color(0xFF9AA3B0),
    tertiaryText: Color(0xFF9AA3B0),
    card: Color(0xFF171A20),
    cardBorder: Color(0xFF262B33),
    divider: Color(0xFF262B33),
    emptyCardBorder: Color(0xFF3A4150),
    accent: Color(0xFF7FA8FF),
    accentSurface: Color(0x1F7FA8FF),
    accentSurfaceText: Color(0xFFB9CEFF),
    ring: Color(0xFF7FA8FF),
    preciseRingFill: Color(0x247FA8FF),
    approximateRingFill: Color(0x147FA8FF),
    ringBackground: Color(0x1A7FA8FF),
    spinnerTrack: Color(0xFF262B33),
    success: Color(0xFF39B26E),
    successText: Color(0xFF5FD094),
    successSurface: Color(0x2439B26E),
    warning: Color(0xFFE0A33A),
    warningText: Color(0xFFF2C46D),
    warningSurface: Color(0x1FE0A33A),
    warningBorder: Color(0x4DE0A33A),
    error: Color(0xFFE26A6A),
    errorText: Color(0xFFF19A9A),
    errorSurface: Color(0x24E26A6A),
    codeSurface: Color(0xFF20242C),
    bannerCodeSurface: Color(0x14FFFFFF),
  );

  static ExampleColors forBrightness(Brightness brightness) {
    return switch (brightness) {
      Brightness.light => light,
      Brightness.dark => dark,
    };
  }

  static ExampleColors of(BuildContext context) {
    return forBrightness(Theme.of(context).brightness);
  }

  final Color background;
  final Color text;
  final Color secondaryText;
  final Color tertiaryText;
  final Color card;
  final Color cardBorder;
  final Color divider;
  final Color emptyCardBorder;
  final Color accent;
  final Color accentSurface;
  final Color accentSurfaceText;
  final Color ring;
  final Color preciseRingFill;
  final Color approximateRingFill;
  final Color ringBackground;
  final Color spinnerTrack;
  final Color success;
  final Color successText;
  final Color successSurface;
  final Color warning;
  final Color warningText;
  final Color warningSurface;
  final Color warningBorder;
  final Color error;
  final Color errorText;
  final Color errorSurface;
  final Color codeSurface;
  final Color bannerCodeSurface;
}

/// The style that the text of the example app starts from, on top of the
/// text theme.
///
/// The design sets tracking and line height only where a text needs them.
const TextStyle baseTextStyle = TextStyle(letterSpacing: 0, height: 1.2);

/// The monospaced system font, for code and values that the plugin reports.
TextStyle monospaceStyle(
  BuildContext context, {
  required double fontSize,
  required Color color,
  FontWeight? fontWeight,
  double? letterSpacing,
  double? height,
}) {
  final String fontFamily = switch (Theme.of(context).platform) {
    TargetPlatform.iOS || TargetPlatform.macOS => 'Menlo',
    _ => 'monospace',
  };
  return TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSize,
    color: color,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing,
    height: height,
  );
}
