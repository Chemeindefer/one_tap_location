// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_tap_location/one_tap_location.dart';
import 'package:one_tap_location/src/fallback_button.dart' show InsetBorder;
import 'package:one_tap_location/src/platform.dart'
    show resetPlatformStateForTesting;
import 'package:one_tap_location/testing.dart';

const MethodChannel _pluginChannel = MethodChannel('one_tap_location');

final OneTapLocationGranted _granted = OneTapLocationGranted(
  OneTapPosition(
    latitude: 41.0082,
    longitude: 28.9784,
    timestamp: DateTime.utc(2026, 9, 16),
    isPrecise: true,
  ),
);

const OneTapLocationFailed _servicesDisabled = OneTapLocationFailed(
  OneTapLocationException(OneTapLocationErrorCode.locationServicesDisabled),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final TargetPlatformVariant onAndroid = TargetPlatformVariant.only(
    TargetPlatform.android,
  );
  final TargetPlatformVariant onIOS = TargetPlatformVariant.only(
    TargetPlatform.iOS,
  );

  late FakeOneTapLocation location;
  late List<String> platformCalls;

  setUp(() {
    platformCalls = <String>[];
    for (final MethodChannel channel in <MethodChannel>[
      _pluginChannel,
      SystemChannels.platform_views,
      SystemChannels.platform_views_2,
    ]) {
      // As in a test without the fake, the platform never answers.
      messenger.setMockMethodCallHandler(channel, (MethodCall call) {
        platformCalls.add('${channel.name} ${call.method}');
        return Completer<Object?>().future;
      });
    }
    location = FakeOneTapLocation.install();
    addTearDown(location.uninstall);
  });

  tearDown(() {
    for (final MethodChannel channel in <MethodChannel>[
      _pluginChannel,
      SystemChannels.platform_views,
      SystemChannels.platform_views_2,
    ]) {
      messenger.setMockMethodCallHandler(channel, null);
    }
  });

  Widget buildButton({
    ValueChanged<OneTapLocationResult>? onResult,
    OneTapLocationController? controller,
    OneTapLocationButtonStyle style = const OneTapLocationButtonStyle(),
    OneTapLocationFallbackBuilder? fallbackBuilder,
  }) {
    return MaterialApp(
      home: Center(
        child: SizedBox(
          width: 320,
          child: Center(
            child: OneTapLocationButton(
              onResult: onResult ?? (OneTapLocationResult result) {},
              controller: controller,
              style: style,
              fallbackBuilder: fallbackBuilder,
            ),
          ),
        ),
      ),
    );
  }

  VoidCallback? onPressed(WidgetTester tester) {
    return tester.widget<FilledButton>(find.byType(FilledButton)).onPressed;
  }

  Future<void> tap(WidgetTester tester) async {
    await tester.tap(find.byType(OneTapLocationButton));
    await tester.pump();
  }

  group('shows', () {
    testWidgets('the fallback button on Android', (WidgetTester tester) async {
      await tester.pumpWidget(buildButton());

      expect(
        tester.getSize(find.byType(OneTapLocationButton)),
        const Size(320, 48),
      );
      expect(find.text('Precise location'), findsOneWidget);
      expect(platformCalls, isEmpty);
    }, variant: onAndroid);

    testWidgets('the widget of the fallback builder on Android', (
      WidgetTester tester,
    ) async {
      final List<VoidCallback?> callbacks = <VoidCallback?>[];
      await tester.pumpWidget(
        buildButton(
          fallbackBuilder: (BuildContext context, VoidCallback? onPressed) {
            callbacks.add(onPressed);
            return OutlinedButton(
              onPressed: onPressed,
              child: const Text('Use my location'),
            );
          },
        ),
      );

      await tester.tap(find.text('Use my location'));
      await tester.pump();

      expect(callbacks.last, isNull);
      location.requests.single.complete(_granted);
      await tester.pump();
      expect(callbacks.last, isNotNull);
    }, variant: onAndroid);

    testWidgets('a stand-in for the system button on Android', (
      WidgetTester tester,
    ) async {
      location.hasAndroidSystemButton = true;

      await tester.pumpWidget(
        buildButton(
          style: const OneTapLocationButtonStyle(
            androidLabel: AndroidLocationButtonLabel.sharePreciseLocation,
            androidFallbackLabel: 'Use my location',
          ),
          fallbackBuilder: (BuildContext context, VoidCallback? onPressed) =>
              throw StateError('The fallback builder must not be used.'),
        ),
      );

      expect(
        tester.getSize(find.byType(OneTapLocationButton)),
        const Size(320, 48),
      );
      expect(find.text('Share precise location'), findsOneWidget);
      expect(platformCalls, isEmpty);
    }, variant: onAndroid);

    testWidgets('an icon-only stand-in for the system button on Android', (
      WidgetTester tester,
    ) async {
      location.hasAndroidSystemButton = true;

      await tester.pumpWidget(
        buildButton(
          style: const OneTapLocationButtonStyle(
            androidLabel: AndroidLocationButtonLabel.none,
          ),
        ),
      );

      expect(
        tester.getSize(find.byType(OneTapLocationButton)),
        const Size(48, 48),
      );
    }, variant: onAndroid);

    testWidgets('a stand-in for the system button on iOS', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildButton(
          style: const OneTapLocationButtonStyle(
            iosLabel: IOSLocationButtonLabel.shareCurrentLocation,
          ),
          fallbackBuilder: (BuildContext context, VoidCallback? onPressed) =>
              throw StateError('The fallback builder must not be used.'),
        ),
      );

      expect(
        tester.getSize(find.byType(OneTapLocationButton)),
        const Size(205, 52),
      );
      expect(find.text('Share Current Location'), findsOneWidget);
      expect(platformCalls, isEmpty);
    }, variant: onIOS);

    testWidgets('a stand-in of the chosen size on iOS', (
      WidgetTester tester,
    ) async {
      location.iosButtonSize = const Size(260, 60);

      await tester.pumpWidget(buildButton());
      location.iosButtonSize = const Size(300, 70);
      await tester.tap(find.byType(OneTapLocationButton));
      await tester.pump();

      expect(
        tester.getSize(find.byType(OneTapLocationButton)),
        const Size(260, 60),
      );
    }, variant: onIOS);

    testWidgets(
      'a stand-in on iOS without a baseline, like the system button',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  const Text('Address'),
                  OneTapLocationButton(
                    onResult: (OneTapLocationResult result) {},
                  ),
                ],
              ),
            ),
          ),
        );
        final RenderBox row = tester.renderObject(find.byType(Row).first);

        expect(
          tester.getTopLeft(find.text('Address')).dy,
          tester.getTopLeft(find.byType(Row).first).dy,
        );
        expect(
          () => row.getDryLayout(const BoxConstraints(maxWidth: 400)),
          returnsNormally,
        );
        expect(tester.takeException(), isNull);
      },
      variant: onIOS,
    );

    testWidgets('nothing on iOS where the system button ignores taps', (
      WidgetTester tester,
    ) async {
      location.hasIOSSystemButton = false;

      await tester.pumpWidget(buildButton());

      expect(tester.getSize(find.byType(OneTapLocationButton)), Size.zero);
      expect(platformCalls, isEmpty);
    }, variant: onIOS);

    testWidgets(
      'a stand-in on iOS that asserts the size the system requires',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox(
                height: 48,
                child: OneTapLocationButton(
                  onResult: (OneTapLocationResult result) {},
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isAssertionError);
      },
      variant: onIOS,
    );

    testWidgets(
      'a stand-in with only the iOS properties of the style on iOS',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          buildButton(
            style: const OneTapLocationButtonStyle(
              iosIcon: IOSLocationButtonIcon.none,
              androidStrokeColor: Color(0xFFFFC107),
              androidStrokeWidth: 2,
            ),
          ),
        );

        Material shape() => tester.widget(
          find.descendant(
            of: find.byType(FilledButton),
            matching: find.byType(Material),
          ),
        );
        final Row content = tester.widget(
          find.descendant(
            of: find.byType(FilledButton),
            matching: find.byType(Row),
          ),
        );
        expect(find.text('Current Location'), findsOneWidget);
        expect(content.children, hasLength(1));
        expect(shape().shape, InsetBorder(const RoundedRectangleBorder(), 0));

        final TestGesture gesture = await tester.startGesture(
          tester.getCenter(find.byType(OneTapLocationButton)),
        );
        await tester.pump();

        expect(shape().shape, InsetBorder(const RoundedRectangleBorder(), 0));
        await gesture.cancel();
      },
      variant: onIOS,
    );

    testWidgets(
      'nothing on other platforms',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildButton());

        expect(tester.getSize(find.byType(OneTapLocationButton)), Size.zero);
        expect(platformCalls, isEmpty);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
    );
  });

  group('answers a tap', () {
    testWidgets(
      'with the preset result',
      (WidgetTester tester) async {
        final OneTapLocationController controller = OneTapLocationController();
        addTearDown(controller.dispose);
        final List<bool> locating = <bool>[];
        controller.addListener(() => locating.add(controller.isLocating));
        final List<OneTapLocationResult> results = <OneTapLocationResult>[];
        location.result = _granted;
        await tester.pumpWidget(
          buildButton(onResult: results.add, controller: controller),
        );

        await tap(tester);

        expect(results, <OneTapLocationResult>[_granted]);
        expect(locating, <bool>[true, false]);
        expect(location.requests.single.isPending, isFalse);
        expect(onPressed(tester), isNotNull);
      },
      variant: TargetPlatformVariant(<TargetPlatform>{
        TargetPlatform.android,
        TargetPlatform.iOS,
      }),
    );

    testWidgets('with a denial and no progress', (WidgetTester tester) async {
      final OneTapLocationController controller = OneTapLocationController();
      addTearDown(controller.dispose);
      final List<bool> locating = <bool>[];
      controller.addListener(() => locating.add(controller.isLocating));
      final List<OneTapLocationResult> results = <OneTapLocationResult>[];
      location.result = const OneTapLocationDenied();
      await tester.pumpWidget(
        buildButton(onResult: results.add, controller: controller),
      );

      await tap(tester);

      expect(results, <OneTapLocationResult>[const OneTapLocationDenied()]);
      expect(locating, isEmpty);
    }, variant: onAndroid);

    testWidgets('step by step', (WidgetTester tester) async {
      final OneTapLocationController controller = OneTapLocationController();
      addTearDown(controller.dispose);
      final List<OneTapLocationResult> results = <OneTapLocationResult>[];
      await tester.pumpWidget(
        buildButton(onResult: results.add, controller: controller),
      );

      await tap(tester);
      final FakeLocationRequest request = location.requests.single;
      expect(request.isPending, isTrue);
      expect(controller.isLocating, isFalse);
      expect(onPressed(tester), isNull);

      request.grantAccess();
      await tester.pump();
      expect(controller.isLocating, isTrue);
      expect(onPressed(tester), isNull);

      request.complete(_servicesDisabled);
      await tester.pump();
      expect(controller.isLocating, isFalse);
      expect(results, <OneTapLocationResult>[_servicesDisabled]);
      expect(request.isPending, isFalse);
      expect(onPressed(tester), isNotNull);
    }, variant: onAndroid);

    testWidgets(
      'with progress before a result when access was not granted',
      (WidgetTester tester) async {
        final OneTapLocationController controller = OneTapLocationController();
        addTearDown(controller.dispose);
        final List<bool> locating = <bool>[];
        controller.addListener(() => locating.add(controller.isLocating));
        await tester.pumpWidget(buildButton(controller: controller));

        await tap(tester);
        location.requests.single.complete(_granted);
        await tester.pump();

        expect(locating, <bool>[true, false]);
      },
      variant: onAndroid,
    );

    testWidgets('with a denial after access was granted', (
      WidgetTester tester,
    ) async {
      final OneTapLocationController controller = OneTapLocationController();
      addTearDown(controller.dispose);
      final List<bool> locating = <bool>[];
      controller.addListener(() => locating.add(controller.isLocating));
      final List<OneTapLocationResult> results = <OneTapLocationResult>[];
      await tester.pumpWidget(
        buildButton(onResult: results.add, controller: controller),
      );

      await tap(tester);
      location.requests.single
        ..grantAccess()
        ..complete(const OneTapLocationDenied());
      await tester.pump();

      expect(locating, <bool>[true, false]);
      expect(results, <OneTapLocationResult>[const OneTapLocationDenied()]);
    }, variant: onAndroid);

    testWidgets('with turned off location services and no progress on iOS', (
      WidgetTester tester,
    ) async {
      final OneTapLocationController controller = OneTapLocationController();
      addTearDown(controller.dispose);
      final List<bool> locating = <bool>[];
      controller.addListener(() => locating.add(controller.isLocating));
      final List<OneTapLocationResult> results = <OneTapLocationResult>[];
      location.result = _servicesDisabled;
      await tester.pumpWidget(
        buildButton(onResult: results.add, controller: controller),
      );

      await tap(tester);

      expect(results, <OneTapLocationResult>[_servicesDisabled]);
      expect(locating, isEmpty);
    }, variant: onIOS);

    testWidgets('with the preset result after the tap has been handled', (
      WidgetTester tester,
    ) async {
      final List<String> events = <String>[];
      location.result = _granted;
      await tester.pumpWidget(
        buildButton(
          onResult: (OneTapLocationResult result) => events.add('result'),
          fallbackBuilder: (BuildContext context, VoidCallback? onPressed) {
            return OutlinedButton(
              onPressed: onPressed == null
                  ? null
                  : () {
                      onPressed();
                      events.add('pressed');
                    },
              child: const Text('Use my location'),
            );
          },
        ),
      );

      await tester.tap(find.text('Use my location'));
      await tester.pump();

      expect(events, <String>['pressed', 'result']);
    }, variant: onAndroid);

    testWidgets(
      'with a diagnostic when the permission request is interrupted',
      (WidgetTester tester) async {
        final OneTapLocationController controller = OneTapLocationController();
        addTearDown(controller.dispose);
        final List<OneTapLocationDiagnostic> diagnostics =
            <OneTapLocationDiagnostic>[];
        final StreamSubscription<OneTapLocationDiagnostic> subscription =
            controller.diagnostics.listen(diagnostics.add);
        addTearDown(subscription.cancel);
        final List<OneTapLocationResult> results = <OneTapLocationResult>[];
        await tester.pumpWidget(
          buildButton(onResult: results.add, controller: controller),
        );

        await tap(tester);
        location.requests.single.dismiss();
        await tester.pump();

        expect(diagnostics, <OneTapLocationDiagnostic>[
          OneTapLocationDiagnostic.tapWithoutAuthorization,
        ]);
        expect(results, isEmpty);
        expect(onPressed(tester), isNotNull);
      },
      variant: onAndroid,
    );

    testWidgets('once while a request waits', (WidgetTester tester) async {
      await tester.pumpWidget(buildButton());

      await tap(tester);
      await tap(tester);

      expect(location.requests, hasLength(1));
    }, variant: onAndroid);

    testWidgets('once when a second tap arrives before the next frame', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildButton());

      await tester.tap(find.byType(OneTapLocationButton));
      await tester.tap(find.byType(OneTapLocationButton));
      await tester.pumpWidget(const SizedBox.shrink());

      expect(location.requests, hasLength(1));
      expect(location.requests.single.isPending, isFalse);
    }, variant: onAndroid);

    testWidgets('with errors of the app reported to FlutterError', (
      WidgetTester tester,
    ) async {
      location.result = _granted;
      await tester.pumpWidget(
        buildButton(
          onResult: (OneTapLocationResult result) =>
              throw StateError('Failure in the app.'),
        ),
      );

      await tap(tester);

      expect(tester.takeException(), isStateError);
      expect(onPressed(tester), isNotNull);
    }, variant: onAndroid);
  });

  testWidgets('rejects answers that no user could give', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildButton());
    await tap(tester);
    final FakeLocationRequest request = location.requests.single;

    request.grantAccess();
    expect(request.grantAccess, throwsStateError);
    expect(request.dismiss, throwsStateError);
    request.complete(_granted);
    expect(() => request.complete(_granted), throwsStateError);
    expect(request.dismiss, throwsStateError);
  }, variant: onAndroid);

  testWidgets('ignores answers to the request of a removed button', (
    WidgetTester tester,
  ) async {
    final OneTapLocationController controller = OneTapLocationController();
    addTearDown(controller.dispose);
    final List<OneTapLocationResult> results = <OneTapLocationResult>[];
    await tester.pumpWidget(
      buildButton(onResult: results.add, controller: controller),
    );
    await tap(tester);
    final FakeLocationRequest request = location.requests.single;
    request.grantAccess();
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    request.complete(_granted);
    await tester.pump();

    expect(request.isPending, isFalse);
    expect(results, isEmpty);
    expect(controller.isLocating, isFalse);
  }, variant: onAndroid);

  group('describes', () {
    testWidgets('the availability on Android', (WidgetTester tester) async {
      location
        ..hasAndroidSystemButton = true
        ..isPreciseLocationRestrictedToSystemButton = true;

      expect(
        await OneTapLocationButton.checkAvailability(),
        const OneTapLocationAvailability(
          buttonType: OneTapLocationButtonType.system,
          isPreciseLocationRestrictedToSystemButton: true,
        ),
      );
      expect(platformCalls, isEmpty);
    }, variant: onAndroid);

    testWidgets('the availability on iOS', (WidgetTester tester) async {
      location
        ..hasAndroidSystemButton = false
        ..isPreciseLocationRestrictedToSystemButton = true;

      expect(
        await OneTapLocationButton.checkAvailability(),
        const OneTapLocationAvailability(
          buttonType: OneTapLocationButtonType.system,
        ),
      );

      location.hasIOSSystemButton = false;
      expect(
        await OneTapLocationButton.checkAvailability(),
        const OneTapLocationAvailability(
          buttonType: OneTapLocationButtonType.none,
        ),
      );
      expect(platformCalls, isEmpty);
    }, variant: onIOS);
  });

  group('install', () {
    testWidgets('replaces the fake installed before', (
      WidgetTester tester,
    ) async {
      final FakeOneTapLocation replacement = FakeOneTapLocation.install();
      addTearDown(replacement.uninstall);
      replacement.result = const OneTapLocationDenied();
      final List<OneTapLocationResult> results = <OneTapLocationResult>[];
      await tester.pumpWidget(buildButton(onResult: results.add));

      await tap(tester);

      expect(location.requests, isEmpty);
      expect(results, <OneTapLocationResult>[const OneTapLocationDenied()]);
    }, variant: onAndroid);

    testWidgets('does not change buttons that exist already', (
      WidgetTester tester,
    ) async {
      location.uninstall();
      resetPlatformStateForTesting();
      await tester.pumpWidget(buildButton());

      final FakeOneTapLocation later = FakeOneTapLocation.install();
      addTearDown(later.uninstall);
      await tester.pumpWidget(buildButton());

      expect(platformCalls, <String>['one_tap_location getAvailability']);
      expect(find.byType(FilledButton), findsNothing);
    }, variant: onAndroid);
  });

  group('uninstall', () {
    testWidgets('leaves new buttons to the platform', (
      WidgetTester tester,
    ) async {
      location.uninstall();
      resetPlatformStateForTesting();

      await tester.pumpWidget(buildButton());

      expect(platformCalls, <String>['one_tap_location getAvailability']);
    }, variant: onAndroid);

    testWidgets('keeps a fake that replaced this one', (
      WidgetTester tester,
    ) async {
      final FakeOneTapLocation replacement = FakeOneTapLocation.install();
      addTearDown(replacement.uninstall);
      replacement.result = const OneTapLocationDenied();
      final List<OneTapLocationResult> results = <OneTapLocationResult>[];

      location.uninstall();
      await tester.pumpWidget(buildButton(onResult: results.add));
      await tap(tester);

      expect(platformCalls, isEmpty);
      expect(results, <OneTapLocationResult>[const OneTapLocationDenied()]);
    }, variant: onAndroid);
  });
}
