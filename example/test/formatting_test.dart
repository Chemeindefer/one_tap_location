// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_tap_location_example/src/formatting.dart';

void main() {
  test('formats coordinates with their hemispheres', () {
    expect(formatLatitude(41.02551), '41.025510° N');
    expect(formatLatitude(-33.8688), '33.868800° S');
    expect(formatLongitude(28.97538), '28.975380° E');
    expect(formatLongitude(-0.1276), '0.127600° W');
    expect(formatLatitude(0), '0.000000° N');
  });

  test('formats distances in meters', () {
    expect(formatMeters(12.44), '12.4\u00A0m');
    expect(formatMeters(2000), '2000.0\u00A0m');
  });

  test('formats a timestamp with its age', () {
    final DateTime timestamp = DateTime(2026, 9, 17, 14, 3, 7);

    expect(formatTimestamp(timestamp, timestamp), '14:03:07\u00A0· just now');
    expect(
      formatTimestamp(
        timestamp,
        timestamp.subtract(const Duration(seconds: 5)),
      ),
      '14:03:07\u00A0· just now',
    );
    expect(
      formatTimestamp(timestamp, timestamp.add(const Duration(seconds: 59))),
      '14:03:07\u00A0· just now',
    );
    expect(
      formatTimestamp(timestamp, timestamp.add(const Duration(minutes: 9))),
      '14:03:07\u00A0· 9\u00A0min ago',
    );
    expect(
      formatTimestamp(timestamp, timestamp.add(const Duration(minutes: 75))),
      '14:03:07\u00A0· 1\u00A0h ago',
    );
  });

  test(
    'shows a UTC timestamp in local time',
    () {
      final DateTime local = DateTime(2026, 9, 17, 14, 3, 7);

      expect(formatTimestamp(local.toUtc(), local), '14:03:07\u00A0· just now');
    },
    skip: DateTime(2026, 9, 17).timeZoneOffset == Duration.zero
        ? 'Needs a time zone with an offset from UTC'
        : false,
  );
}
