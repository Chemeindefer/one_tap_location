// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// @docImport 'button.dart';
/// @docImport 'diagnostic.dart';
library;

import 'package:flutter/foundation.dart';

import 'exception.dart';

/// The outcome of a tap on a [OneTapLocationButton].
///
/// A result is reported only once the outcome is known. A tap that the system
/// ignores produces no result; on iOS, such a tap is reported through
/// [OneTapLocationDiagnostic.tapWithoutAuthorization].
@immutable
sealed class OneTapLocationResult {
  /// Creates a result.
  const OneTapLocationResult();
}

/// Location access was granted and a position was obtained.
final class OneTapLocationGranted extends OneTapLocationResult {
  /// Creates a result for [position].
  const OneTapLocationGranted(this.position);

  /// The position obtained after access was granted.
  final OneTapPosition position;

  @override
  bool operator ==(Object other) =>
      other is OneTapLocationGranted && other.position == position;

  @override
  int get hashCode => position.hashCode;

  @override
  String toString() => 'OneTapLocationGranted($position)';
}

/// Location access was denied by the user or by a device policy.
///
/// On Android 11 and later, once the user has denied access twice, the system
/// denies later taps without showing its confirmation or its permission
/// dialog. On Android 7 to 10, the fallback button is denied without a dialog
/// once the user chooses not to be asked again. The user can then allow
/// location access for the app in the system settings.
final class OneTapLocationDenied extends OneTapLocationResult {
  /// Creates a denied result.
  const OneTapLocationDenied();

  @override
  bool operator ==(Object other) => other is OneTapLocationDenied;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'OneTapLocationDenied()';
}

/// No position could be obtained.
///
/// Access was granted before the failure, except when iOS answers a tap with
/// [OneTapLocationErrorCode.locationServicesDisabled]: with location services
/// turned off, the system grants no access, and
/// [OneTapLocationController.isLocating] does not turn true. A failure with that
/// code also follows a grant when location services are turned off while the
/// position is determined.
final class OneTapLocationFailed extends OneTapLocationResult {
  /// Creates a failed result caused by [exception].
  const OneTapLocationFailed(this.exception);

  /// The error that prevented a position from being obtained.
  final OneTapLocationException exception;

  @override
  bool operator ==(Object other) =>
      other is OneTapLocationFailed && other.exception == exception;

  @override
  int get hashCode => exception.hashCode;

  @override
  String toString() => 'OneTapLocationFailed($exception)';
}

/// A geographic position reported by a [OneTapLocationButton].
@immutable
final class OneTapPosition {
  /// Creates a position.
  const OneTapPosition({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.isPrecise,
    this.horizontalAccuracy,
    this.altitude,
  });

  /// The latitude in degrees.
  final double latitude;

  /// The longitude in degrees.
  final double longitude;

  /// The time at which the position was determined, in UTC.
  ///
  /// An approximate position can be several minutes old: on Android, the
  /// system determines approximate positions at most every ten minutes, and the
  /// fallback button reports such a position right away.
  final DateTime timestamp;

  /// Whether the user allowed precise location.
  ///
  /// When false, the position is approximate and has no [altitude].
  final bool isPrecise;

  /// The radius of uncertainty of [latitude] and [longitude], in meters.
  ///
  /// Null if the platform did not report a valid value.
  final double? horizontalAccuracy;

  /// The altitude above mean sea level, in meters.
  ///
  /// Null if [isPrecise] is false, or if no valid altitude was determined for
  /// the position. On Android, the altitude is available only on Android 14
  /// and later.
  final double? altitude;

  @override
  bool operator ==(Object other) =>
      other is OneTapPosition &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.timestamp == timestamp &&
      other.isPrecise == isPrecise &&
      other.horizontalAccuracy == horizontalAccuracy &&
      other.altitude == altitude;

  @override
  int get hashCode => Object.hash(
    latitude,
    longitude,
    timestamp,
    isPrecise,
    horizontalAccuracy,
    altitude,
  );

  @override
  String toString() {
    final List<String> details = <String>[
      '$latitude',
      '$longitude',
      if (isPrecise) 'precise' else 'approximate',
      'timestamp: $timestamp',
      if (horizontalAccuracy != null) 'horizontalAccuracy: $horizontalAccuracy',
      if (altitude != null) 'altitude: $altitude',
    ];
    return 'OneTapPosition(${details.join(', ')})';
  }
}
