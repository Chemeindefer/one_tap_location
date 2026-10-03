// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'availability.dart';
import 'codec.dart';
import 'location_request.dart';
import 'style.dart';

/// The channel on which the plugin reaches its platform code.
const MethodChannel pluginChannel = MethodChannel('one_tap_location');

/// How the system button is shown on Android.
enum AndroidEmbedding {
  /// The device has no system location button, so the fallback button is
  /// shown.
  fallback,

  /// Hybrid composition, used when hybrid composition++ is not available.
  hybridComposition,

  /// Hybrid composition++, used when the app enables it and the device
  /// supports it.
  hybridCompositionPlusPlus,
}

/// Stands in for the platform code of the plugin.
abstract interface class PlatformOverride {
  /// The availability that buttons and [loadAvailability] report.
  OneTapLocationAvailability get availability;

  /// The size of the button that stands in for the system button on iOS.
  Size get iosButtonSize;

  /// Creates the request that a tap on a button starts.
  LocationRequest createRequest();
}

/// The override that buttons use when they are created, if any.
PlatformOverride? platformOverride;

/// The properties of a style that decide the size of the system button on iOS.
typedef IOSButtonContent = ({
  IOSLocationButtonLabel label,
  IOSLocationButtonIcon icon,
  double? fontSize,
});

Future<OneTapLocationAvailability>? _availabilityRequest;
OneTapLocationAvailability? _knownAvailability;
AndroidEmbedding? _knownAndroidEmbedding;
Future<AndroidEmbedding>? _androidEmbeddingRequest;
final Map<IOSButtonContent, Size> _iosButtonSizes = <IOSButtonContent, Size>{};

/// Forgets what was determined about the device, so that the next button and
/// the next availability query ask the platform again.
@visibleForTesting
void resetPlatformStateForTesting() {
  _availabilityRequest = null;
  _knownAvailability = null;
  _knownAndroidEmbedding = null;
  _androidEmbeddingRequest = null;
  _iosButtonSizes.clear();
}

/// Determines the availability, from [platformOverride] when one is set.
Future<OneTapLocationAvailability> loadAvailability() {
  final PlatformOverride? override = platformOverride;
  if (override != null) {
    return Future<OneTapLocationAvailability>.value(override.availability);
  }
  return loadPlatformAvailability();
}

/// Determines the availability on the device that the app runs on.
///
/// The availability does not change while the app runs, so the platform is
/// asked once. A failed request is not kept, so that the next call asks again.
Future<OneTapLocationAvailability> loadPlatformAvailability() {
  const OneTapLocationAvailability unavailable = OneTapLocationAvailability(
    buttonType: OneTapLocationButtonType.none,
  );
  if (kIsWeb) {
    return Future<OneTapLocationAvailability>.value(unavailable);
  }
  final OneTapLocationButtonType withoutSystemButton;
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      withoutSystemButton = OneTapLocationButtonType.none;
    case TargetPlatform.android:
      withoutSystemButton = OneTapLocationButtonType.fallback;
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
      return Future<OneTapLocationAvailability>.value(unavailable);
  }
  return _availabilityRequest ??= () async {
    try {
      final Map<Object?, Object?>? availability = await pluginChannel
          .invokeMapMethod<Object?, Object?>('getAvailability');
      return _knownAvailability = decodeAvailability(
        availability!,
        withoutSystemButton: withoutSystemButton,
      );
    } catch (_) {
      _availabilityRequest = null;
      rethrow;
    }
  }();
}

/// The availability on the device that the app runs on, if the platform has
/// reported it already.
OneTapLocationAvailability? get knownPlatformAvailability => _knownAvailability;

/// How the system button is shown on Android, if that was determined already.
AndroidEmbedding? get knownAndroidEmbedding => _knownAndroidEmbedding;

/// Determines how the system button is shown on Android.
///
/// Like the availability, the embedding does not change while the app runs,
/// so it is determined once.
Future<AndroidEmbedding> determineAndroidEmbedding() {
  return _androidEmbeddingRequest ??= () async {
    try {
      final OneTapLocationAvailability availability =
          await loadPlatformAvailability();
      final AndroidEmbedding embedding;
      if (availability.buttonType != OneTapLocationButtonType.system) {
        embedding = AndroidEmbedding.fallback;
      } else if (await HybridAndroidViewController.checkIfSupported()) {
        embedding = AndroidEmbedding.hybridCompositionPlusPlus;
      } else {
        embedding = AndroidEmbedding.hybridComposition;
      }
      return _knownAndroidEmbedding = embedding;
    } catch (_) {
      _androidEmbeddingRequest = null;
      rethrow;
    }
  }();
}

/// The properties of [style] that decide the size of the system button on iOS.
IOSButtonContent iosButtonContent(OneTapLocationButtonStyle style) {
  return (
    label: style.iosLabel,
    icon: style.iosIcon,
    fontSize: style.iosFontSize,
  );
}

/// The size that the system required for a button with the content of [style]
/// on iOS, if such a button was measured before.
///
/// The size depends only on the content, not on the text size of the device,
/// so a size that was measured once stays valid while the app runs.
Size? knownIOSButtonSize(OneTapLocationButtonStyle style) {
  return _iosButtonSizes[iosButtonContent(style)];
}

/// Measures the size that the system requires for a button with [style] on
/// iOS.
Future<Size> measureIOSButton(OneTapLocationButtonStyle style) async {
  final Map<Object?, Object?>? size = await pluginChannel
      .invokeMapMethod<Object?, Object?>(
        'measureButton',
        encodeIOSStyle(style),
      );
  return _iosButtonSizes[iosButtonContent(style)] = decodeButtonSize(size!);
}

/// Reports an error of the plugin to [FlutterError.onError].
void reportError(Object exception, StackTrace stack, String context) {
  FlutterError.reportError(
    FlutterErrorDetails(
      exception: exception,
      stack: stack,
      library: 'one_tap_location',
      context: ErrorDescription(context),
    ),
  );
}
