// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_tap_location/one_tap_location.dart';
import 'package:one_tap_location_example/src/panels.dart';

void main() {
  testWidgets('keeps the age of the position current', (
    WidgetTester tester,
  ) async {
    DateTime now = DateTime(2026, 9, 17, 14, 3, 7);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PositionCard(
            position: OneTapPosition(
              latitude: 41.02551,
              longitude: 28.97538,
              timestamp: now.subtract(const Duration(seconds: 50)),
              isPrecise: true,
            ),
            note: null,
            onCopy: () {},
            clock: () => now,
          ),
        ),
      ),
    );
    expect(find.textContaining('\u00A0· just now'), findsOneWidget);

    now = now.add(const Duration(seconds: 14));
    await tester.pump(const Duration(seconds: 14));
    expect(find.textContaining('\u00A0· just now'), findsOneWidget);

    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('\u00A0· 1\u00A0min ago'), findsOneWidget);
  });
}
