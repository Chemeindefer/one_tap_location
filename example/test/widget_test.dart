// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_tap_location/one_tap_location.dart';
import 'package:one_tap_location/testing.dart';
import 'package:one_tap_location_example/main.dart';
import 'package:one_tap_location_example/src/announcements.dart';
import 'package:one_tap_location_example/src/decorations.dart';
import 'package:one_tap_location_example/src/panels.dart';
import 'package:one_tap_location_example/src/plugin_version.dart';
import 'package:one_tap_location_example/src/theme.dart';

import 'ios_button_size.dart';

final TargetPlatformVariant onAndroid = TargetPlatformVariant.only(
  TargetPlatform.android,
);
final TargetPlatformVariant onIOS = TargetPlatformVariant.only(
  TargetPlatform.iOS,
);
final TargetPlatformVariant onMobile = TargetPlatformVariant(<TargetPlatform>{
  TargetPlatform.android,
  TargetPlatform.iOS,
});

const String promptHint = 'Nothing is shared until you tap.';
const String grantedHint =
    'Each tap grants access again — no alert after the first.';

void main() {
  late FakeOneTapLocation location;

  setUp(() {
    location = FakeOneTapLocation.install()
      ..iosButtonSize = shareCurrentLocationButtonSize;
    addTearDown(location.uninstall);
  });

  Future<void> startApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ExampleApp(availability: await OneTapLocationButton.checkAvailability()),
    );
    await tester.pump();
  }

  Future<FakeLocationRequest> tapButton(WidgetTester tester) async {
    await tester.tap(find.byType(OneTapLocationButton));
    await tester.pump();
    return location.requests.last;
  }

  OneTapLocationGranted granted({
    bool isPrecise = true,
    double? altitude = 41.2,
  }) {
    return OneTapLocationGranted(
      OneTapPosition(
        latitude: 41.02551,
        longitude: 28.97538,
        horizontalAccuracy: isPrecise ? 12.4 : 2000,
        altitude: altitude,
        timestamp: DateTime.now(),
        isPrecise: isPrecise,
      ),
    );
  }

  // Hints below the button and the texts of the copy button keep their space
  // while hidden.
  Finder shown(String text) {
    return find.byWidgetPredicate(
      (Widget widget) =>
          widget is Visibility &&
          widget.visible &&
          widget.child is Text &&
          (widget.child as Text).data == text,
    );
  }

  testWidgets('introduces the system button', (WidgetTester tester) async {
    await startApp(tester);

    expect(find.text('One Tap Example'), findsOneWidget);
    expect(find.text('one_tap_location $pluginVersion'), findsOneWidget);
    expect(find.text('button: system'), findsOneWidget);
    expect(find.text('Share your location once'), findsOneWidget);
    expect(find.textContaining('doesn’t offer the system'), findsNothing);
    expect(find.text('NO LOCATION YET'), findsOneWidget);
    expect(shown(promptHint), findsOneWidget);
  }, variant: onIOS);

  testWidgets('introduces the system button on Android', (
    WidgetTester tester,
  ) async {
    location.hasAndroidSystemButton = true;
    await startApp(tester);

    expect(find.text('button: system'), findsOneWidget);
    expect(find.text('Share your location once'), findsOneWidget);
    expect(find.textContaining('doesn’t offer the system'), findsNothing);
    expect(shown(promptHint), findsOneWidget);
  }, variant: onAndroid);

  testWidgets('introduces the fallback button', (WidgetTester tester) async {
    await startApp(tester);

    expect(find.text('button: fallback'), findsOneWidget);
    expect(
      find.text(
        'This device doesn’t offer the system location button — the package '
        'draws its own and opens the standard permission dialog.',
      ),
      findsOneWidget,
    );
    expect(find.text('Share your location once'), findsNothing);
    expect(find.text('NO LOCATION YET'), findsOneWidget);
    expect(shown(promptHint), findsOneWidget);
  }, variant: onAndroid);

  testWidgets('shows progress while the position is determined', (
    WidgetTester tester,
  ) async {
    await startApp(tester);

    final FakeLocationRequest request = await tapButton(tester);
    request.grantAccess();
    await tester.pump();

    expect(find.text('Getting location…'), findsOneWidget);
    expect(find.text('isLocating: true'), findsOneWidget);
    expect(find.text('Share your location once'), findsNothing);
    expect(shown(promptHint), findsNothing);
  }, variant: onMobile);

  testWidgets('shows a precise position', (WidgetTester tester) async {
    await startApp(tester);

    (await tapButton(tester)).complete(granted());
    await tester.pump();

    expect(find.text('PRECISE'), findsOneWidget);
    expect(find.text('41.025510° N\n28.975380° E'), findsOneWidget);
    expect(find.text('±12.4\u00A0m'), findsOneWidget);
    expect(find.text('41.2\u00A0m'), findsOneWidget);
    expect(find.textContaining('\u00A0· just now'), findsOneWidget);
    expect(find.text('true'), findsOneWidget);
    expect(find.text('OneTapLocationGranted'), findsOneWidget);
    expect(shown(promptHint), findsNothing);
    expect(
      shown(grantedHint),
      defaultTargetPlatform == TargetPlatform.iOS
          ? findsOneWidget
          : findsNothing,
    );
  }, variant: onMobile);

  testWidgets('copies the result and confirms it for a moment', (
    WidgetTester tester,
  ) async {
    final List<MethodCall> calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final OneTapLocationGranted result = granted();
    await startApp(tester);
    (await tapButton(tester)).complete(result);
    await tester.pump();

    final Size buttonSize = tester.getSize(find.byType(TextButton));
    await tester.tap(find.text('Copy result'));
    await tester.pump();

    expect(tester.getSize(find.byType(TextButton)), buttonSize);
    final MethodCall copy = calls.singleWhere(
      (MethodCall call) => call.method == 'Clipboard.setData',
    );
    expect(copy.arguments, <String, Object?>{'text': result.toString()});
    expect(shown('Copied'), findsOneWidget);
    expect(shown('Copy result'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1499));
    expect(shown('Copied'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1));
    expect(shown('Copy result'), findsOneWidget);
    expect(shown('Copied'), findsNothing);
  }, variant: onIOS);

  testWidgets('starts a new result without the copy confirmation', (
    WidgetTester tester,
  ) async {
    await startApp(tester);
    (await tapButton(tester)).complete(granted());
    await tester.pump();
    await tester.tap(find.text('Copy result'));
    await tester.pump();
    expect(shown('Copied'), findsOneWidget);

    (await tapButton(tester)).complete(granted(altitude: 12));
    await tester.pump();

    expect(find.text('12.0\u00A0m'), findsOneWidget);
    expect(shown('Copied'), findsNothing);
    expect(shown('Copy result'), findsOneWidget);
  }, variant: onIOS);

  testWidgets('explains the age of an approximate position on Android', (
    WidgetTester tester,
  ) async {
    await startApp(tester);

    (await tapButton(
      tester,
    )).complete(granted(isPrecise: false, altitude: null));
    await tester.pump();

    expect(find.text('APPROXIMATE'), findsOneWidget);
    expect(find.text('±2000.0\u00A0m'), findsOneWidget);
    expect(find.text('— (null when approximate)'), findsOneWidget);
    expect(
      find.text(
        'Approximate fixes can be up to 10\u00A0minutes old — check the '
        'timestamp.',
      ),
      findsOneWidget,
    );
  }, variant: onAndroid);

  testWidgets(
    'explains nothing for an approximate position of the system button',
    (WidgetTester tester) async {
      location.hasAndroidSystemButton = true;
      await startApp(tester);

      (await tapButton(
        tester,
      )).complete(granted(isPrecise: false, altitude: null));
      await tester.pump();

      expect(find.text('APPROXIMATE'), findsOneWidget);
      expect(find.textContaining('Approximate fixes'), findsNothing);
    },
    variant: onMobile,
  );

  testWidgets('shows a missing altitude of a precise position', (
    WidgetTester tester,
  ) async {
    await startApp(tester);

    (await tapButton(tester)).complete(granted(altitude: null));
    await tester.pump();

    expect(find.text('—'), findsOneWidget);
  }, variant: onAndroid);

  testWidgets('shows a denied request', (WidgetTester tester) async {
    await startApp(tester);

    (await tapButton(tester)).complete(const OneTapLocationDenied());
    await tester.pump();

    expect(find.text('OneTapLocationDenied'), findsOneWidget);
    expect(find.text('Access declined'), findsOneWidget);
    expect(
      find.text(
        'You or a device policy declined this request. No location was shared.',
      ),
      findsOneWidget,
    );
    expect(shown(promptHint), findsNothing);
  }, variant: onMobile);

  testWidgets('shows a failure with the platform message', (
    WidgetTester tester,
  ) async {
    await startApp(tester);

    (await tapButton(tester)).complete(
      const OneTapLocationFailed(
        OneTapLocationException(
          OneTapLocationErrorCode.locationUnavailable,
          'kCLErrorDomain error 0',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('locationUnavailable'), findsOneWidget);
    expect(find.text('Couldn’t get a location'), findsOneWidget);
    expect(
      find.text('The system didn’t deliver a fix and doesn’t say why.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'message: "kCLErrorDomain error 0"\nfor logs only\u00A0· untranslated',
      ),
      findsOneWidget,
    );
  }, variant: onIOS);

  testWidgets('names the reason when location services are off', (
    WidgetTester tester,
  ) async {
    await startApp(tester);

    (await tapButton(tester)).complete(
      const OneTapLocationFailed(
        OneTapLocationException(
          OneTapLocationErrorCode.locationServicesDisabled,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('locationServicesDisabled'), findsOneWidget);
    expect(
      find.text('Location services are off. Turn them on in system settings.'),
      findsOneWidget,
    );
    expect(find.textContaining('doesn’t say why'), findsNothing);
    expect(find.textContaining('message: '), findsNothing);
  }, variant: onMobile);

  testWidgets('shows only the platform message of an unknown failure', (
    WidgetTester tester,
  ) async {
    await startApp(tester);

    (await tapButton(tester)).complete(
      const OneTapLocationFailed(
        OneTapLocationException(
          OneTapLocationErrorCode.unknown,
          'Unexpected error',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('unknown'), findsOneWidget);
    expect(
      find.text(
        'message: "Unexpected error"\nfor logs only\u00A0· untranslated',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('doesn’t say why'), findsNothing);
    expect(find.textContaining('Location services are off'), findsNothing);
    // The message box follows the title 12 logical pixels below it, and its
    // text starts after the box padding.
    expect(
      tester.getTopLeft(find.textContaining('message: ')).dy -
          tester.getBottomLeft(find.text('Couldn’t get a location')).dy,
      12 + 9,
    );
  }, variant: onAndroid);

  testWidgets('reports a tap without authorization until a result arrives', (
    WidgetTester tester,
  ) async {
    await startApp(tester);

    (await tapButton(tester)).dismiss();
    await tester.pump();

    expect(find.text('Tap without authorization'), findsOneWidget);
    expect(find.text('Share your location once'), findsOneWidget);
    expect(find.text('NO LOCATION YET'), findsNothing);
    expect(shown(promptHint), findsNothing);

    (await tapButton(tester)).complete(const OneTapLocationDenied());
    await tester.pump();

    expect(find.text('Tap without authorization'), findsNothing);
    expect(find.text('Access declined'), findsOneWidget);
  }, variant: onIOS);

  testWidgets('replaces the tap without authorization with progress', (
    WidgetTester tester,
  ) async {
    await startApp(tester);
    (await tapButton(tester)).dismiss();
    await tester.pump();

    final FakeLocationRequest request = await tapButton(tester);
    request.grantAccess();
    await tester.pump();

    expect(find.text('Tap without authorization'), findsNothing);
    expect(find.text('Getting location…'), findsOneWidget);

    request.complete(granted());
    await tester.pump();

    expect(find.text('Location received'), findsOneWidget);
  }, variant: onIOS);

  testWidgets('keeps the button in place when the hint changes', (
    WidgetTester tester,
  ) async {
    await startApp(tester);
    Offset buttonPosition() {
      return tester.getTopLeft(find.byType(OneTapLocationButton));
    }

    final Offset initial = buttonPosition();
    final FakeLocationRequest request = await tapButton(tester);
    request.grantAccess();
    await tester.pump();
    expect(buttonPosition(), initial);

    request.complete(granted());
    await tester.pump();
    expect(shown(grantedHint), findsOneWidget);
    expect(buttonPosition(), initial);

    (await tapButton(tester)).dismiss();
    await tester.pump();
    expect(buttonPosition(), initial);
  }, variant: onIOS);

  testWidgets('follows the dark theme of the device', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await startApp(tester);

    expect(
      Theme.of(tester.element(find.byType(Scaffold))).scaffoldBackgroundColor,
      ExampleColors.dark.background,
    );
  }, variant: onIOS);

  testWidgets('shows the intro in the first frame', (
    WidgetTester tester,
  ) async {
    final OneTapLocationAvailability availability =
        await OneTapLocationButton.checkAvailability();
    await tester.pumpWidget(ExampleApp(availability: availability));

    expect(find.text('button: system'), findsOneWidget);
    expect(find.text('Share your location once'), findsOneWidget);
  }, variant: onIOS);

  testWidgets('starts without the button type when the check failed', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ExampleApp(availability: null));
    await tester.pump();

    expect(find.textContaining('button: '), findsNothing);
    expect(find.text('Share your location once'), findsNothing);
    expect(find.text('NO LOCATION YET'), findsOneWidget);
    expect(find.byType(OneTapLocationButton), findsOneWidget);
  }, variant: onIOS);

  testWidgets('marks the titles as headings', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    location.hasAndroidSystemButton = true;
    await startApp(tester);

    void expectHeading(String title, {required int level}) {
      final SemanticsNode node = tester.getSemantics(find.text(title));
      expect(node, isSemantics(label: title, isHeader: true));
      // Android reports a heading only with a heading level.
      expect(node.getSemanticsData().headingLevel, level);
    }

    expectHeading('One Tap Example', level: 1);
    expectHeading('Share your location once', level: 2);
    expectHeading('NO LOCATION YET', level: 2);

    final FakeLocationRequest request = await tapButton(tester);
    request.grantAccess();
    await tester.pump();
    expectHeading('Getting location…', level: 2);

    request.complete(granted());
    await tester.pump();
    expectHeading('Location received', level: 2);

    (await tapButton(tester)).complete(const OneTapLocationDenied());
    await tester.pump();
    expectHeading('Access declined', level: 2);
    expect(
      tester.getSemantics(find.textContaining('You or a device policy')),
      isSemantics(isHeader: false),
    );

    (await tapButton(tester)).complete(
      const OneTapLocationFailed(
        OneTapLocationException(OneTapLocationErrorCode.locationUnavailable),
      ),
    );
    await tester.pump();
    expectHeading('Couldn’t get a location', level: 2);

    (await tapButton(tester)).dismiss();
    await tester.pump();
    expectHeading('Tap without authorization', level: 2);
    semantics.dispose();
  }, variant: onMobile);

  testWidgets('scrolls a status below the visible content into view', (
    WidgetTester tester,
  ) async {
    tester.view
      ..physicalSize = const Size(667, 375)
      ..devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await startApp(tester);
    final Rect content = tester.getRect(find.byType(SingleChildScrollView));

    (await tapButton(tester)).complete(const OneTapLocationDenied());
    await tester.pumpAndSettle();
    // The content scrolls just far enough to show the card and the space
    // below it.
    final Rect card = tester.getRect(find.byType(DeniedCard));
    expect(card.top, greaterThan(content.top + 20));
    expect(content.bottom - card.bottom, 20);

    // A status taller than the visible content shows its start.
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    (await tapButton(tester)).dismiss();
    await tester.pumpAndSettle();
    final Rect largeContent = tester.getRect(
      find.byType(SingleChildScrollView),
    );
    final Rect banner = tester.getRect(
      find.byType(TapWithoutAuthorizationBanner),
    );
    expect(banner.height, greaterThan(largeContent.height));
    expect(banner.top, largeContent.top);
  }, variant: onAndroid);

  testWidgets('shows the status at once when animations are off', (
    WidgetTester tester,
  ) async {
    tester.view
      ..physicalSize = const Size(667, 375)
      ..devicePixelRatio = 1;
    tester.platformDispatcher
      ..textScaleFactorTestValue = 1.3
      ..accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        supportsAnnounce: true,
        disableAnimations: true,
      );
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await startApp(tester);
    final Rect content = tester.getRect(find.byType(SingleChildScrollView));

    final FakeLocationRequest request = await tapButton(tester);
    request.grantAccess();
    // The ink of the tap fades out, and the spinner stands still.
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(ProgressSpinner), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);

    request.complete(const OneTapLocationDenied());
    await tester.pump();
    expect(content.bottom - tester.getRect(find.byType(DeniedCard)).bottom, 20);
  }, variant: onAndroid);

  testWidgets('leaves the content to a user who scrolls it', (
    WidgetTester tester,
  ) async {
    tester.view
      ..physicalSize = const Size(667, 375)
      ..devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await startApp(tester);
    final FakeLocationRequest request = await tapButton(tester);
    request.grantAccess();
    await tester.pump(const Duration(seconds: 1));
    final ScrollPosition position = Scrollable.of(
      tester.element(find.byType(LocatingCard)),
    ).position;
    position.jumpTo(0);
    await tester.pump();

    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byType(SingleChildScrollView)),
    );
    await gesture.moveBy(const Offset(0, -40));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -20));
    await tester.pump();
    request.complete(const OneTapLocationDenied());
    await tester.pump();
    final double pixels = position.pixels;
    expect(pixels, greaterThan(0));

    await gesture.moveBy(const Offset(0, -20));
    await tester.pump();
    expect(position.pixels, pixels + 20);
    await gesture.up();
    await tester.pump(const Duration(seconds: 1));
  }, variant: onAndroid);

  group('with announcements', () {
    testWidgets('announces the outcome once the layout settles', (
      WidgetTester tester,
    ) async {
      await startApp(tester);
      final FakeLocationRequest request = await tapButton(tester);
      request.grantAccess();
      await tester.pump(const Duration(milliseconds: 999));
      expect(tester.takeAnnouncements(), isEmpty);

      // An outcome within the delay replaces the pending announcement.
      request.complete(granted());
      await tester.pump(const Duration(milliseconds: 999));
      expect(tester.takeAnnouncements(), isEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      expect(tester.takeAnnouncements(), <Matcher>[
        isAccessibilityAnnouncement(
          'Location received, precise',
          textDirection: TextDirection.ltr,
        ),
      ]);
    }, variant: onIOS);

    testWidgets('reports the status without a live region', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await startApp(tester);
      (await tapButton(tester)).complete(granted());
      await tester.pump(const Duration(seconds: 1));

      expect(tester.takeAnnouncements(), <Matcher>[
        isAccessibilityAnnouncement('Location received, precise'),
      ]);
      // A live region would speak the status a second time.
      expect(find.semantics.byFlag(SemanticsFlag.isLiveRegion), findsNothing);
      semantics.dispose();
    }, variant: onIOS);

    testWidgets('announces progress', (WidgetTester tester) async {
      await startApp(tester);
      (await tapButton(tester)).grantAccess();
      await tester.pump(const Duration(seconds: 1));

      expect(tester.takeAnnouncements(), <Matcher>[
        isAccessibilityAnnouncement('Getting location…'),
      ]);
    }, variant: onIOS);

    testWidgets('announces a repeated outcome again', (
      WidgetTester tester,
    ) async {
      await startApp(tester);

      for (int tap = 0; tap < 2; tap++) {
        (await tapButton(tester)).complete(const OneTapLocationDenied());
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeAnnouncements(), <Matcher>[
          isAccessibilityAnnouncement('Access declined'),
        ]);
      }
      for (int tap = 0; tap < 2; tap++) {
        (await tapButton(tester)).dismiss();
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeAnnouncements(), <Matcher>[
          isAccessibilityAnnouncement('Tap without authorization'),
        ]);
      }
    }, variant: onIOS);

    testWidgets('announces a failure and the copy of a result', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await startApp(tester);
      (await tapButton(tester)).complete(
        const OneTapLocationFailed(
          OneTapLocationException(OneTapLocationErrorCode.locationUnavailable),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeAnnouncements(), <Matcher>[
        isAccessibilityAnnouncement('Couldn’t get a location'),
      ]);

      (await tapButton(tester)).complete(granted(isPrecise: false));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeAnnouncements(), <Matcher>[
        isAccessibilityAnnouncement('Location received, approximate'),
      ]);

      await tester.tap(find.text('Copy result'));
      await tester.pump();
      // A live region would speak the confirmation a second time.
      expect(
        tester.getSemantics(find.byType(TextButton)),
        isSemantics(label: 'Copied', isLiveRegion: false),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeAnnouncements(), <Matcher>[
        isAccessibilityAnnouncement('Copied'),
      ]);
      semantics.dispose();
    }, variant: onIOS);
  });

  group('without announcements', () {
    setUp(() {
      // Flutter reports no announcement support on Android.
      TestWidgetsFlutterBinding
              .instance
              .platformDispatcher
              .accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures();
    });

    tearDown(() {
      TestWidgetsFlutterBinding.instance.platformDispatcher
          .clearAccessibilityFeaturesTestValue();
    });

    SemanticsNode statusRegion(WidgetTester tester) {
      return tester.getSemantics(find.byType(StatusLiveRegion));
    }

    testWidgets('reports the outcome in a live region', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await startApp(tester);
      expect(
        statusRegion(tester),
        isSemantics(label: '', isLiveRegion: true, hasTapAction: false),
      );

      final FakeLocationRequest request = await tapButton(tester);
      request.grantAccess();
      await tester.pump();
      expect(
        statusRegion(tester),
        isSemantics(label: 'Getting location…', isLiveRegion: true),
      );

      request.complete(granted());
      await tester.pump();
      final SemanticsNode region = statusRegion(tester);
      expect(
        region,
        isSemantics(label: 'Location received, precise', isLiveRegion: true),
      );
      // Users reach the status in the content, not as a stop of its own.
      expect(
        region.getSemanticsData().flagsCollection.isAccessibilityFocusBlocked,
        isTrue,
      );
      expect(
        tester.getSemantics(find.text('Location received')),
        isSemantics(label: 'Location received', isLiveRegion: false),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeAnnouncements(), isEmpty);
      semantics.dispose();
    }, variant: onAndroid);

    testWidgets('reports a repeated outcome in a new live region', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await startApp(tester);

      (await tapButton(tester)).complete(const OneTapLocationDenied());
      await tester.pump();
      final SemanticsNode first = statusRegion(tester);
      expect(first, isSemantics(label: 'Access declined', isLiveRegion: true));

      (await tapButton(tester)).complete(const OneTapLocationDenied());
      await tester.pump();
      final SemanticsNode second = statusRegion(tester);
      expect(second, isSemantics(label: 'Access declined', isLiveRegion: true));
      expect(second.id, isNot(first.id));
      semantics.dispose();
    }, variant: onAndroid);

    testWidgets(
      'keeps the live region on screen while the content scrolls',
      (WidgetTester tester) async {
        final SemanticsHandle semantics = tester.ensureSemantics();
        tester.view
          ..physicalSize = const Size(667, 375)
          ..devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await startApp(tester);

        // The banner starts below the visible content. A live region that is
        // out of view does not speak.
        (await tapButton(tester)).dismiss();
        await tester.pump();
        expect(
          statusRegion(tester),
          isSemantics(
            label: 'Tap without authorization',
            isLiveRegion: true,
            isHidden: false,
          ),
        );
        await tester.pumpAndSettle();
        semantics.dispose();
      },
      variant: onAndroid,
    );

    testWidgets('speaks the copy confirmation but not its end', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await startApp(tester);
      (await tapButton(tester)).complete(granted());
      await tester.pump();
      expect(
        tester.getSemantics(find.byType(TextButton)),
        isSemantics(label: 'Copy result', isButton: true, isLiveRegion: false),
      );

      await tester.tap(find.byType(TextButton));
      await tester.pump();
      expect(
        tester.getSemantics(find.byType(TextButton)),
        isSemantics(label: 'Copied', isButton: true, isLiveRegion: true),
      );

      await tester.pump(const Duration(milliseconds: 1500));
      expect(
        tester.getSemantics(find.byType(TextButton)),
        isSemantics(label: 'Copy result', isButton: true, isLiveRegion: false),
      );
      expect(tester.takeAnnouncements(), isEmpty);
      semantics.dispose();
    }, variant: onAndroid);
  });
}
