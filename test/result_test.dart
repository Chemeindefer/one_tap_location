// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_tap_location/one_tap_location.dart';

void main() {
  test('describes every field that positions are compared by', () {
    expect(
      OneTapPosition(
        latitude: 41.0082,
        longitude: 28.9784,
        timestamp: DateTime.utc(2026, 9, 16, 22, 26, 34),
        isPrecise: true,
        horizontalAccuracy: 5,
        altitude: 62.5,
      ).toString(),
      'OneTapPosition(41.0082, 28.9784, precise, '
      'timestamp: 2026-09-16 22:26:34.000Z, horizontalAccuracy: 5.0, '
      'altitude: 62.5)',
    );
    expect(
      OneTapPosition(
        latitude: 41,
        longitude: 29,
        timestamp: DateTime.utc(2026),
        isPrecise: false,
      ).toString(),
      'OneTapPosition(41.0, 29.0, approximate, '
      'timestamp: 2026-01-01 00:00:00.000Z)',
    );
  });
}
