// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

/// The reason a [OneTapLocationException] was raised.
enum OneTapLocationErrorCode {
  /// The platform could not determine the position.
  ///
  /// On Android, this is also reported when the user allowed only approximate
  /// location and Android determined no approximate position within 30
  /// seconds.
  locationUnavailable,

  /// Location services are turned off on the device.
  ///
  /// Neither iOS nor Android asks the user to turn them on after a tap, so the
  /// app can explain that they are needed; the user turns them on in the
  /// system settings.
  locationServicesDisabled,

  /// The platform reported an error that no other code describes.
  unknown,
}

/// An error that prevented a position from being obtained.
@immutable
final class OneTapLocationException implements Exception {
  /// Creates an exception with a [code] and an optional platform [message].
  const OneTapLocationException(this.code, [this.message]);

  /// The reason for the error.
  final OneTapLocationErrorCode code;

  /// The description provided by the platform, if any.
  ///
  /// Intended for logging; it is not localized.
  final String? message;

  @override
  bool operator ==(Object other) =>
      other is OneTapLocationException &&
      other.code == code &&
      other.message == message;

  @override
  int get hashCode => Object.hash(code, message);

  @override
  String toString() => message == null
      ? 'OneTapLocationException(${code.name})'
      : 'OneTapLocationException(${code.name}, $message)';
}
