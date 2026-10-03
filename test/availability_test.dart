// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_tap_location/one_tap_location.dart';
import 'package:one_tap_location/src/platform.dart'
    show resetPlatformStateForTesting;

const MethodChannel _pluginChannel = MethodChannel('one_tap_location');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<MethodCall> calls;
  late Object? Function() answer;

  setUp(() {
    resetPlatformStateForTesting();
    calls = <MethodCall>[];
    answer = () => <String, Object?>{
      'isSystemButtonAvailable': true,
      'isPreciseLocationRestrictedToSystemButton': false,
    };
    messenger.setMockMethodCallHandler(_pluginChannel, (MethodCall call) async {
      calls.add(call);
      return answer();
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(_pluginChannel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('asks iOS once', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    final OneTapLocationAvailability first =
        await OneTapLocationButton.checkAvailability();
    final OneTapLocationAvailability second =
        await OneTapLocationButton.checkAvailability();

    expect(
      first,
      const OneTapLocationAvailability(
        buttonType: OneTapLocationButtonType.system,
      ),
    );
    expect(second, first);
    expect(calls.single.method, 'getAvailability');
  });

  test(
    'reports no button on iOS where the system button ignores taps',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      answer = () => <String, Object?>{
        'isSystemButtonAvailable': false,
        'isPreciseLocationRestrictedToSystemButton': false,
      };

      expect(
        await OneTapLocationButton.checkAvailability(),
        const OneTapLocationAvailability(
          buttonType: OneTapLocationButtonType.none,
        ),
      );
    },
  );

  test('reports no button on other platforms', () async {
    for (final TargetPlatform platform in <TargetPlatform>[
      TargetPlatform.fuchsia,
      TargetPlatform.linux,
      TargetPlatform.macOS,
      TargetPlatform.windows,
    ]) {
      debugDefaultTargetPlatformOverride = platform;

      expect(
        await OneTapLocationButton.checkAvailability(),
        const OneTapLocationAvailability(
          buttonType: OneTapLocationButtonType.none,
        ),
        reason: platform.name,
      );
    }
    expect(calls, isEmpty);
  });

  test('asks Android once', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    answer = () => <String, Object?>{
      'isSystemButtonAvailable': false,
      'isPreciseLocationRestrictedToSystemButton': true,
    };

    final OneTapLocationAvailability first =
        await OneTapLocationButton.checkAvailability();
    final OneTapLocationAvailability second =
        await OneTapLocationButton.checkAvailability();

    expect(
      first,
      const OneTapLocationAvailability(
        buttonType: OneTapLocationButtonType.fallback,
        isPreciseLocationRestrictedToSystemButton: true,
      ),
    );
    expect(second, first);
    expect(calls.single.method, 'getAvailability');
  });

  test('asks Android again after a failure', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    answer = () => throw PlatformException(code: 'error');

    await expectLater(
      OneTapLocationButton.checkAvailability(),
      throwsA(isA<PlatformException>()),
    );
    answer = () => <String, Object?>{
      'isSystemButtonAvailable': true,
      'isPreciseLocationRestrictedToSystemButton': false,
    };

    expect(
      await OneTapLocationButton.checkAvailability(),
      const OneTapLocationAvailability(
        buttonType: OneTapLocationButtonType.system,
      ),
    );
    expect(calls, hasLength(2));
  });

  test('compares by value', () {
    const OneTapLocationAvailability restricted = OneTapLocationAvailability(
      buttonType: OneTapLocationButtonType.fallback,
      isPreciseLocationRestrictedToSystemButton: true,
    );

    expect(
      restricted,
      const OneTapLocationAvailability(
        buttonType: OneTapLocationButtonType.fallback,
        isPreciseLocationRestrictedToSystemButton: true,
      ),
    );
    expect(
      restricted.hashCode,
      const OneTapLocationAvailability(
        buttonType: OneTapLocationButtonType.fallback,
        isPreciseLocationRestrictedToSystemButton: true,
      ).hashCode,
    );
    expect(
      restricted,
      isNot(
        const OneTapLocationAvailability(
          buttonType: OneTapLocationButtonType.fallback,
        ),
      ),
    );
    expect(
      restricted.toString(),
      'OneTapLocationAvailability(fallback, precise location restricted to '
      'the system button)',
    );
    expect(
      const OneTapLocationAvailability(
        buttonType: OneTapLocationButtonType.system,
      ).toString(),
      'OneTapLocationAvailability(system)',
    );
  });
}
