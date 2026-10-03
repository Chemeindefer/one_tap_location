// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// @docImport 'button.dart';
library;

import 'package:flutter/foundation.dart';

/// The button that a [OneTapLocationButton] shows.
///
/// See [OneTapLocationButton.checkAvailability].
enum OneTapLocationButtonType {
  /// The button that the system draws: `CLLocationButton` on iOS, and the
  /// system location button on Android 17 and later.
  system,

  /// The fallback button, which asks for access with the permission dialog of
  /// the system, on Android 7 to 16 and on devices with a later version of
  /// Android that lack the system location button.
  fallback,

  /// No button, on the web, on platforms other than iOS and Android, and in
  /// iPhone and iPad apps on Apple Vision Pro with visionOS 26.1 or later, where
  /// the system button does not respond to taps.
  none,
}

/// How a [OneTapLocationButton] obtains location access on a device.
///
/// See [OneTapLocationButton.checkAvailability].
@immutable
final class OneTapLocationAvailability {
  /// Creates an availability.
  const OneTapLocationAvailability({
    required this.buttonType,
    this.isPreciseLocationRestrictedToSystemButton = false,
  });

  /// The button that a [OneTapLocationButton] shows.
  final OneTapLocationButtonType buttonType;

  /// Whether the app can obtain precise location only through the system
  /// location button.
  ///
  /// True on Android 17 and later when the app declares
  /// `ACCESS_FINE_LOCATION` with
  /// `android:usesPermissionFlags="onlyForLocationButton"`. Android then grants
  /// precise location only through the system location button, not through
  /// the permission dialog that the fallback button shows.
  ///
  /// False on iOS, on Android 16 and earlier, which do not apply the flag, and
  /// on other platforms.
  final bool isPreciseLocationRestrictedToSystemButton;

  @override
  bool operator ==(Object other) =>
      other is OneTapLocationAvailability &&
      other.buttonType == buttonType &&
      other.isPreciseLocationRestrictedToSystemButton ==
          isPreciseLocationRestrictedToSystemButton;

  @override
  int get hashCode =>
      Object.hash(buttonType, isPreciseLocationRestrictedToSystemButton);

  @override
  String toString() => isPreciseLocationRestrictedToSystemButton
      ? 'OneTapLocationAvailability(${buttonType.name}, precise location '
            'restricted to the system button)'
      : 'OneTapLocationAvailability(${buttonType.name})';
}
