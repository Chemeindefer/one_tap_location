// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_tap_location/one_tap_location.dart';
import 'package:one_tap_location/src/fallback_button.dart' show InsetBorder;
import 'package:one_tap_location/src/platform.dart'
    show resetPlatformStateForTesting;

const MethodChannel _pluginChannel = MethodChannel('one_tap_location');
const StandardMethodCodec _methodCodec = StandardMethodCodec();

/// Longer than the time the button must stay fully visible before it is shown.
const Duration _afterShowDelay = Duration(seconds: 1);

/// Shorter than the time the button must stay fully visible before it is
/// shown.
const Duration _beforeShowDelay = Duration(milliseconds: 100);

const Map<String, Object?> _grantedResult = <String, Object?>{
  'status': 'granted',
  'position': <String, Object?>{
    'latitude': 41.0082,
    'longitude': 28.9784,
    'timestamp': 1757800000000,
    'isPrecise': true,
  },
};

final OneTapLocationGranted _grantedLocation = OneTapLocationGranted(
  OneTapPosition(
    latitude: 41.0082,
    longitude: 28.9784,
    timestamp: DateTime.fromMillisecondsSinceEpoch(1757800000000, isUtc: true),
    isPrecise: true,
  ),
);

Widget _center(Widget button) => Center(child: button);

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(_afterShowDelay);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final TargetPlatformVariant onIOS = TargetPlatformVariant.only(
    TargetPlatform.iOS,
  );
  final TargetPlatformVariant onAndroid = TargetPlatformVariant.only(
    TargetPlatform.android,
  );
  final TargetPlatformVariant onMobile = TargetPlatformVariant(<TargetPlatform>{
    TargetPlatform.iOS,
    TargetPlatform.android,
  });

  late List<MethodCall> measureCalls;
  late List<Completer<Object?>> pendingMeasurements;
  late bool deferMeasurements;
  late bool failMeasurements;
  late bool isSystemButtonAvailable;
  late int availabilityChecks;
  late bool deferAvailabilityChecks;
  late List<Completer<Object?>> pendingAvailabilityChecks;
  late List<Completer<Object?>> pendingPermissionRequests;
  late List<int> positionRequestIds;
  late List<Completer<Object?>> pendingPositionRequests;
  late List<int> cancelledPositionRequestIds;
  late bool isSurfaceControlEnabled;
  late int surfaceControlChecks;
  late bool deferCreation;
  late List<Completer<Object?>> pendingCreations;
  late List<({String channel, Map<Object?, Object?> arguments})> createCalls;
  late List<int> createdViewIds;
  late List<({int viewId, MethodCall call})> viewCalls;

  Future<Object?> pendingReply(List<Completer<Object?>> pendingReplies) {
    final Completer<Object?> completer = Completer<Object?>();
    pendingReplies.add(completer);
    return completer.future;
  }

  Map<String, Object?> availabilityFor(bool isSystemButtonAvailable) {
    return <String, Object?>{
      'isSystemButtonAvailable': isSystemButtonAvailable,
      'isPreciseLocationRestrictedToSystemButton': false,
    };
  }

  // The fake system requires a fractional size that grows with the font size.
  Map<String, Object?> sizeFor(MethodCall call) {
    final Map<Object?, Object?> style = call.arguments as Map<Object?, Object?>;
    final double fontSize = (style['iosFontSize'] as num?)?.toDouble() ?? 17;
    return <String, Object?>{
      'width': 12 * fontSize + 0.33,
      'height': 3 * fontSize + 0.5,
    };
  }

  Future<Object?> handlePlatformViewsCall(
    MethodChannel channel,
    MethodCall call,
  ) {
    switch (call.method) {
      case 'isSurfaceControlEnabled':
        surfaceControlChecks += 1;
        return Future<Object?>.value(isSurfaceControlEnabled);
      case 'create':
        final Map<Object?, Object?> arguments =
            call.arguments as Map<Object?, Object?>;
        final int viewId = arguments['id']! as int;
        createCalls.add((channel: channel.name, arguments: arguments));
        createdViewIds.add(viewId);
        messenger.setMockMethodCallHandler(
          MethodChannel('one_tap_location/location_button/$viewId'),
          (MethodCall call) async {
            viewCalls.add((viewId: viewId, call: call));
            return null;
          },
        );
        if (deferCreation) {
          final Completer<Object?> completer = Completer<Object?>();
          pendingCreations.add(completer);
          return completer.future;
        }
    }
    return Future<Object?>.value();
  }

  setUp(() {
    resetPlatformStateForTesting();
    measureCalls = <MethodCall>[];
    pendingMeasurements = <Completer<Object?>>[];
    deferMeasurements = false;
    failMeasurements = false;
    isSystemButtonAvailable = true;
    availabilityChecks = 0;
    deferAvailabilityChecks = false;
    pendingAvailabilityChecks = <Completer<Object?>>[];
    pendingPermissionRequests = <Completer<Object?>>[];
    positionRequestIds = <int>[];
    pendingPositionRequests = <Completer<Object?>>[];
    cancelledPositionRequestIds = <int>[];
    isSurfaceControlEnabled = false;
    surfaceControlChecks = 0;
    deferCreation = false;
    pendingCreations = <Completer<Object?>>[];
    createCalls = <({String channel, Map<Object?, Object?> arguments})>[];
    createdViewIds = <int>[];
    viewCalls = <({int viewId, MethodCall call})>[];
    messenger.setMockMethodCallHandler(_pluginChannel, (MethodCall call) {
      switch (call.method) {
        case 'getAvailability':
          availabilityChecks += 1;
          if (deferAvailabilityChecks) {
            return pendingReply(pendingAvailabilityChecks);
          }
          return Future<Object?>.value(
            availabilityFor(isSystemButtonAvailable),
          );
        case 'measureButton':
          measureCalls.add(call);
          if (failMeasurements) {
            throw PlatformException(code: 'unavailable');
          }
          if (!deferMeasurements) {
            return Future<Object?>.value(sizeFor(call));
          }
          return pendingReply(pendingMeasurements);
        case 'requestFallbackPermission':
          return pendingReply(pendingPermissionRequests);
        case 'requestFallbackPosition':
          positionRequestIds.add(call.arguments! as int);
          return pendingReply(pendingPositionRequests);
        case 'cancelFallbackPosition':
          cancelledPositionRequestIds.add(call.arguments! as int);
          return Future<Object?>.value();
      }
      return null;
    });
    for (final MethodChannel channel in <MethodChannel>[
      SystemChannels.platform_views,
      SystemChannels.platform_views_2,
    ]) {
      messenger.setMockMethodCallHandler(
        channel,
        (MethodCall call) => handlePlatformViewsCall(channel, call),
      );
    }
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(_pluginChannel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views_2, null);
    for (final int viewId in createdViewIds) {
      messenger.setMockMethodCallHandler(
        MethodChannel('one_tap_location/location_button/$viewId'),
        null,
      );
    }
  });

  Future<void> sendFromView(int id, String method, [Object? arguments]) async {
    await messenger.handlePlatformMessage(
      'one_tap_location/location_button/$id',
      _methodCodec.encodeMethodCall(MethodCall(method, arguments)),
      (ByteData? reply) {},
    );
  }

  List<Object?> callsTo(String method) {
    return <Object?>[
      for (final ({int viewId, MethodCall call}) viewCall in viewCalls)
        if (viewCall.call.method == method) viewCall.call.arguments,
    ];
  }

  Widget buildButton({
    Key? key,
    ValueChanged<OneTapLocationResult>? onResult,
    OneTapLocationController? controller,
    OneTapLocationButtonStyle style = const OneTapLocationButtonStyle(),
    OneTapLocationFallbackBuilder? fallbackBuilder,
    Widget Function(Widget button) wrap = _center,
  }) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: wrap(
        OneTapLocationButton(
          key: key,
          onResult: onResult ?? (OneTapLocationResult result) {},
          controller: controller,
          style: style,
          fallbackBuilder: fallbackBuilder,
        ),
      ),
    );
  }

  Route<void> pageRoute(Widget page) {
    return PageRouteBuilder<void>(pageBuilder: (_, _, _) => page);
  }

  Route<void> dialogRoute() {
    return RawDialogRoute<void>(
      barrierLabel: 'Dismiss',
      pageBuilder: (_, _, _) => const SizedBox(width: 100, height: 100),
    );
  }

  testWidgets(
    'renders nothing on platforms without a system button',
    (WidgetTester tester) async {
      await tester.pumpWidget(buildButton());
      await tester.pumpAndSettle();

      expect(measureCalls, isEmpty);
      expect(createCalls, isEmpty);
      expect(tester.getSize(find.byType(OneTapLocationButton)), Size.zero);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets(
    'asserts that a controller is attached to one button',
    (WidgetTester tester) async {
      final OneTapLocationController controller = OneTapLocationController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: <Widget>[
              OneTapLocationButton(
                controller: controller,
                onResult: (OneTapLocationResult result) {},
              ),
              OneTapLocationButton(
                controller: controller,
                onResult: (OneTapLocationResult result) {},
              ),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isAssertionError);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets('forwards progress, results and diagnostics', (
    WidgetTester tester,
  ) async {
    final OneTapLocationController controller = OneTapLocationController();
    addTearDown(controller.dispose);
    final List<OneTapLocationResult> results = <OneTapLocationResult>[];
    final List<OneTapLocationDiagnostic> diagnostics =
        <OneTapLocationDiagnostic>[];
    final StreamSubscription<OneTapLocationDiagnostic> subscription = controller
        .diagnostics
        .listen(diagnostics.add);
    addTearDown(subscription.cancel);

    await tester.pumpWidget(
      buildButton(onResult: results.add, controller: controller),
    );
    await tester.pumpAndSettle();
    final int viewId = createdViewIds.single;

    await sendFromView(viewId, 'onDiagnostic', <String, Object?>{
      'diagnostic': 'tapWithoutAuthorization',
    });
    await sendFromView(viewId, 'onLocating');
    expect(controller.isLocating, isTrue);

    await sendFromView(viewId, 'onResult', _grantedResult);
    await sendFromView(viewId, 'onResult', <String, Object?>{
      'status': 'denied',
    });
    await sendFromView(viewId, 'onResult', <String, Object?>{
      'status': 'failed',
      'code': 'locationUnavailable',
    });
    await tester.pump();

    expect(controller.isLocating, isFalse);
    expect(diagnostics, <OneTapLocationDiagnostic>[
      OneTapLocationDiagnostic.tapWithoutAuthorization,
    ]);
    expect(results, <OneTapLocationResult>[
      _grantedLocation,
      const OneTapLocationDenied(),
      const OneTapLocationFailed(
        OneTapLocationException(OneTapLocationErrorCode.locationUnavailable),
      ),
    ]);
  }, variant: onMobile);

  testWidgets('clears the location progress when the button is removed', (
    WidgetTester tester,
  ) async {
    final OneTapLocationController controller = OneTapLocationController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(buildButton(controller: controller));
    await tester.pumpAndSettle();
    await sendFromView(createdViewIds.single, 'onLocating');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(controller.isLocating, isFalse);
  }, variant: onMobile);

  testWidgets('moves the location progress to a new controller', (
    WidgetTester tester,
  ) async {
    final OneTapLocationController first = OneTapLocationController();
    addTearDown(first.dispose);
    final OneTapLocationController second = OneTapLocationController();
    addTearDown(second.dispose);
    await tester.pumpWidget(buildButton(controller: first));
    await tester.pumpAndSettle();
    await sendFromView(createdViewIds.single, 'onLocating');

    await tester.pumpWidget(buildButton(controller: second));
    await tester.pump();

    expect(first.isLocating, isFalse);
    expect(second.isLocating, isTrue);
  }, variant: onMobile);

  testWidgets('keeps the location progress of a button that moves', (
    WidgetTester tester,
  ) async {
    final OneTapLocationController controller = OneTapLocationController();
    addTearDown(controller.dispose);
    final GlobalKey buttonKey = GlobalKey();
    await tester.pumpWidget(
      buildButton(key: buttonKey, controller: controller),
    );
    await tester.pumpAndSettle();
    await sendFromView(createdViewIds.single, 'onLocating');

    await tester.pumpWidget(
      buildButton(
        key: buttonKey,
        controller: controller,
        wrap: (Widget button) => Align(child: button),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(controller.isLocating, isTrue);
  }, variant: onMobile);

  testWidgets(
    'resets the location progress of a button that is recreated',
    (WidgetTester tester) async {
      final OneTapLocationController controller = OneTapLocationController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(buildButton(controller: controller));
      await tester.pumpAndSettle();
      await sendFromView(createdViewIds.single, 'onLocating');

      await tester.pumpWidget(
        buildButton(
          controller: controller,
          wrap: (Widget button) => Align(child: button),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(controller.isLocating, isFalse);
    },
    variant: onMobile,
  );

  testWidgets('accepts a controller that moves to a replacement button', (
    WidgetTester tester,
  ) async {
    final OneTapLocationController controller = OneTapLocationController();
    addTearDown(controller.dispose);
    Widget keyed(int key) {
      return buildButton(
        key: ValueKey<int>(key),
        controller: controller,
        wrap: (Widget button) => Column(children: <Widget>[button]),
      );
    }

    await tester.pumpWidget(keyed(1));
    await tester.pumpAndSettle();
    await tester.pumpWidget(keyed(2));
    await tester.pumpAndSettle();
    await sendFromView(createdViewIds.last, 'onLocating');

    expect(tester.takeException(), isNull);
    expect(controller.isLocating, isTrue);
  }, variant: onMobile);

  testWidgets('notifies listeners once the button is removed', (
    WidgetTester tester,
  ) async {
    final OneTapLocationController controller = OneTapLocationController();
    addTearDown(controller.dispose);
    final ValueNotifier<bool> hasButton = ValueNotifier<bool>(true);
    addTearDown(hasButton.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: <Widget>[
            ListenableBuilder(
              listenable: controller,
              builder: (BuildContext context, Widget? child) =>
                  Text(controller.isLocating ? 'Locating' : 'Idle'),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: hasButton,
              builder: (BuildContext context, bool value, Widget? child) =>
                  value
                  ? OneTapLocationButton(
                      controller: controller,
                      onResult: (OneTapLocationResult result) {},
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await sendFromView(createdViewIds.single, 'onLocating');
    await tester.pump();
    expect(find.text('Locating'), findsOneWidget);

    hasButton.value = false;
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Idle'), findsOneWidget);
  }, variant: onMobile);

  testWidgets('notifies the listeners of both controllers when they swap', (
    WidgetTester tester,
  ) async {
    final OneTapLocationController first = OneTapLocationController();
    addTearDown(first.dispose);
    final OneTapLocationController second = OneTapLocationController();
    addTearDown(second.dispose);
    final ValueNotifier<bool> usesSecond = ValueNotifier<bool>(false);
    addTearDown(usesSecond.dispose);
    Widget progress(String name, OneTapLocationController controller) {
      return ListenableBuilder(
        listenable: controller,
        builder: (BuildContext context, Widget? child) =>
            Text('$name ${controller.isLocating ? 'locating' : 'idle'}'),
      );
    }

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: <Widget>[
            progress('first', first),
            progress('second', second),
            ValueListenableBuilder<bool>(
              valueListenable: usesSecond,
              builder: (BuildContext context, bool value, Widget? child) =>
                  OneTapLocationButton(
                    controller: value ? second : first,
                    onResult: (OneTapLocationResult result) {},
                  ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await sendFromView(createdViewIds.single, 'onLocating');
    await tester.pump();

    usesSecond.value = true;
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('first idle'), findsOneWidget);
    expect(find.text('second locating'), findsOneWidget);
  }, variant: onMobile);

  testWidgets('reports errors thrown while handling a result', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      buildButton(
        onResult: (OneTapLocationResult result) =>
            throw StateError('Failure in the app.'),
      ),
    );
    await tester.pumpAndSettle();

    await sendFromView(createdViewIds.single, 'onResult', <String, Object?>{
      'status': 'denied',
    });

    expect(tester.takeException(), isStateError);
  }, variant: onMobile);

  testWidgets('leaves unknown methods unhandled', (WidgetTester tester) async {
    await tester.pumpWidget(buildButton());
    await tester.pumpAndSettle();

    ByteData? reply = ByteData(1);
    await messenger.handlePlatformMessage(
      'one_tap_location/location_button/${createdViewIds.single}',
      _methodCodec.encodeMethodCall(const MethodCall('onUnknown')),
      (ByteData? data) => reply = data,
    );

    expect(reply, isNull);
  }, variant: onMobile);

  testWidgets('asserts that the background color is opaque', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      buildButton(
        style: const OneTapLocationButtonStyle(
          backgroundColor: Color(0x803366FF),
        ),
      ),
    );

    expect(tester.takeException(), isAssertionError);
  }, variant: onMobile);

  group('on iOS', () {
    testWidgets('sizes the system button to the size the system requires', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildButton(
          style: const OneTapLocationButtonStyle(
            iosLabel: IOSLocationButtonLabel.shareCurrentLocation,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Map<Object?, Object?> style =
          measureCalls.single.arguments as Map<Object?, Object?>;
      expect(style['iosLabel'], 'shareCurrentLocation');
      expect(tester.getSize(find.byType(UiKitView)), const Size(205, 52));
      expect(createdViewIds, hasLength(1));
    }, variant: onIOS);

    testWidgets('restyles the system button and resizes it once measured', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildButton());
      await tester.pumpAndSettle();
      deferMeasurements = true;

      await tester.pumpWidget(
        buildButton(style: const OneTapLocationButtonStyle(iosFontSize: 22)),
      );
      await tester.pump();

      expect(callsTo('setStyle'), <Object?>[
        <String, Object?>{
          'iosLabel': 'currentLocation',
          'iosIcon': 'arrowFilled',
          'iosFontSize': 22.0,
        },
      ]);
      expect(tester.getSize(find.byType(UiKitView)), const Size(205, 52));

      pendingMeasurements.single.complete(sizeFor(measureCalls.last));
      await tester.pumpAndSettle();

      expect(createdViewIds, hasLength(1));
      expect(tester.getSize(find.byType(UiKitView)), const Size(265, 67));
    }, variant: onIOS);

    testWidgets('sends a style that changed while the view was created', (
      WidgetTester tester,
    ) async {
      deferCreation = true;
      await tester.pumpWidget(buildButton());
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        buildButton(style: const OneTapLocationButtonStyle(cornerRadius: 12)),
      );
      pendingCreations.single.complete();
      await tester.pumpAndSettle();

      expect(createCalls, hasLength(1));
      expect(callsTo('setStyle'), <Object?>[
        <String, Object?>{
          'iosLabel': 'currentLocation',
          'iosIcon': 'arrowFilled',
          'cornerRadius': 12.0,
        },
      ]);
    }, variant: onIOS);

    testWidgets(
      'keeps the system button when only Android properties change',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildButton());
        await tester.pumpAndSettle();

        await tester.pumpWidget(
          buildButton(
            style: const OneTapLocationButtonStyle(
              androidLabel: AndroidLocationButtonLabel.none,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(measureCalls, hasLength(1));
        expect(createdViewIds, hasLength(1));
        expect(callsTo('setStyle'), isEmpty);
      },
      variant: onIOS,
    );

    testWidgets('reports a measurement that fails', (
      WidgetTester tester,
    ) async {
      failMeasurements = true;

      await tester.pumpWidget(buildButton());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isA<PlatformException>());
      expect(tester.getSize(find.byType(OneTapLocationButton)), Size.zero);
    }, variant: onIOS);

    testWidgets('ignores the measurement of a style that changed back', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildButton());
      await tester.pumpAndSettle();
      deferMeasurements = true;

      await tester.pumpWidget(
        buildButton(style: const OneTapLocationButtonStyle(iosFontSize: 22)),
      );
      await tester.pumpWidget(buildButton());
      pendingMeasurements.single.complete(sizeFor(measureCalls.last));
      await tester.pumpAndSettle();

      expect(measureCalls, hasLength(2));
      expect(createdViewIds, hasLength(1));
      expect(tester.getSize(find.byType(UiKitView)), const Size(205, 52));
    }, variant: onIOS);

    testWidgets('has no baseline on iOS', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildButton(
          wrap: (Widget button) => Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[const Text('Address'), button],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final RenderBox row = tester.renderObject(find.byType(Row));

      expect(
        () => row.getDryLayout(const BoxConstraints(maxWidth: 400)),
        returnsNormally,
      );
      expect(tester.takeException(), isNull);
    }, variant: onIOS);

    testWidgets('ignores the measurement of an outdated style', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildButton());
      await tester.pumpAndSettle();
      deferMeasurements = true;

      await tester.pumpWidget(
        buildButton(style: const OneTapLocationButtonStyle(iosFontSize: 22)),
      );
      await tester.pumpWidget(
        buildButton(style: const OneTapLocationButtonStyle(iosFontSize: 30)),
      );
      pendingMeasurements[1].complete(sizeFor(measureCalls[2]));
      await tester.pumpAndSettle();
      pendingMeasurements[0].complete(sizeFor(measureCalls[1]));
      await tester.pumpAndSettle();

      expect(createdViewIds, hasLength(1));
      expect(tester.getSize(find.byType(UiKitView)), const Size(361, 91));
    }, variant: onIOS);

    testWidgets('keeps a request in progress when the style changes', (
      WidgetTester tester,
    ) async {
      final OneTapLocationController controller = OneTapLocationController();
      addTearDown(controller.dispose);
      final List<OneTapLocationResult> results = <OneTapLocationResult>[];
      await tester.pumpWidget(
        buildButton(onResult: results.add, controller: controller),
      );
      await tester.pumpAndSettle();
      final int viewId = createdViewIds.single;
      await sendFromView(viewId, 'onLocating');

      await tester.pumpWidget(
        buildButton(
          onResult: results.add,
          controller: controller,
          style: const OneTapLocationButtonStyle(
            backgroundColor: Color(0xFF1A5CE5),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.isLocating, isTrue);

      await sendFromView(viewId, 'onResult', _grantedResult);

      expect(createdViewIds, hasLength(1));
      expect(measureCalls, hasLength(1));
      expect(callsTo('setStyle'), <Object?>[
        <String, Object?>{
          'iosLabel': 'currentLocation',
          'iosIcon': 'arrowFilled',
          'backgroundColor': 0xFF1A5CE5,
        },
      ]);
      expect(controller.isLocating, isFalse);
      expect(results, <OneTapLocationResult>[_grantedLocation]);
    }, variant: onIOS);

    testWidgets('gives a new button a size measured before right away', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildButton(key: const ValueKey<int>(1)));
      await tester.pumpAndSettle();
      deferMeasurements = true;

      await tester.pumpWidget(buildButton(key: const ValueKey<int>(2)));
      await tester.pump();

      expect(availabilityChecks, 1);
      expect(measureCalls, hasLength(1));
      expect(tester.getSize(find.byType(UiKitView)), const Size(205, 52));
    }, variant: onIOS);

    testWidgets('reuses the size measured for the content of a style', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildButton());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        buildButton(style: const OneTapLocationButtonStyle(iosFontSize: 22)),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(UiKitView)), const Size(265, 67));

      await tester.pumpWidget(
        buildButton(
          style: const OneTapLocationButtonStyle(
            backgroundColor: Color(0xFF1A5CE5),
          ),
        ),
      );
      await tester.pump();

      expect(measureCalls, hasLength(2));
      expect(tester.getSize(find.byType(UiKitView)), const Size(205, 52));
    }, variant: onIOS);

    testWidgets(
      'asserts that the parent allows the size the system requires',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildButton(key: const ValueKey<int>(1)));
        await tester.pumpAndSettle();

        await tester.pumpWidget(
          buildButton(
            key: const ValueKey<int>(2),
            wrap: (Widget button) =>
                Center(child: SizedBox(height: 48, child: button)),
          ),
        );

        expect(tester.takeException(), isAssertionError);
      },
      variant: onIOS,
    );

    testWidgets('renders nothing where the system button ignores taps', (
      WidgetTester tester,
    ) async {
      isSystemButtonAvailable = false;

      await tester.pumpWidget(buildButton());
      await tester.pumpAndSettle();

      expect(measureCalls, isEmpty);
      expect(find.byType(UiKitView), findsNothing);
      expect(tester.getSize(find.byType(OneTapLocationButton)), Size.zero);
    }, variant: onIOS);

    testWidgets('does not build the fallback button', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildButton(
          fallbackBuilder: (BuildContext context, VoidCallback? onPressed) =>
              throw StateError('The fallback button was built on iOS.'),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(UiKitView), findsOneWidget);
    }, variant: onIOS);
  });

  group('on Android', () {
    testWidgets('hosts the system button with hybrid composition', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildButton(
          style: const OneTapLocationButtonStyle(
            androidLabel: AndroidLocationButtonLabel.usePreciseLocation,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final ({String channel, Map<Object?, Object?> arguments}) create =
          createCalls.single;
      expect(create.channel, SystemChannels.platform_views.name);
      expect(create.arguments['hybrid'], isTrue);
      expect(
        const StandardMessageCodec().decodeMessage(
          ByteData.sublistView(create.arguments['params']! as Uint8List),
        ),
        <String, Object?>{'androidLabel': 'usePreciseLocation'},
      );
    }, variant: onAndroid);

    testWidgets('uses hybrid composition++ when the app enables it', (
      WidgetTester tester,
    ) async {
      isSurfaceControlEnabled = true;

      await tester.pumpWidget(buildButton());
      await tester.pumpAndSettle();

      expect(createCalls.single.channel, SystemChannels.platform_views_2.name);
    }, variant: onAndroid);

    testWidgets('recreates the system button for a new pixel ratio', (
      WidgetTester tester,
    ) async {
      final OneTapLocationController controller = OneTapLocationController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(buildButton(controller: controller));
      await _settle(tester);
      await sendFromView(createdViewIds.single, 'onLocating');

      tester.view.devicePixelRatio = 3.5;
      addTearDown(tester.view.resetDevicePixelRatio);
      await _settle(tester);

      expect(createdViewIds, hasLength(2));
      expect(controller.isLocating, isFalse);
      expect(
        <Object?>[
          for (final ({int viewId, MethodCall call}) viewCall in viewCalls)
            if (viewCall.viewId == createdViewIds.last &&
                viewCall.call.method == 'setVisible')
              viewCall.call.arguments,
        ],
        <Object?>[true],
      );
    }, variant: onAndroid);

    testWidgets('checks for the system button once', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildButton(key: const ValueKey<int>(1)));
      await tester.pumpAndSettle();

      await tester.pumpWidget(buildButton(key: const ValueKey<int>(2)));

      expect(availabilityChecks, 1);
      expect(surfaceControlChecks, 1);
      expect(find.byType(PlatformViewLink), findsOneWidget);
    }, variant: onAndroid);

    testWidgets('checks once for buttons built in the same frame', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildButton(
          wrap: (Widget button) => Column(
            children: <Widget>[
              button,
              OneTapLocationButton(onResult: (OneTapLocationResult result) {}),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(availabilityChecks, 1);
      expect(surfaceControlChecks, 1);
      expect(createCalls, hasLength(2));
    }, variant: onAndroid);

    testWidgets('shares the check with the availability query', (
      WidgetTester tester,
    ) async {
      final OneTapLocationAvailability availability =
          await OneTapLocationButton.checkAvailability();
      await tester.pumpWidget(buildButton());
      await tester.pumpAndSettle();

      expect(availability.buttonType, OneTapLocationButtonType.system);
      expect(availabilityChecks, 1);
      expect(createCalls, hasLength(1));
    }, variant: onAndroid);

    testWidgets('fills the width of its parent', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildButton(
          wrap: (Widget button) =>
              Center(child: SizedBox(width: 320, child: button)),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getSize(find.byType(OneTapLocationButton)),
        const Size(320, 48),
      );
    }, variant: onAndroid);

    testWidgets('is a square without a label', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildButton(
          style: const OneTapLocationButtonStyle(
            androidLabel: AndroidLocationButtonLabel.none,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getSize(find.byType(OneTapLocationButton)),
        const Size(48, 48),
      );
    }, variant: onAndroid);

    testWidgets('supports parents that measure intrinsic sizes', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildButton(
          wrap: (Widget button) => Center(
            child: IntrinsicWidth(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const SizedBox(width: 280, height: 10),
                  button,
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(OneTapLocationButton)),
        const Size(280, 48),
      );
    }, variant: onAndroid);

    testWidgets('supports baseline-aligned parents', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildButton(
          wrap: (Widget button) => Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                const Text('Address'),
                SizedBox(width: 200, child: button),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final RenderBox row = tester.renderObject(find.byType(Row));

      expect(
        () => row.getDryLayout(const BoxConstraints(maxWidth: 400)),
        returnsNormally,
      );
      expect(tester.takeException(), isNull);
    }, variant: onAndroid);

    testWidgets('asserts that the width is bounded', (
      WidgetTester tester,
    ) async {
      final List<Object> exceptions = <Object>[];
      final FlutterExceptionHandler? previousHandler = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        exceptions.add(details.exception);
      };

      await tester.pumpWidget(
        buildButton(wrap: (Widget button) => Row(children: <Widget>[button])),
      );
      await tester.pumpAndSettle();
      FlutterError.onError = previousHandler;

      expect(
        exceptions.first,
        isAssertionError.having(
          (AssertionError error) => error.message,
          'message',
          contains('unbounded width'),
        ),
      );
    }, variant: onAndroid);

    testWidgets('shows the system button once it stays fully visible', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildButton());
      await tester.pumpAndSettle();
      await tester.pump(_beforeShowDelay);
      expect(callsTo('setVisible'), isEmpty);

      await tester.pump(_afterShowDelay);
      expect(callsTo('setVisible'), <Object?>[true]);
    }, variant: onAndroid);

    testWidgets('hides the system button while another route covers it', (
      WidgetTester tester,
    ) async {
      final GlobalKey<NavigatorState> navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        buildButton(
          wrap: (Widget button) => Navigator(
            key: navigator,
            onGenerateRoute: (RouteSettings settings) =>
                pageRoute(Center(child: button)),
          ),
        ),
      );
      await _settle(tester);

      unawaited(navigator.currentState!.push(pageRoute(const SizedBox())));
      await tester.pump();
      expect(callsTo('setVisible'), <Object?>[true, false]);

      await tester.pumpAndSettle();
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(callsTo('setVisible'), <Object?>[true, false]);

      await tester.pump(_afterShowDelay);
      expect(callsTo('setVisible'), <Object?>[true, false, true]);
      expect(createCalls, hasLength(1));
    }, variant: onAndroid);

    testWidgets('hides the system button under a dialog', (
      WidgetTester tester,
    ) async {
      final GlobalKey<NavigatorState> navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        buildButton(
          wrap: (Widget button) => MediaQuery.fromView(
            view: tester.view,
            child: Navigator(
              key: navigator,
              onGenerateRoute: (RouteSettings settings) =>
                  pageRoute(Center(child: button)),
            ),
          ),
        ),
      );
      await _settle(tester);

      unawaited(navigator.currentState!.push(dialogRoute()));
      await tester.pumpAndSettle();
      expect(callsTo('setVisible'), <Object?>[true, false]);

      navigator.currentState!.pop();
      await tester.pump();
      await tester.pump(_beforeShowDelay);
      expect(callsTo('setVisible'), <Object?>[true, false]);

      await _settle(tester);
      expect(callsTo('setVisible'), <Object?>[true, false, true]);
    }, variant: onAndroid);

    testWidgets(
      'hides the system button under a dialog of an outer navigator',
      (WidgetTester tester) async {
        final GlobalKey<NavigatorState> outerNavigator =
            GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          buildButton(
            wrap: (Widget button) => MediaQuery.fromView(
              view: tester.view,
              child: Navigator(
                key: outerNavigator,
                onGenerateRoute: (RouteSettings settings) => pageRoute(
                  Navigator(
                    onGenerateRoute: (RouteSettings settings) =>
                        pageRoute(Center(child: button)),
                  ),
                ),
              ),
            ),
          ),
        );
        await _settle(tester);

        unawaited(outerNavigator.currentState!.push(dialogRoute()));
        await tester.pumpAndSettle();
        expect(callsTo('setVisible'), <Object?>[true, false]);

        outerNavigator.currentState!.pop();
        await _settle(tester);
        expect(callsTo('setVisible'), <Object?>[true, false, true]);
      },
      variant: onAndroid,
    );

    testWidgets(
      'hides the system button under content that receives taps',
      (WidgetTester tester) async {
        Widget covered(bool isCovered) {
          return buildButton(
            wrap: (Widget button) => Stack(
              children: <Widget>[
                Center(child: button),
                if (isCovered)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {},
                    ),
                  ),
              ],
            ),
          );
        }

        await tester.pumpWidget(covered(false));
        await _settle(tester);
        await tester.pumpWidget(covered(true));
        await tester.pump();
        expect(callsTo('setVisible'), <Object?>[true, false]);

        await tester.pumpWidget(covered(false));
        await _settle(tester);
        expect(callsTo('setVisible'), <Object?>[true, false, true]);
      },
      variant: onAndroid,
    );

    testWidgets(
      'hides the system button under content that absorbs taps',
      (WidgetTester tester) async {
        Widget covered(bool isCovered) {
          return buildButton(
            wrap: (Widget button) => Stack(
              children: <Widget>[
                Center(child: button),
                if (isCovered)
                  const Positioned.fill(
                    child: AbsorbPointer(
                      child: ColoredBox(color: Color(0x8A000000)),
                    ),
                  ),
              ],
            ),
          );
        }

        await tester.pumpWidget(covered(false));
        await _settle(tester);
        await tester.pumpWidget(covered(true));
        await tester.pump();

        expect(callsTo('setVisible'), <Object?>[true, false]);
      },
      variant: onAndroid,
    );

    testWidgets('hides the system button under content covering an edge', (
      WidgetTester tester,
    ) async {
      Widget covered(bool isCovered) {
        return buildButton(
          wrap: (Widget button) => Stack(
            children: <Widget>[
              Center(child: button),
              if (isCovered)
                Positioned(
                  left: 600,
                  top: 312,
                  width: 48,
                  height: 24,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {},
                  ),
                ),
            ],
          ),
        );
      }

      await tester.pumpWidget(covered(false));
      await _settle(tester);
      await tester.pumpWidget(covered(true));
      await tester.pump();

      expect(callsTo('setVisible'), <Object?>[true, false]);
    }, variant: onAndroid);

    testWidgets(
      'shows the system button at the edges of a closed drawer',
      (WidgetTester tester) async {
        final GlobalKey<ScaffoldState> scaffold = GlobalKey<ScaffoldState>();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              key: scaffold,
              drawer: const Drawer(),
              endDrawer: const Drawer(),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  OneTapLocationButton(
                    onResult: (OneTapLocationResult result) {},
                  ),
                ],
              ),
            ),
          ),
        );
        await _settle(tester);
        expect(callsTo('setVisible'), <Object?>[true]);

        scaffold.currentState!.openDrawer();
        await tester.pumpAndSettle();
        expect(callsTo('setVisible'), <Object?>[true, false]);
      },
      variant: onAndroid,
    );

    testWidgets(
      'shows the system button at the back swipe edge of a page',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            onGenerateRoute: (RouteSettings settings) =>
                CupertinoPageRoute<void>(
                  builder: (BuildContext context) => ListView(
                    padding: const EdgeInsets.all(16),
                    children: <Widget>[
                      OneTapLocationButton(
                        onResult: (OneTapLocationResult result) {},
                      ),
                    ],
                  ),
                ),
          ),
        );
        await _settle(tester);

        expect(callsTo('setVisible'), <Object?>[true]);
      },
      variant: onAndroid,
    );

    testWidgets('shows the system button inside a rounded clip', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildButton(
          wrap: (Widget button) => Center(
            child: SizedBox(
              width: 320,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: button,
              ),
            ),
          ),
        ),
      );
      await _settle(tester);

      expect(callsTo('setVisible'), <Object?>[true]);
    }, variant: onAndroid);

    testWidgets(
      'keeps the system button shown while its list is dragged',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          buildButton(
            wrap: (Widget button) => ListView(
              children: <Widget>[
                const SizedBox(height: 200),
                button,
                const SizedBox(height: 2000),
              ],
            ),
          ),
        );
        await _settle(tester);

        final TestGesture gesture = await tester.startGesture(
          const Offset(400, 500),
        );
        for (int step = 0; step < 6; step += 1) {
          await gesture.moveBy(const Offset(0, -4));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await tester.pump(_afterShowDelay);
        await gesture.up();
        await tester.pump(_afterShowDelay);

        expect(callsTo('setVisible'), <Object?>[true]);
      },
      variant: onAndroid,
      semanticsEnabled: false,
    );

    // The button lies 200 logical pixels below the top of the list, and the box
    // covers the top 100 logical pixels of the screen.
    Widget listUnderBox(Widget button, ScrollController controller) {
      return Stack(
        children: <Widget>[
          ListView(
            controller: controller,
            children: <Widget>[
              const SizedBox(height: 200),
              button,
              const SizedBox(height: 2000),
            ],
          ),
          Positioned(
            left: 0,
            top: 0,
            right: 0,
            height: 100,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
            ),
          ),
        ],
      );
    }

    Future<void> drag(WidgetTester tester, double distance) async {
      final TestGesture gesture = await tester.startGesture(
        const Offset(400, 500),
      );
      for (int step = 0; step < 10; step += 1) {
        await gesture.moveBy(Offset(0, distance / 10));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pump(_afterShowDelay);
      await gesture.up();
    }

    testWidgets(
      'checks again whether content covers the system button once a drag ends',
      (WidgetTester tester) async {
        final ScrollController controller = ScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          buildButton(
            wrap: (Widget button) => listUnderBox(button, controller),
          ),
        );
        await _settle(tester);

        await drag(tester, -150);
        expect(callsTo('setVisible'), <Object?>[true]);
        expect(tester.binding.hasScheduledFrame, isTrue);

        await tester.pump();
        expect(callsTo('setVisible'), <Object?>[true, false]);
      },
      variant: onAndroid,
      semanticsEnabled: false,
    );

    testWidgets(
      'keeps a covered system button hidden while its list is dragged',
      (WidgetTester tester) async {
        final ScrollController controller = ScrollController(
          initialScrollOffset: 150,
        );
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          buildButton(
            wrap: (Widget button) => listUnderBox(button, controller),
          ),
        );
        await _settle(tester);

        await drag(tester, 150);
        expect(callsTo('setVisible'), isEmpty);

        await _settle(tester);
        expect(callsTo('setVisible'), <Object?>[true]);
      },
      variant: onAndroid,
      semanticsEnabled: false,
    );

    testWidgets(
      'keeps a system button hidden that is dragged into view under content',
      (WidgetTester tester) async {
        final ScrollController controller = ScrollController(
          initialScrollOffset: 350,
        );
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          buildButton(
            wrap: (Widget button) => listUnderBox(button, controller),
          ),
        );
        await _settle(tester);

        await drag(tester, 200);
        expect(callsTo('setVisible'), isEmpty);

        await _settle(tester);
        expect(callsTo('setVisible'), isEmpty);
      },
      variant: onAndroid,
      semanticsEnabled: false,
    );

    testWidgets(
      'keeps a system button hidden that appears under content during a drag',
      (WidgetTester tester) async {
        final ScrollController controller = ScrollController(
          initialScrollOffset: 150,
        );
        addTearDown(controller.dispose);
        final ValueNotifier<bool> hasButton = ValueNotifier<bool>(false);
        addTearDown(hasButton.dispose);
        await tester.pumpWidget(
          buildButton(
            wrap: (Widget button) => listUnderBox(
              ValueListenableBuilder<bool>(
                valueListenable: hasButton,
                builder: (BuildContext context, bool value, Widget? child) =>
                    value ? button : const SizedBox(height: 48),
              ),
              controller,
            ),
          ),
        );
        await _settle(tester);

        final TestGesture gesture = await tester.startGesture(
          const Offset(400, 500),
        );
        for (int step = 0; step < 4; step += 1) {
          await gesture.moveBy(const Offset(0, 5));
          await tester.pump(const Duration(milliseconds: 16));
        }
        hasButton.value = true;
        await tester.pumpAndSettle();
        await tester.pump(_afterShowDelay);
        expect(callsTo('setVisible'), isEmpty);

        await gesture.up();
      },
      variant: onAndroid,
      semanticsEnabled: false,
    );

    testWidgets(
      'keeps a system button hidden that is dragged back into view under content',
      (WidgetTester tester) async {
        final ScrollController controller = ScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          buildButton(
            wrap: (Widget button) => listUnderBox(button, controller),
          ),
        );
        await _settle(tester);
        controller.jumpTo(350);
        await tester.pump();
        expect(callsTo('setVisible'), <Object?>[true, false]);

        await drag(tester, 200);
        await _settle(tester);

        expect(callsTo('setVisible'), <Object?>[true, false]);
      },
      variant: onAndroid,
      semanticsEnabled: false,
    );

    testWidgets('shows a system button that was created after the delay', (
      WidgetTester tester,
    ) async {
      deferCreation = true;
      await tester.pumpWidget(buildButton());
      await tester.pumpAndSettle();
      await tester.pump(_afterShowDelay);
      expect(callsTo('setVisible'), isEmpty);

      pendingCreations.single.complete();
      await _settle(tester);

      expect(callsTo('setVisible'), <Object?>[true]);
    }, variant: onAndroid);

    testWidgets('hides the system button while an ancestor clips it', (
      WidgetTester tester,
    ) async {
      Widget clipped(double heightFactor) {
        return buildButton(
          wrap: (Widget button) => Center(
            child: ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: heightFactor,
                child: button,
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(clipped(0.5));
      await _settle(tester);
      expect(callsTo('setVisible'), isEmpty);

      await tester.pumpWidget(clipped(1));
      await _settle(tester);
      expect(callsTo('setVisible'), <Object?>[true]);
    }, variant: onAndroid);

    testWidgets('hides the system button while an ancestor fades it', (
      WidgetTester tester,
    ) async {
      Widget faded(double opacity) {
        return buildButton(
          wrap: (Widget button) => Center(
            child: Opacity(opacity: opacity, child: button),
          ),
        );
      }

      await tester.pumpWidget(faded(0.5));
      await _settle(tester);
      expect(callsTo('setVisible'), isEmpty);

      await tester.pumpWidget(faded(1));
      await _settle(tester);
      expect(callsTo('setVisible'), <Object?>[true]);
    }, variant: onAndroid);

    testWidgets(
      'hides the system button while an ancestor scales or rotates it',
      (WidgetTester tester) async {
        Widget transformed(Matrix4 transform) {
          return buildButton(
            wrap: (Widget button) => Center(
              child: SizedBox(
                width: 320,
                child: Transform(
                  transform: transform,
                  alignment: Alignment.center,
                  child: button,
                ),
              ),
            ),
          );
        }

        await tester.pumpWidget(
          transformed(Matrix4.diagonal3Values(0.98, 0.98, 1)),
        );
        await _settle(tester);
        expect(callsTo('setVisible'), isEmpty);

        await tester.pumpWidget(transformed(Matrix4.rotationZ(0.1)));
        await _settle(tester);
        expect(callsTo('setVisible'), isEmpty);

        await tester.pumpWidget(transformed(Matrix4.identity()));
        await _settle(tester);
        expect(callsTo('setVisible'), <Object?>[true]);
      },
      variant: onAndroid,
    );

    testWidgets(
      'hides the system button while an ancestor applies an image filter',
      (WidgetTester tester) async {
        Widget filtered(Widget Function(Widget button) filter) {
          return buildButton(
            wrap: (Widget button) =>
                Center(child: SizedBox(width: 320, child: filter(button))),
          );
        }

        await tester.pumpWidget(
          filtered(
            (Widget button) => Transform.scale(
              scale: 0.5,
              filterQuality: FilterQuality.medium,
              child: button,
            ),
          ),
        );
        await _settle(tester);
        expect(callsTo('setVisible'), isEmpty);

        await tester.pumpWidget(
          filtered(
            (Widget button) => ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
              child: button,
            ),
          ),
        );
        await _settle(tester);
        expect(callsTo('setVisible'), isEmpty);

        await tester.pumpWidget(filtered((Widget button) => button));
        await _settle(tester);
        expect(callsTo('setVisible'), <Object?>[true]);
      },
      variant: onAndroid,
    );

    testWidgets('hides the system button while it is not painted', (
      WidgetTester tester,
    ) async {
      Widget offstage(bool isOffstage) {
        return buildButton(
          wrap: (Widget button) => Center(
            child: Offstage(offstage: isOffstage, child: button),
          ),
        );
      }

      await tester.pumpWidget(offstage(false));
      await _settle(tester);
      await tester.pumpWidget(offstage(true));
      await tester.pump();
      expect(callsTo('setVisible'), <Object?>[true, false]);

      await tester.pumpWidget(offstage(false));
      await _settle(tester);
      expect(callsTo('setVisible'), <Object?>[true, false, true]);
    }, variant: onAndroid);

    testWidgets(
      'hides the system button while it is scrolled out of view',
      (WidgetTester tester) async {
        final ScrollController scrollController = ScrollController();
        addTearDown(scrollController.dispose);
        await tester.pumpWidget(
          buildButton(
            wrap: (Widget button) => ListView(
              controller: scrollController,
              children: <Widget>[
                const SizedBox(height: 100),
                button,
                const SizedBox(height: 2000),
              ],
            ),
          ),
        );
        await _settle(tester);

        scrollController.jumpTo(120);
        await tester.pump();
        expect(callsTo('setVisible'), <Object?>[true, false]);

        scrollController.jumpTo(0);
        await _settle(tester);
        expect(callsTo('setVisible'), <Object?>[true, false, true]);
      },
      variant: onAndroid,
    );

    testWidgets('hides the system button under the system bars', (
      WidgetTester tester,
    ) async {
      addTearDown(tester.view.resetViewPadding);
      tester.view.viewPadding = const FakeViewPadding(top: 200);
      await tester.pumpWidget(
        buildButton(
          wrap: (Widget button) =>
              Align(alignment: Alignment.topCenter, child: button),
        ),
      );
      await _settle(tester);
      expect(callsTo('setVisible'), isEmpty);

      tester.view.resetViewPadding();
      await _settle(tester);
      expect(callsTo('setVisible'), <Object?>[true]);
    }, variant: onAndroid);

    testWidgets('hides the system button under the keyboard', (
      WidgetTester tester,
    ) async {
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        buildButton(
          wrap: (Widget button) =>
              Align(alignment: Alignment.bottomCenter, child: button),
        ),
      );
      await _settle(tester);

      tester.view.viewInsets = const FakeViewPadding(bottom: 600);
      await tester.pumpAndSettle();

      expect(callsTo('setVisible'), <Object?>[true, false]);
    }, variant: onAndroid);

    testWidgets('keeps a hidden button hidden while it is removed', (
      WidgetTester tester,
    ) async {
      final GlobalKey<NavigatorState> navigator = GlobalKey<NavigatorState>();
      final ValueNotifier<bool> hasButton = ValueNotifier<bool>(true);
      addTearDown(hasButton.dispose);
      await tester.pumpWidget(
        buildButton(
          wrap: (Widget button) => MediaQuery.fromView(
            view: tester.view,
            child: Navigator(
              key: navigator,
              onGenerateRoute: (RouteSettings settings) => pageRoute(
                ValueListenableBuilder<bool>(
                  valueListenable: hasButton,
                  builder: (BuildContext context, bool value, Widget? child) =>
                      Center(child: value ? button : null),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      unawaited(navigator.currentState!.push(dialogRoute()));
      await tester.pumpAndSettle();

      hasButton.value = false;
      await _settle(tester);

      expect(callsTo('setVisible'), <Object?>[true, false]);
    }, variant: onAndroid);

    testWidgets('sends a new style to the existing system button', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildButton());
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        buildButton(
          style: const OneTapLocationButtonStyle(
            androidLabel: AndroidLocationButtonLabel.sharePreciseLocation,
          ),
        ),
      );
      await tester.pump();

      expect(createCalls, hasLength(1));
      expect(callsTo('setStyle'), <Object?>[
        <String, Object?>{'androidLabel': 'sharePreciseLocation'},
      ]);
    }, variant: onAndroid);

    testWidgets('sends no style when only iOS properties change', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildButton());
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        buildButton(style: const OneTapLocationButtonStyle(iosFontSize: 22)),
      );
      await tester.pump();

      expect(callsTo('setStyle'), isEmpty);
    }, variant: onAndroid);

    testWidgets('sends a style that changed while the view was created', (
      WidgetTester tester,
    ) async {
      deferCreation = true;
      await tester.pumpWidget(buildButton());
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        buildButton(
          style: const OneTapLocationButtonStyle(
            androidLabel: AndroidLocationButtonLabel.sharePreciseLocation,
          ),
        ),
      );
      pendingCreations.single.complete();
      await tester.pumpAndSettle();

      expect(createCalls, hasLength(1));
      expect(callsTo('setStyle'), <Object?>[
        <String, Object?>{'androidLabel': 'sharePreciseLocation'},
      ]);
    }, variant: onAndroid);

    testWidgets('reports a system button that cannot be shown', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildButton());
      await tester.pumpAndSettle();

      await sendFromView(
        createdViewIds.single,
        'onUnavailable',
        <String, Object?>{
          'message': 'The app must declare ACCESS_FINE_LOCATION.',
        },
      );
      await tester.pump();

      expect(
        tester.takeException(),
        isA<FlutterError>().having(
          (FlutterError error) => error.message,
          'message',
          contains('The app must declare ACCESS_FINE_LOCATION.'),
        ),
      );
      expect(find.byType(PlatformViewLink), findsNothing);
      expect(
        tester.getSize(find.byType(OneTapLocationButton)),
        const Size(800, 48),
      );
    }, variant: onAndroid);

    testWidgets(
      'ends the progress of a system button that cannot be shown',
      (WidgetTester tester) async {
        final OneTapLocationController controller = OneTapLocationController();
        addTearDown(controller.dispose);
        final List<OneTapLocationResult> results = <OneTapLocationResult>[];
        await tester.pumpWidget(
          buildButton(onResult: results.add, controller: controller),
        );
        await tester.pumpAndSettle();
        final int viewId = createdViewIds.single;
        await sendFromView(viewId, 'onLocating');

        await sendFromView(viewId, 'onUnavailable', <String, Object?>{
          'message': 'The location button render service stopped.',
        });
        await tester.pump();

        expect(tester.takeException(), isFlutterError);
        expect(controller.isLocating, isFalse);
        expect(results, isEmpty);
        expect(find.byType(PlatformViewLink), findsNothing);
      },
      variant: onAndroid,
    );
  });

  group('on Android without the system button', () {
    setUp(() {
      isSystemButtonAvailable = false;
    });

    Finder fallbackShape() => find.descendant(
      of: find.byType(FilledButton),
      matching: find.byType(Material),
    );

    // The shape that the button draws, in the coordinates of the button.
    Rect visibleShape(WidgetTester tester) {
      final Material material = tester.widget(fallbackShape());
      return material.shape!
          .getOuterPath(Offset.zero & tester.getSize(fallbackShape()))
          .getBounds();
    }

    // The button paints other parts with custom painters too, so the icon is
    // looked up next to the label.
    Finder fallbackIcon() => find.descendant(
      of: find.descendant(
        of: find.byType(FilledButton),
        matching: find.byType(Row),
      ),
      matching: find.byType(CustomPaint),
    );

    VoidCallback? fallbackOnPressed(WidgetTester tester) {
      return tester.widget<FilledButton>(find.byType(FilledButton)).onPressed;
    }

    Future<void> tapFallbackButton(WidgetTester tester) async {
      await tester.tap(find.byType(OneTapLocationButton));
      await tester.pump();
    }

    testWidgets(
      'shows a fallback button that resembles the system button',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildButton());
        await tester.pumpAndSettle();

        final Material shape = tester.widget(fallbackShape());
        final ColorScheme colors = ThemeData.fallback().colorScheme;
        expect(createCalls, isEmpty);
        expect(
          tester.getSize(find.byType(OneTapLocationButton)),
          const Size(800, 48),
        );
        expect(visibleShape(tester), const Rect.fromLTWH(4, 4, 792, 40));
        expect(find.text('Precise location'), findsOneWidget);
        expect(shape.color, colors.secondaryContainer);
        expect(shape.textStyle?.color, colors.onSecondaryContainer);
        expect(shape.shape, InsetBorder(const StadiumBorder(), 4));
        expect(
          tester.getSemantics(find.byType(FilledButton)),
          isSemantics(
            label: 'Precise location',
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
          ),
        );
      },
      variant: onAndroid,
    );

    testWidgets('shows the English text of the Android label', (
      WidgetTester tester,
    ) async {
      const Map<AndroidLocationButtonLabel, String> texts =
          <AndroidLocationButtonLabel, String>{
            AndroidLocationButtonLabel.preciseLocation: 'Precise location',
            AndroidLocationButtonLabel.usePreciseLocation:
                'Use precise location',
            AndroidLocationButtonLabel.sharePreciseLocation:
                'Share precise location',
            AndroidLocationButtonLabel.nearMyPreciseLocation:
                'Near my precise location',
            AndroidLocationButtonLabel.nearYourPreciseLocation:
                'Near your precise location',
          };

      for (final MapEntry<AndroidLocationButtonLabel, String> text
          in texts.entries) {
        await tester.pumpWidget(
          buildButton(style: OneTapLocationButtonStyle(androidLabel: text.key)),
        );
        await tester.pumpAndSettle();

        expect(find.text(text.value), findsOneWidget);
      }
    }, variant: onAndroid);

    testWidgets('shows the text that the app provides', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildButton(
          style: const OneTapLocationButtonStyle(
            androidLabel: AndroidLocationButtonLabel.sharePreciseLocation,
            androidFallbackLabel: 'Use my location',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Use my location'), findsOneWidget);
      expect(find.text('Share precise location'), findsNothing);
    }, variant: onAndroid);

    testWidgets('shows only the icon without a label', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildButton(
          style: const OneTapLocationButtonStyle(
            androidLabel: AndroidLocationButtonLabel.none,
            androidFallbackLabel: 'My location',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getSize(find.byType(OneTapLocationButton)),
        const Size(48, 48),
      );
      expect(visibleShape(tester), const Rect.fromLTWH(4, 4, 40, 40));
      expect(
        tester.widget<Material>(fallbackShape()).shape,
        InsetBorder(const StadiumBorder(), 4),
      );
      expect(find.byType(Text), findsNothing);
      expect(
        tester.getSemantics(find.byType(FilledButton)),
        isSemantics(label: 'My location', isButton: true, hasTapAction: true),
      );
    }, variant: onAndroid);

    testWidgets('sizes its content by its height like the system button', (
      WidgetTester tester,
    ) async {
      for (final (double height, double iconSize, double gap, double fontSize)
          in <(double, double, double, double)>[
            (63, 20, 4, 14),
            (64, 24, 8, 16),
            (104, 32, 12, 24),
            (136, 32, 12, 24),
          ]) {
        await tester.pumpWidget(
          buildButton(
            wrap: (Widget button) => Center(
              child: SizedBox(width: 320, height: height, child: button),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final Rect icon = tester.getRect(fallbackIcon());
        final Rect text = tester.getRect(find.text('Precise location'));
        expect(
          visibleShape(tester),
          Rect.fromLTWH(4, 4, 312, height - 8),
          reason: 'height $height',
        );
        expect(icon.size, Size.square(iconSize), reason: 'height $height');
        expect(text.left - icon.right, gap, reason: 'height $height');
        expect(
          tester.widget<Material>(fallbackShape()).textStyle?.fontSize,
          fontSize,
          reason: 'height $height',
        );
      }
    }, variant: onAndroid);

    testWidgets('sizes its icon by its shorter side without a label', (
      WidgetTester tester,
    ) async {
      for (final (Size size, double iconSize) in <(Size, double)>[
        (const Size(96, 96), 24),
        (const Size(48, 136), 20),
        (const Size(160, 48), 20),
      ]) {
        await tester.pumpWidget(
          buildButton(
            style: const OneTapLocationButtonStyle(
              androidLabel: AndroidLocationButtonLabel.none,
            ),
            wrap: (Widget button) => Center(
              child: SizedBox.fromSize(size: size, child: button),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final Finder icon = find.descendant(
          of: find.byType(FilledButton),
          matching: find.byWidgetPredicate(
            (Widget widget) =>
                widget is Semantics &&
                widget.properties.label == 'Precise location',
          ),
        );
        expect(
          visibleShape(tester),
          Rect.fromLTWH(4, 4, size.width - 8, size.height - 8),
          reason: 'size $size',
        );
        expect(
          tester.getSize(icon),
          Size.square(iconSize),
          reason: 'size $size',
        );
      }
    }, variant: onAndroid);

    testWidgets('takes the pressed shape of the system button', (
      WidgetTester tester,
    ) async {
      for (final (double height, double? cornerRadius, double pressedRadius)
          in <(double, double?, double)>[
            (56, null, 8),
            (57, null, 12),
            (84, 20, 12),
            (85, null, 16),
          ]) {
        await tester.pumpWidget(
          buildButton(
            style: OneTapLocationButtonStyle(cornerRadius: cornerRadius),
            wrap: (Widget button) => Center(
              child: SizedBox(width: 320, height: height, child: button),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final TestGesture gesture = await tester.startGesture(
          tester.getCenter(find.byType(OneTapLocationButton)),
        );
        await tester.pump();

        expect(
          tester.widget<Material>(fallbackShape()).shape,
          InsetBorder(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(pressedRadius)),
            ),
            4,
          ),
          reason: 'height $height',
        );
        await gesture.cancel();
        await tester.pumpAndSettle();
      }
    }, variant: onAndroid);

    testWidgets('receives taps in its whole area', (WidgetTester tester) async {
      Future<void> tapNearEdge(OneTapLocationButtonStyle style) async {
        await tester.pumpWidget(buildButton(style: style));
        await tester.pumpAndSettle();
        final Rect area = tester.getRect(find.byType(OneTapLocationButton));

        await tester.tapAt(area.centerLeft + const Offset(2, 0));
        await tester.pumpAndSettle();
        pendingPermissionRequests.last.complete('denied');
        await tester.pumpAndSettle();
      }

      await tapNearEdge(const OneTapLocationButtonStyle());
      await tapNearEdge(
        const OneTapLocationButtonStyle(
          androidLabel: AndroidLocationButtonLabel.none,
        ),
      );

      expect(pendingPermissionRequests, hasLength(2));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    }, variant: onAndroid);

    testWidgets('keeps its content inside narrow widths', (
      WidgetTester tester,
    ) async {
      for (final double width in <double>[48, 56, 63]) {
        await tester.pumpWidget(
          buildButton(
            wrap: (Widget button) => Center(
              child: SizedBox(width: width, child: button),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: 'width $width');
        final Rect icon = tester.getRect(fallbackIcon());
        expect(
          tester
              .getRect(find.byType(OneTapLocationButton))
              .contains(icon.center),
          isTrue,
          reason: 'width $width',
        );
        expect(icon.width, 20, reason: 'width $width');
      }
    }, variant: onAndroid);

    testWidgets('applies the style to the fallback button', (
      WidgetTester tester,
    ) async {
      const BorderSide side = BorderSide(color: Color(0xFF90CAF9), width: 3);
      await tester.pumpWidget(
        buildButton(
          style: const OneTapLocationButtonStyle(
            backgroundColor: Color(0xFF1B3A6B),
            foregroundColor: Color(0xFFFFFFFF),
            cornerRadius: 8,
            androidStrokeColor: Color(0xFF90CAF9),
            androidStrokeWidth: 5,
            androidPressedCornerRadius: 2,
          ),
        ),
      );
      await tester.pumpAndSettle();
      Material shape() => tester.widget(fallbackShape());

      expect(shape().color, const Color(0xFF1B3A6B));
      expect(shape().textStyle?.color, const Color(0xFFFFFFFF));
      expect(
        shape().shape,
        InsetBorder(
          const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            side: side,
          ),
          4,
        ),
      );

      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byType(OneTapLocationButton)),
      );
      await tester.pump();

      expect(
        shape().shape,
        InsetBorder(
          const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(2)),
            side: side,
          ),
          4,
        ),
      );
      await gesture.cancel();
    }, variant: onAndroid);

    testWidgets('draws no outline without a stroke color', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildButton(
          style: const OneTapLocationButtonStyle(androidStrokeWidth: 2),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<Material>(fallbackShape()).shape,
        InsetBorder(const StadiumBorder(), 4),
      );
    }, variant: onAndroid);

    testWidgets('ignores the button styling of the app theme', (
      WidgetTester tester,
    ) async {
      final ThemeData plain = ThemeData();
      final ThemeData themed = ThemeData(
        textTheme: const TextTheme(
          labelLarge: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            iconColor: const Color(0xFFD50000),
            side: const BorderSide(color: Color(0xFFD50000), width: 2),
            textStyle: const TextStyle(fontSize: 30),
            elevation: 6,
          ),
        ),
      );
      Future<
        ({
          ShapeBorder? shape,
          TextStyle? textStyle,
          double? elevation,
          Color? iconColor,
        })
      >
      look(ThemeData theme) async {
        await tester.pumpWidget(
          buildButton(
            wrap: (Widget button) => Theme(
              data: theme,
              child: Center(child: button),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final Material material = tester.widget(fallbackShape());
        final IconThemeData icon = IconTheme.of(tester.element(fallbackIcon()));
        return (
          shape: material.shape,
          textStyle: material.textStyle,
          elevation: material.elevation,
          iconColor: icon.color,
        );
      }

      expect(await look(themed), await look(plain));
    }, variant: onAndroid);

    testWidgets('uses the colors of the theme', (WidgetTester tester) async {
      final ThemeData theme = ThemeData(
        colorSchemeSeed: const Color(0xFF00897B),
      );
      await tester.pumpWidget(
        buildButton(
          wrap: (Widget button) => Theme(
            data: theme,
            child: Center(child: button),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Material shape = tester.widget(fallbackShape());
      expect(shape.color, theme.colorScheme.secondaryContainer);
      expect(shape.textStyle?.color, theme.colorScheme.onSecondaryContainer);
    }, variant: onAndroid);

    testWidgets(
      'gives a custom fallback button the size of the system button',
      (WidgetTester tester) async {
        final List<VoidCallback?> callbacks = <VoidCallback?>[];
        await tester.pumpWidget(
          buildButton(
            wrap: (Widget button) =>
                Center(child: SizedBox(width: 320, child: button)),
            fallbackBuilder: (BuildContext context, VoidCallback? onPressed) {
              callbacks.add(onPressed);
              return GestureDetector(
                onTap: onPressed,
                child: const ColoredBox(color: Color(0xFF1B3A6B)),
              );
            },
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(FilledButton), findsNothing);
        expect(tester.getSize(find.byType(ColoredBox)), const Size(320, 48));
        expect(callbacks.last, isNotNull);

        await tester.tap(find.byType(ColoredBox));
        await tester.pump();
        expect(pendingPermissionRequests, hasLength(1));
        expect(callbacks.last, isNull);

        pendingPermissionRequests.single.complete('denied');
        await tester.pumpAndSettle();
        expect(callbacks.last, isNotNull);
      },
      variant: onAndroid,
    );

    testWidgets('reports the position once access is granted', (
      WidgetTester tester,
    ) async {
      final OneTapLocationController controller = OneTapLocationController();
      addTearDown(controller.dispose);
      final List<OneTapLocationResult> results = <OneTapLocationResult>[];
      await tester.pumpWidget(
        buildButton(onResult: results.add, controller: controller),
      );
      await tester.pumpAndSettle();
      final Color? color = tester.widget<Material>(fallbackShape()).color;

      await tapFallbackButton(tester);
      expect(pendingPermissionRequests, hasLength(1));
      expect(controller.isLocating, isFalse);
      expect(fallbackOnPressed(tester), isNull);
      expect(tester.widget<Material>(fallbackShape()).color, color);

      pendingPermissionRequests.single.complete('granted');
      await tester.pumpAndSettle();
      expect(controller.isLocating, isTrue);
      expect(positionRequestIds, hasLength(1));

      pendingPositionRequests.single.complete(_grantedResult);
      await tester.pumpAndSettle();
      expect(controller.isLocating, isFalse);
      expect(results, <OneTapLocationResult>[_grantedLocation]);
      expect(fallbackOnPressed(tester), isNotNull);
    }, variant: onAndroid);

    testWidgets('makes one request for taps before the next frame', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildButton());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(OneTapLocationButton));
      await tester.tap(find.byType(OneTapLocationButton));
      await tester.pumpAndSettle();

      expect(pendingPermissionRequests, hasLength(1));
    }, variant: onAndroid);

    testWidgets(
      'keeps the keyboard focus while a request is in progress',
      (WidgetTester tester) async {
        final FocusNode textField = FocusNode();
        addTearDown(textField.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: Column(
                children: <Widget>[
                  TextField(focusNode: textField),
                  OneTapLocationButton(
                    style: const OneTapLocationButtonStyle(
                      cornerRadius: 12,
                      androidPressedCornerRadius: 4,
                    ),
                    onResult: (OneTapLocationResult result) {},
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        textField.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final FocusNode? button = FocusManager.instance.primaryFocus;
        expect(button, isNot(textField));

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(pendingPermissionRequests, hasLength(1));
        expect(FocusManager.instance.primaryFocus, same(button));
        final ButtonStyle style = tester
            .widget<FilledButton>(find.byType(FilledButton))
            .style!;
        const Set<WidgetState> busy = <WidgetState>{WidgetState.disabled};
        final Set<WidgetState> busyAndPressed = <WidgetState>{
          ...busy,
          WidgetState.pressed,
        };
        expect(style.splashFactory, same(NoSplash.splashFactory));
        expect(
          style.overlayColor!.resolve(busyAndPressed),
          const Color(0x00000000),
        );
        expect(
          style.overlayColor!.resolve(<WidgetState>{
            ...busy,
            WidgetState.focused,
          }),
          isNot(const Color(0x00000000)),
        );
        expect(
          style.shape!.resolve(busyAndPressed),
          style.shape!.resolve(busy),
        );

        pendingPermissionRequests.single.complete('denied');
        await tester.pumpAndSettle();
        expect(FocusManager.instance.primaryFocus, same(button));
      },
      variant: onAndroid,
    );

    testWidgets('reports a denied request', (WidgetTester tester) async {
      final List<OneTapLocationResult> results = <OneTapLocationResult>[];
      await tester.pumpWidget(buildButton(onResult: results.add));
      await tester.pumpAndSettle();

      await tapFallbackButton(tester);
      pendingPermissionRequests.single.complete('denied');
      await tester.pumpAndSettle();

      expect(results, <OneTapLocationResult>[const OneTapLocationDenied()]);
      expect(positionRequestIds, isEmpty);
    }, variant: onAndroid);

    testWidgets('reports an unanswered request through a diagnostic', (
      WidgetTester tester,
    ) async {
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
      await tester.pumpAndSettle();

      await tapFallbackButton(tester);
      pendingPermissionRequests.single.complete('cancelled');
      await tester.pumpAndSettle();

      expect(diagnostics, <OneTapLocationDiagnostic>[
        OneTapLocationDiagnostic.tapWithoutAuthorization,
      ]);
      expect(results, isEmpty);
      expect(fallbackOnPressed(tester), isNotNull);
    }, variant: onAndroid);

    testWidgets('reports that location services are turned off', (
      WidgetTester tester,
    ) async {
      final List<OneTapLocationResult> results = <OneTapLocationResult>[];
      await tester.pumpWidget(buildButton(onResult: results.add));
      await tester.pumpAndSettle();

      await tapFallbackButton(tester);
      pendingPermissionRequests.single.complete('granted');
      await tester.pumpAndSettle();
      pendingPositionRequests.single.complete(<String, Object?>{
        'status': 'failed',
        'code': 'locationServicesDisabled',
      });
      await tester.pumpAndSettle();

      expect(results, <OneTapLocationResult>[
        const OneTapLocationFailed(
          OneTapLocationException(
            OneTapLocationErrorCode.locationServicesDisabled,
          ),
        ),
      ]);
    }, variant: onAndroid);

    testWidgets('cancels the position request of a removed button', (
      WidgetTester tester,
    ) async {
      final OneTapLocationController controller = OneTapLocationController();
      addTearDown(controller.dispose);
      final List<OneTapLocationResult> results = <OneTapLocationResult>[];
      await tester.pumpWidget(
        buildButton(onResult: results.add, controller: controller),
      );
      await tester.pumpAndSettle();
      await tapFallbackButton(tester);
      pendingPermissionRequests.single.complete('granted');
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox.shrink());
      expect(cancelledPositionRequestIds, positionRequestIds);

      pendingPositionRequests.single.complete();
      await tester.pumpAndSettle();
      expect(results, isEmpty);
      expect(controller.isLocating, isFalse);
    }, variant: onAndroid);

    testWidgets(
      'requests no position for a button removed during the dialog',
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
        await tester.pumpAndSettle();
        await tapFallbackButton(tester);

        await tester.pumpWidget(const SizedBox.shrink());
        pendingPermissionRequests.single.complete('granted');
        await tester.pumpAndSettle();

        expect(positionRequestIds, isEmpty);
        expect(results, isEmpty);
        expect(diagnostics, isEmpty);
        expect(controller.isLocating, isFalse);
      },
      variant: onAndroid,
    );

    testWidgets('recovers from a position request that fails', (
      WidgetTester tester,
    ) async {
      final OneTapLocationController controller = OneTapLocationController();
      addTearDown(controller.dispose);
      final List<OneTapLocationResult> results = <OneTapLocationResult>[];
      await tester.pumpWidget(
        buildButton(onResult: results.add, controller: controller),
      );
      await tester.pumpAndSettle();
      await tapFallbackButton(tester);
      pendingPermissionRequests.single.complete('granted');
      await tester.pumpAndSettle();

      pendingPositionRequests.single.completeError(
        PlatformException(code: 'error'),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isA<PlatformException>());
      expect(results, isEmpty);
      expect(controller.isLocating, isFalse);
      expect(fallbackOnPressed(tester), isNotNull);
    }, variant: onAndroid);

    testWidgets(
      'reports errors thrown by the app while handling a result',
      (WidgetTester tester) async {
        final OneTapLocationController controller = OneTapLocationController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          buildButton(
            controller: controller,
            onResult: (OneTapLocationResult result) =>
                throw StateError('Failure in the app.'),
          ),
        );
        await tester.pumpAndSettle();
        await tapFallbackButton(tester);
        pendingPermissionRequests.single.complete('granted');
        await tester.pumpAndSettle();

        pendingPositionRequests.single.complete(_grantedResult);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isStateError);
        expect(controller.isLocating, isFalse);
        expect(fallbackOnPressed(tester), isNotNull);
      },
      variant: onAndroid,
    );

    testWidgets('reports an error when access cannot be requested', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildButton());
      await tester.pumpAndSettle();

      await tapFallbackButton(tester);
      pendingPermissionRequests.single.completeError(
        PlatformException(
          code: 'missingPermission',
          message:
              'The app must declare android.permission.ACCESS_COARSE_LOCATION '
              'in its AndroidManifest.xml.',
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.takeException(),
        isA<PlatformException>().having(
          (PlatformException exception) => exception.code,
          'code',
          'missingPermission',
        ),
      );
      expect(fallbackOnPressed(tester), isNotNull);
    }, variant: onAndroid);

    testWidgets('keeps its position in a baseline-aligned parent', (
      WidgetTester tester,
    ) async {
      deferAvailabilityChecks = true;
      await tester.pumpWidget(
        buildButton(
          wrap: (Widget button) => Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                const Text('Address'),
                SizedBox(width: 200, child: button),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      final Offset buttonOrigin = tester.getTopLeft(
        find.byType(OneTapLocationButton),
      );
      final Offset textOrigin = tester.getTopLeft(find.text('Address'));

      pendingAvailabilityChecks.single.complete(availabilityFor(false));
      await tester.pumpAndSettle();
      final RenderBox row = tester.renderObject(find.byType(Row).first);

      expect(find.byType(FilledButton), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(OneTapLocationButton)),
        buttonOrigin,
      );
      expect(tester.getTopLeft(find.text('Address')), textOrigin);
      expect(
        () => row.getDryLayout(const BoxConstraints(maxWidth: 400)),
        returnsNormally,
      );
      expect(tester.takeException(), isNull);
    }, variant: onAndroid);

    testWidgets('uses the label geometry of the script of the app', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildButton(
          wrap: (Widget button) => Localizations(
            locale: const Locale('ja'),
            delegates: const <LocalizationsDelegate<Object?>>[
              _DenseScriptLocalizationsDelegate(),
              DefaultWidgetsLocalizations.delegate,
            ],
            child: Center(child: button),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final TextStyle style = tester
          .widget<Material>(fallbackShape())
          .textStyle!;

      expect(
        style,
        Typography.dense2021.labelLarge!.copyWith(color: style.color),
      );
    }, variant: onAndroid);

    testWidgets('reserves its size while the device is checked', (
      WidgetTester tester,
    ) async {
      deferAvailabilityChecks = true;
      await tester.pumpWidget(buildButton());
      await tester.pump();

      expect(
        tester.getSize(find.byType(OneTapLocationButton)),
        const Size(800, 48),
      );
      expect(find.byType(FilledButton), findsNothing);

      pendingAvailabilityChecks.single.complete(availabilityFor(false));
      await tester.pumpAndSettle();
      expect(find.byType(FilledButton), findsOneWidget);
    }, variant: onAndroid);
  });
}

class _DenseScriptLocalizations extends DefaultMaterialLocalizations {
  const _DenseScriptLocalizations();

  @override
  ScriptCategory get scriptCategory => ScriptCategory.dense;
}

class _DenseScriptLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _DenseScriptLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) {
    return SynchronousFuture<MaterialLocalizations>(
      const _DenseScriptLocalizations(),
    );
  }

  @override
  bool shouldReload(_DenseScriptLocalizationsDelegate old) => false;
}
