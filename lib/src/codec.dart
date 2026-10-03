// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/painting.dart';

import 'availability.dart';
import 'diagnostic.dart';
import 'exception.dart';
import 'result.dart';
import 'style.dart';

/// The answer to a request for location access made by the fallback button.
enum FallbackPermissionAnswer {
  /// Precise or approximate access was granted.
  granted,

  /// Access was denied.
  denied,

  /// The request was interrupted before the user answered.
  cancelled,
}

/// Encodes [style] as the creation parameters of the system button on iOS.
Map<String, Object?> encodeIOSStyle(OneTapLocationButtonStyle style) {
  return <String, Object?>{
    'iosLabel': style.iosLabel.name,
    'iosIcon': style.iosIcon.name,
    'iosFontSize': ?style.iosFontSize,
    'cornerRadius': ?style.cornerRadius,
    'backgroundColor': ?style.backgroundColor?.toARGB32(),
    'foregroundColor': ?style.foregroundColor?.toARGB32(),
  };
}

/// Encodes [style] as the creation parameters of the system button on Android.
Map<String, Object?> encodeAndroidStyle(OneTapLocationButtonStyle style) {
  return <String, Object?>{
    'androidLabel': style.androidLabel.name,
    'cornerRadius': ?style.cornerRadius,
    'backgroundColor': ?style.backgroundColor?.toARGB32(),
    'foregroundColor': ?style.foregroundColor?.toARGB32(),
    'androidStrokeColor': ?style.androidStrokeColor?.toARGB32(),
    'androidStrokeWidth': ?style.androidStrokeWidth,
    'androidPressedCornerRadius': ?style.androidPressedCornerRadius,
  };
}

/// Decodes the availability that the platform reports.
///
/// [withoutSystemButton] is the button type of a device on which the system
/// location button is not available.
OneTapLocationAvailability decodeAvailability(
  Map<Object?, Object?> availability, {
  required OneTapLocationButtonType withoutSystemButton,
}) {
  return OneTapLocationAvailability(
    buttonType: availability['isSystemButtonAvailable']! as bool
        ? OneTapLocationButtonType.system
        : withoutSystemButton,
    isPreciseLocationRestrictedToSystemButton:
        availability['isPreciseLocationRestrictedToSystemButton']! as bool,
  );
}

/// Decodes the answer to a request for location access made by the fallback
/// button.
FallbackPermissionAnswer decodePermissionAnswer(Object? answer) {
  return FallbackPermissionAnswer.values.byName(answer! as String);
}

/// Decodes the size the system requires for the button.
///
/// The size is rounded up to whole logical pixels, because the system ignores
/// taps on a button that is smaller than it requires.
Size decodeButtonSize(Map<Object?, Object?> size) {
  return Size(
    (size['width']! as num).ceilToDouble(),
    (size['height']! as num).ceilToDouble(),
  );
}

/// Decodes the arguments of an `onResult` call from the system button, or the
/// reply to a `requestFallbackPosition` call.
OneTapLocationResult decodeResult(Map<Object?, Object?> arguments) {
  final Object? status = arguments['status'];
  return switch (status) {
    'granted' => OneTapLocationGranted(
      decodePosition(arguments['position']! as Map<Object?, Object?>),
    ),
    'denied' => const OneTapLocationDenied(),
    'failed' => OneTapLocationFailed(
      OneTapLocationException(
        OneTapLocationErrorCode.values.asNameMap()[arguments['code']] ??
            OneTapLocationErrorCode.unknown,
        arguments['message'] as String?,
      ),
    ),
    _ => throw ArgumentError.value(status, 'status', 'Unknown result status'),
  };
}

/// Decodes the position of a granted result.
OneTapPosition decodePosition(Map<Object?, Object?> position) {
  return OneTapPosition(
    latitude: (position['latitude']! as num).toDouble(),
    longitude: (position['longitude']! as num).toDouble(),
    timestamp: DateTime.fromMillisecondsSinceEpoch(
      (position['timestamp']! as num).toInt(),
      isUtc: true,
    ),
    isPrecise: position['isPrecise']! as bool,
    horizontalAccuracy: (position['horizontalAccuracy'] as num?)?.toDouble(),
    altitude: (position['altitude'] as num?)?.toDouble(),
  );
}

/// Decodes the arguments of an `onDiagnostic` call from the system button.
OneTapLocationDiagnostic decodeDiagnostic(Map<Object?, Object?> arguments) {
  return OneTapLocationDiagnostic.values.byName(
    arguments['diagnostic']! as String,
  );
}
