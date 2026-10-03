// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:one_tap_location/one_tap_location.dart';

/// Whether the Android device under test provides the system location button,
/// which requires Android 17 or later. Pass
/// `--dart-define=EXPECT_SYSTEM_BUTTON=true` when it does.
const bool expectsSystemButton = bool.fromEnvironment('EXPECT_SYSTEM_BUTTON');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Widget buildButton() {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: OneTapLocationButton(onResult: (OneTapLocationResult result) {}),
      ),
    );
  }

  testWidgets(
    'hosts the system location button on iOS',
    (WidgetTester tester) async {
      final OneTapLocationAvailability availability =
          await OneTapLocationButton.checkAvailability();
      expect(availability.buttonType, OneTapLocationButtonType.system);

      await tester.pumpWidget(buildButton());
      await tester.pumpAndSettle();

      expect(find.byType(UiKitView), findsOneWidget);
      expect(tester.getSize(find.byType(UiKitView)).height, greaterThan(0));
    },
    skip: defaultTargetPlatform != TargetPlatform.iOS,
  );

  testWidgets(
    'hosts the system location button or the fallback button on Android',
    (WidgetTester tester) async {
      final OneTapLocationAvailability availability =
          await OneTapLocationButton.checkAvailability();
      expect(
        availability.buttonType,
        expectsSystemButton
            ? OneTapLocationButtonType.system
            : OneTapLocationButtonType.fallback,
      );

      await tester.pumpWidget(buildButton());
      await tester.pumpAndSettle();
      // Opening a session of the system button takes a few seconds, and a
      // failure is reported only then.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 5)),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        find.byType(PlatformViewLink),
        expectsSystemButton ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('Precise location'),
        expectsSystemButton ? findsNothing : findsOneWidget,
      );
    },
    skip: defaultTargetPlatform != TargetPlatform.android,
  );
}
