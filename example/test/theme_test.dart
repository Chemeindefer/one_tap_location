// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_tap_location_example/src/theme.dart';

/// The contrast ratio between [foreground] and the surfaces below it, the
/// last of which is opaque.
double _contrast(Color foreground, List<Color> surfaces) {
  Color background = surfaces.last;
  for (final Color surface in surfaces.reversed.skip(1)) {
    background = Color.alphaBlend(surface, background);
  }
  final double text = Color.alphaBlend(
    foreground,
    background,
  ).computeLuminance();
  final double behind = background.computeLuminance();
  final double lighter = text > behind ? text : behind;
  final double darker = text > behind ? behind : text;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  // The texts of the example app are smaller than the 18 point that WCAG AA
  // allows 3:1 for, so every pair meets the 4.5:1 of small text.
  const double smallTextContrast = 4.5;

  for (final (String name, ExampleColors colors) in <(String, ExampleColors)>[
    ('light', ExampleColors.light),
    ('dark', ExampleColors.dark),
  ]) {
    test('keeps the $name text readable on its surface', () {
      final List<(String, Color, List<Color>)> pairs =
          <(String, Color, List<Color>)>[
            (
              'titles on the background',
              colors.text,
              <Color>[colors.background],
            ),
            (
              'the titles and the values of a card',
              colors.text,
              <Color>[colors.card],
            ),
            (
              'the version and the hints below the button',
              colors.secondaryText,
              <Color>[colors.background],
            ),
            ('the texts of a card', colors.secondaryText, <Color>[colors.card]),
            (
              'the message of a failure',
              colors.secondaryText,
              <Color>[colors.codeSurface, colors.card],
            ),
            (
              'the empty state and the type of a result',
              colors.tertiaryText,
              <Color>[colors.card],
            ),
            ('the copy button', colors.accent, <Color>[colors.card]),
            (
              'the button tag of the header',
              colors.accent,
              <Color>[colors.accentSurface, colors.background],
            ),
            (
              'the tag of the locating card',
              colors.accent,
              <Color>[colors.accentSurface, colors.card],
            ),
            (
              'the text of the fallback notice',
              colors.accentSurfaceText,
              <Color>[colors.accentSurface, colors.background],
            ),
            (
              'the PRECISE tag',
              colors.successText,
              <Color>[colors.successSurface, colors.card],
            ),
            (
              'the APPROXIMATE tag and the error code',
              colors.warningText,
              <Color>[colors.warningSurface, colors.card],
            ),
            (
              'the texts of the diagnostic notice',
              colors.warningText,
              <Color>[colors.warningSurface, colors.background],
            ),
            (
              'the diagnostic of the notice',
              colors.warning,
              <Color>[
                colors.bannerCodeSurface,
                colors.warningSurface,
                colors.background,
              ],
            ),
            (
              'the tag of the denied card',
              colors.errorText,
              <Color>[colors.errorSurface, colors.card],
            ),
          ];

      for (final (String what, Color foreground, List<Color> surfaces)
          in pairs) {
        expect(
          _contrast(foreground, surfaces),
          greaterThanOrEqualTo(smallTextContrast),
          reason: '$what in the $name theme',
        );
      }
    });
  }
}
