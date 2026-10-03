// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_tap_location/one_tap_location.dart';

void main() {
  test('asserts that the style has a label or an icon', () {
    expect(
      () => OneTapLocationButtonStyle(
        iosLabel: IOSLocationButtonLabel.none,
        iosIcon: IOSLocationButtonIcon.none,
      ),
      throwsAssertionError,
    );
  });

  test('asserts that the Android dimensions are not negative', () {
    expect(
      () => OneTapLocationButtonStyle(androidStrokeWidth: -1),
      throwsAssertionError,
    );
    expect(
      () => OneTapLocationButtonStyle(androidPressedCornerRadius: -1),
      throwsAssertionError,
    );
  });

  test('compares styles by value', () {
    const OneTapLocationButtonStyle style = OneTapLocationButtonStyle(
      cornerRadius: 8,
      androidStrokeColor: Color(0xFF102040),
    );

    expect(
      style,
      const OneTapLocationButtonStyle(
        cornerRadius: 8,
        androidStrokeColor: Color(0xFF102040),
      ),
    );
    expect(
      style.hashCode,
      const OneTapLocationButtonStyle(
        cornerRadius: 8,
        androidStrokeColor: Color(0xFF102040),
      ).hashCode,
    );
    expect(style, isNot(const OneTapLocationButtonStyle(cornerRadius: 12)));
    expect(
      style,
      isNot(
        const OneTapLocationButtonStyle(
          cornerRadius: 8,
          androidStrokeColor: Color(0xFF102040),
          androidLabel: AndroidLocationButtonLabel.none,
        ),
      ),
    );
    expect(
      style,
      isNot(
        const OneTapLocationButtonStyle(
          cornerRadius: 8,
          androidStrokeColor: Color(0xFF102040),
          androidFallbackLabel: 'My location',
        ),
      ),
    );
  });

  test('describes the properties that differ from the defaults', () {
    expect(
      const OneTapLocationButtonStyle(
        cornerRadius: 8,
        iosLabel: IOSLocationButtonLabel.none,
        androidFallbackLabel: 'My location',
      ).toString(),
      endsWith(
        '(cornerRadius: 8.0, iosLabel: none, androidFallbackLabel: "My '
        'location")',
      ),
    );
  });
}
