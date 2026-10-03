// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_tap_location/one_tap_location.dart';
import 'package:one_tap_location/src/codec.dart';

void main() {
  group('encodeIOSStyle', () {
    test('encodes the default style', () {
      expect(
        encodeIOSStyle(const OneTapLocationButtonStyle()),
        <String, Object?>{
          'iosLabel': 'currentLocation',
          'iosIcon': 'arrowFilled',
        },
      );
    });

    test('encodes every property', () {
      const OneTapLocationButtonStyle style = OneTapLocationButtonStyle(
        backgroundColor: Color(0xFF3366FF),
        foregroundColor: Color(0xFFFFFFFF),
        cornerRadius: 12,
        iosLabel: IOSLocationButtonLabel.shareMyCurrentLocation,
        iosIcon: IOSLocationButtonIcon.none,
        iosFontSize: 20,
      );

      expect(encodeIOSStyle(style), <String, Object?>{
        'iosLabel': 'shareMyCurrentLocation',
        'iosIcon': 'none',
        'iosFontSize': 20.0,
        'cornerRadius': 12.0,
        'backgroundColor': 0xFF3366FF,
        'foregroundColor': 0xFFFFFFFF,
      });
    });
  });

  group('encodeAndroidStyle', () {
    test('encodes the default style', () {
      expect(
        encodeAndroidStyle(const OneTapLocationButtonStyle()),
        <String, Object?>{'androidLabel': 'preciseLocation'},
      );
    });

    test('encodes every property', () {
      const OneTapLocationButtonStyle style = OneTapLocationButtonStyle(
        backgroundColor: Color(0xFF3366FF),
        foregroundColor: Color(0xFFFFFFFF),
        cornerRadius: 12,
        androidLabel: AndroidLocationButtonLabel.sharePreciseLocation,
        androidStrokeColor: Color(0xFF102040),
        androidStrokeWidth: 2,
        androidPressedCornerRadius: 16,
      );

      expect(encodeAndroidStyle(style), <String, Object?>{
        'androidLabel': 'sharePreciseLocation',
        'cornerRadius': 12.0,
        'backgroundColor': 0xFF3366FF,
        'foregroundColor': 0xFFFFFFFF,
        'androidStrokeColor': 0xFF102040,
        'androidStrokeWidth': 2.0,
        'androidPressedCornerRadius': 16.0,
      });
    });
  });

  test('decodeButtonSize rounds up to whole logical pixels', () {
    expect(
      decodeButtonSize(<Object?, Object?>{'width': 204.33, 'height': 51}),
      const Size(205, 51),
    );
  });

  group('decodeResult', () {
    test('decodes a granted result', () {
      final OneTapLocationResult result = decodeResult(<Object?, Object?>{
        'status': 'granted',
        'position': <Object?, Object?>{
          'latitude': 41.0082,
          'longitude': 28.9784,
          'timestamp': 1757800000000,
          'isPrecise': true,
          'horizontalAccuracy': 5.0,
          'altitude': 39.5,
        },
      });

      expect(
        result,
        OneTapLocationGranted(
          OneTapPosition(
            latitude: 41.0082,
            longitude: 28.9784,
            timestamp: DateTime.fromMillisecondsSinceEpoch(
              1757800000000,
              isUtc: true,
            ),
            isPrecise: true,
            horizontalAccuracy: 5,
            altitude: 39.5,
          ),
        ),
      );
    });

    test('leaves unavailable position details null', () {
      expect(
        decodeResult(<Object?, Object?>{
          'status': 'granted',
          'position': <Object?, Object?>{
            'latitude': 41,
            'longitude': 29,
            'timestamp': 0,
            'isPrecise': false,
          },
        }),
        OneTapLocationGranted(
          OneTapPosition(
            latitude: 41,
            longitude: 29,
            timestamp: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
            isPrecise: false,
          ),
        ),
      );
    });

    test('decodes a denied result', () {
      expect(
        decodeResult(<Object?, Object?>{'status': 'denied'}),
        const OneTapLocationDenied(),
      );
    });

    test('decodes a failed result', () {
      expect(
        decodeResult(<Object?, Object?>{
          'status': 'failed',
          'code': 'locationUnavailable',
          'message': 'The operation could not be completed.',
        }),
        const OneTapLocationFailed(
          OneTapLocationException(
            OneTapLocationErrorCode.locationUnavailable,
            'The operation could not be completed.',
          ),
        ),
      );
    });

    test('decodes a failure caused by disabled location services', () {
      expect(
        decodeResult(<String, Object?>{
          'status': 'failed',
          'code': 'locationServicesDisabled',
        }),
        const OneTapLocationFailed(
          OneTapLocationException(
            OneTapLocationErrorCode.locationServicesDisabled,
          ),
        ),
      );
    });

    test('maps an unrecognized error code to unknown', () {
      expect(
        decodeResult(<Object?, Object?>{'status': 'failed', 'code': 'other'}),
        const OneTapLocationFailed(
          OneTapLocationException(OneTapLocationErrorCode.unknown),
        ),
      );
    });

    test('rejects an unrecognized status', () {
      expect(
        () => decodeResult(<Object?, Object?>{'status': 'pending'}),
        throwsArgumentError,
      );
    });
  });

  test('decodeDiagnostic decodes a diagnostic', () {
    expect(
      decodeDiagnostic(<Object?, Object?>{
        'diagnostic': 'tapWithoutAuthorization',
      }),
      OneTapLocationDiagnostic.tapWithoutAuthorization,
    );
  });

  test('decodeAvailability decodes the availability', () {
    expect(
      decodeAvailability(<Object?, Object?>{
        'isSystemButtonAvailable': true,
        'isPreciseLocationRestrictedToSystemButton': false,
      }, withoutSystemButton: OneTapLocationButtonType.fallback),
      const OneTapLocationAvailability(
        buttonType: OneTapLocationButtonType.system,
      ),
    );
    expect(
      decodeAvailability(<Object?, Object?>{
        'isSystemButtonAvailable': false,
        'isPreciseLocationRestrictedToSystemButton': true,
      }, withoutSystemButton: OneTapLocationButtonType.fallback),
      const OneTapLocationAvailability(
        buttonType: OneTapLocationButtonType.fallback,
        isPreciseLocationRestrictedToSystemButton: true,
      ),
    );
    expect(
      decodeAvailability(<Object?, Object?>{
        'isSystemButtonAvailable': false,
        'isPreciseLocationRestrictedToSystemButton': false,
      }, withoutSystemButton: OneTapLocationButtonType.none),
      const OneTapLocationAvailability(
        buttonType: OneTapLocationButtonType.none,
      ),
    );
  });

  test('decodePermissionAnswer decodes an answer', () {
    expect(decodePermissionAnswer('granted'), FallbackPermissionAnswer.granted);
    expect(decodePermissionAnswer('denied'), FallbackPermissionAnswer.denied);
    expect(
      decodePermissionAnswer('cancelled'),
      FallbackPermissionAnswer.cancelled,
    );
    expect(() => decodePermissionAnswer('allowed'), throwsArgumentError);
  });
}
