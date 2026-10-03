// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// @docImport 'package:flutter/material.dart';
///
/// @docImport 'button.dart';
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// The text of the system button on iOS.
///
/// The system provides and localizes the text.
enum IOSLocationButtonLabel {
  /// No text; the button shows its icon only.
  none,

  /// "Current Location".
  currentLocation,

  /// "Send Current Location".
  sendCurrentLocation,

  /// "Send My Current Location".
  sendMyCurrentLocation,

  /// "Share Current Location".
  shareCurrentLocation,

  /// "Share My Current Location".
  shareMyCurrentLocation,
}

/// The icon of the system button on iOS.
enum IOSLocationButtonIcon {
  /// No icon; the button shows its text only.
  none,

  /// A filled arrow.
  arrowFilled,

  /// An outlined arrow.
  arrowOutline,
}

/// The text of the system button on Android.
///
/// The system provides and localizes the text, and cuts it off when the button
/// is too narrow for it. The button always shows its icon.
///
/// The fallback button shown on Android versions without the system button
/// uses the English text, unless
/// [OneTapLocationButtonStyle.androidFallbackLabel] provides another.
enum AndroidLocationButtonLabel {
  /// No text; the button shows its icon only.
  none,

  /// "Precise location".
  preciseLocation,

  /// "Use precise location".
  usePreciseLocation,

  /// "Share precise location".
  sharePreciseLocation,

  /// "Near my precise location".
  nearMyPreciseLocation,

  /// "Near your precise location".
  nearYourPreciseLocation,
}

/// The appearance of a [OneTapLocationButton].
///
/// The system limits styling to keep the button legible. On iOS, the background
/// must be fully opaque and the foreground must contrast with it; otherwise the
/// system ignores taps without reporting an error. On Android, the system makes
/// the background opaque and adjusts the foreground until it contrasts enough.
///
/// On Android 17 the system draws its button with the same colors in a dark
/// theme as in a light one, so an app whose dark theme needs a different button
/// sets [backgroundColor] and [foregroundColor] itself.
///
/// The Android properties also style the fallback button shown on Android
/// versions without the system button. The fallback button uses the colors as
/// given, so choose a foreground that contrasts with the background.
@immutable
final class OneTapLocationButtonStyle with Diagnosticable {
  /// Creates a style. Properties that are null use the system defaults.
  const OneTapLocationButtonStyle({
    this.backgroundColor,
    this.foregroundColor,
    this.cornerRadius,
    this.iosLabel = IOSLocationButtonLabel.currentLocation,
    this.iosIcon = IOSLocationButtonIcon.arrowFilled,
    this.iosFontSize,
    this.androidLabel = AndroidLocationButtonLabel.preciseLocation,
    this.androidStrokeColor,
    this.androidStrokeWidth,
    this.androidPressedCornerRadius,
    this.androidFallbackLabel,
  }) : assert(
         iosLabel != IOSLocationButtonLabel.none ||
             iosIcon != IOSLocationButtonIcon.none,
         'The button needs a label, an icon, or both.',
       ),
       assert(cornerRadius == null || cornerRadius >= 0),
       assert(iosFontSize == null || iosFontSize > 0),
       assert(androidStrokeWidth == null || androidStrokeWidth >= 0),
       assert(
         androidPressedCornerRadius == null || androidPressedCornerRadius >= 0,
       );

  /// The fill color. Must be fully opaque.
  ///
  /// When null, the system chooses the color, and the fallback button on
  /// Android uses [ColorScheme.secondaryContainer] of the ambient [Theme].
  final Color? backgroundColor;

  /// The color of the text and the icon.
  ///
  /// When null, the system chooses the color, and the fallback button on
  /// Android uses [ColorScheme.onSecondaryContainer] of the ambient [Theme].
  final Color? foregroundColor;

  /// The corner radius in logical pixels.
  ///
  /// When null, the corners are square on iOS and fully rounded on Android.
  final double? cornerRadius;

  /// The text shown on iOS.
  final IOSLocationButtonLabel iosLabel;

  /// The icon shown on iOS.
  final IOSLocationButtonIcon iosIcon;

  /// The font size on iOS, in points.
  ///
  /// A larger font increases the size of the button.
  final double? iosFontSize;

  /// The text shown on Android.
  final AndroidLocationButtonLabel androidLabel;

  /// The color of the outline on Android.
  final Color? androidStrokeColor;

  /// The width of the outline on Android, in logical pixels.
  ///
  /// The system limits the width to 3 logical pixels. The outline is drawn only
  /// when [androidStrokeColor] is set as well.
  final double? androidStrokeWidth;

  /// The corner radius on Android while the button is pressed, in logical
  /// pixels.
  ///
  /// When null, the pressed button takes the corner radius that the system
  /// gives a pressed button of its height, whatever [cornerRadius] is.
  final double? androidPressedCornerRadius;

  /// The text of the fallback button shown on Android versions without the
  /// system button.
  ///
  /// Unlike the system, the fallback button does not translate its text, so
  /// apps that support several languages provide the text here. When null, the
  /// fallback button shows the English text of [androidLabel]. With
  /// [AndroidLocationButtonLabel.none], the fallback button shows its icon only
  /// and uses the text as its semantic label.
  final String? androidFallbackLabel;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(
        ColorProperty('backgroundColor', backgroundColor, defaultValue: null),
      )
      ..add(
        ColorProperty('foregroundColor', foregroundColor, defaultValue: null),
      )
      ..add(DoubleProperty('cornerRadius', cornerRadius, defaultValue: null))
      ..add(
        EnumProperty<IOSLocationButtonLabel>(
          'iosLabel',
          iosLabel,
          defaultValue: IOSLocationButtonLabel.currentLocation,
        ),
      )
      ..add(
        EnumProperty<IOSLocationButtonIcon>(
          'iosIcon',
          iosIcon,
          defaultValue: IOSLocationButtonIcon.arrowFilled,
        ),
      )
      ..add(DoubleProperty('iosFontSize', iosFontSize, defaultValue: null))
      ..add(
        EnumProperty<AndroidLocationButtonLabel>(
          'androidLabel',
          androidLabel,
          defaultValue: AndroidLocationButtonLabel.preciseLocation,
        ),
      )
      ..add(
        ColorProperty(
          'androidStrokeColor',
          androidStrokeColor,
          defaultValue: null,
        ),
      )
      ..add(
        DoubleProperty(
          'androidStrokeWidth',
          androidStrokeWidth,
          defaultValue: null,
        ),
      )
      ..add(
        DoubleProperty(
          'androidPressedCornerRadius',
          androidPressedCornerRadius,
          defaultValue: null,
        ),
      )
      ..add(
        StringProperty(
          'androidFallbackLabel',
          androidFallbackLabel,
          defaultValue: null,
        ),
      );
  }

  @override
  bool operator ==(Object other) =>
      other is OneTapLocationButtonStyle &&
      other.backgroundColor == backgroundColor &&
      other.foregroundColor == foregroundColor &&
      other.cornerRadius == cornerRadius &&
      other.iosLabel == iosLabel &&
      other.iosIcon == iosIcon &&
      other.iosFontSize == iosFontSize &&
      other.androidLabel == androidLabel &&
      other.androidStrokeColor == androidStrokeColor &&
      other.androidStrokeWidth == androidStrokeWidth &&
      other.androidPressedCornerRadius == androidPressedCornerRadius &&
      other.androidFallbackLabel == androidFallbackLabel;

  @override
  int get hashCode => Object.hash(
    backgroundColor,
    foregroundColor,
    cornerRadius,
    iosLabel,
    iosIcon,
    iosFontSize,
    androidLabel,
    androidStrokeColor,
    androidStrokeWidth,
    androidPressedCornerRadius,
    androidFallbackLabel,
  );
}
