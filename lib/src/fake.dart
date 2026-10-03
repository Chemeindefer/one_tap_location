// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// @docImport 'button.dart';
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'availability.dart';
import 'diagnostic.dart';
import 'exception.dart';
import 'location_request.dart';
import 'platform.dart';
import 'result.dart';

/// Stands in for the platform in tests of apps that show a
/// [OneTapLocationButton].
///
/// While a fake is installed, buttons that are created call no platform
/// channel and create no platform view, and
/// [OneTapLocationButton.checkAvailability] reports the device that the fake
/// describes. The target platform, [defaultTargetPlatform], decides what the
/// buttons show:
///
///  * On iOS, a button that stands in for the system button, with the size
///    [iosButtonSize]. Where [hasIOSSystemButton] is false, nothing.
///  * On Android, the fallback button, or the widget that
///    [OneTapLocationButton.fallbackBuilder] builds. Where
///    [hasAndroidSystemButton] is true, a button that stands in for the system
///    button instead, with the size of the system button.
///  * On the web and on other platforms, nothing.
///
/// A button that stands in for the system button resembles the fallback button
/// and shows the English text of the label that the style selects. It shows
/// what the system button would, but not how the system draws it, and on
/// Android it is not hidden while other content covers it.
///
/// A tap adds a [FakeLocationRequest] to [requests]. The request reports
/// [result] once the tap has been handled, or waits until the test answers it.
/// The button receives each answer of the test before the call returns; pump a
/// frame to see its effect. While a request waits, the button accepts no taps,
/// and the `onPressed` callback given to [OneTapLocationButton.fallbackBuilder]
/// is null.
///
/// Install the fake before the buttons are created, and uninstall it when the
/// test ends:
///
/// ```dart
/// late FakeOneTapLocation location;
///
/// setUp(() {
///   location = FakeOneTapLocation.install();
///   addTearDown(location.uninstall);
/// });
///
/// testWidgets('fills in the coordinates after a tap', (
///   WidgetTester tester,
/// ) async {
///   location.result = OneTapLocationGranted(
///     OneTapPosition(
///       latitude: 41.0082,
///       longitude: 28.9784,
///       timestamp: DateTime.utc(2026, 9, 16),
///       isPrecise: true,
///     ),
///   );
///   await tester.pumpWidget(const MaterialApp(home: AddressForm()));
///
///   await tester.tap(find.byType(OneTapLocationButton));
///   await tester.pump();
///
///   expect(find.text('41.0082, 28.9784'), findsOneWidget);
/// });
/// ```
final class FakeOneTapLocation {
  FakeOneTapLocation._();

  /// Installs a new fake and returns it, replacing a fake that was installed
  /// before.
  ///
  /// Buttons keep what they were created with: buttons that exist already keep
  /// reaching the platform or the previous fake.
  static FakeOneTapLocation install() {
    final FakeOneTapLocation fake = FakeOneTapLocation._();
    platformOverride = fake._platform;
    return fake;
  }

  late final _FakePlatform _platform = _FakePlatform(this);
  final List<FakeLocationRequest> _requests = <FakeLocationRequest>[];

  /// Whether the device has the system location button when the target
  /// platform is Android, as devices with Android 17 and later do.
  ///
  /// Defaults to false, as on Android 7 to 16. A button reads the value when
  /// it is created.
  bool hasAndroidSystemButton = false;

  /// Whether the device shows the system location button when the target
  /// platform is iOS.
  ///
  /// Defaults to true. Set it to false for an iPhone or iPad app on Apple
  /// Vision Pro with visionOS 26.1 or later, where
  /// [OneTapLocationButton.checkAvailability] reports
  /// [OneTapLocationButtonType.none] and buttons show nothing. A button reads
  /// the value when it is created.
  bool hasIOSSystemButton = true;

  /// The value of
  /// [OneTapLocationAvailability.isPreciseLocationRestrictedToSystemButton]
  /// when the target platform is Android.
  ///
  /// The value does not change the outcome of taps; [result] and the answers
  /// to [requests] decide that.
  bool isPreciseLocationRestrictedToSystemButton = false;

  /// The size of the button that stands in for the system button on iOS.
  ///
  /// On a device, the system button takes the size that its label, its icon and
  /// its font size require. The default is the size of the system button with
  /// the default style, so set the size when the app uses another style. A
  /// button reads the value when it is created.
  Size iosButtonSize = const Size(205, 52);

  /// The result that a new request reports once the tap has been handled.
  ///
  /// The result is reported with the progress that a device reports before it;
  /// see [FakeLocationRequest.complete]. When null, a request waits until the
  /// test answers it.
  OneTapLocationResult? result;

  /// The requests made by taps on buttons that use this fake, oldest first.
  List<FakeLocationRequest> get requests =>
      List<FakeLocationRequest>.unmodifiable(_requests);

  /// Removes this fake, so that buttons created afterwards reach the platform
  /// again.
  ///
  /// Does nothing when another fake has replaced this one.
  void uninstall() {
    if (identical(platformOverride, _platform)) {
      platformOverride = null;
    }
  }
}

/// A request for location access, made by a tap on a [OneTapLocationButton]
/// that uses a [FakeOneTapLocation].
///
/// Answer the request as the user and the system would:
///
///  * [complete] with a [OneTapLocationGranted] or a [OneTapLocationFailed]
///    result when the user allows access, after [grantAccess] to check the app
///    while the position is determined. On iOS, a failure with
///    [OneTapLocationErrorCode.locationServicesDisabled] answers a tap without
///    access as well.
///  * [complete] with a [OneTapLocationDenied] result when the user denies
///    access, including a permission dialog of the fallback button that the
///    user closes on Android 11 and later while the app has no location access,
///    or after [grantAccess] when access is revoked while the position is
///    determined.
///  * [dismiss] when the tap ends without an answer, as described for
///    [OneTapLocationDiagnostic.tapWithoutAuthorization].
final class FakeLocationRequest {
  FakeLocationRequest._(this._listener);

  final LocationRequestListener _listener;
  _FakeRequestState _state = _FakeRequestState.waiting;

  /// Whether the request waits for an answer.
  ///
  /// False once the request is answered, and once the button that made it is
  /// removed. Answers to a request of a removed button have no effect.
  bool get isPending =>
      _state == _FakeRequestState.waiting ||
      _state == _FakeRequestState.locating;

  /// Grants access, so that the button starts to determine the position.
  ///
  /// [OneTapLocationController.isLocating] stays true until [complete] reports
  /// the outcome.
  ///
  /// Throws a [StateError] if access was granted already or the request was
  /// answered.
  void grantAccess() {
    _checkNotAnswered();
    if (_isCancelled) {
      return;
    }
    if (_state == _FakeRequestState.locating) {
      throw StateError('Access was granted already for this request.');
    }
    _state = _FakeRequestState.locating;
    _listener.onLocating();
  }

  /// Reports [result] and ends the request.
  ///
  /// Unless [grantAccess] was called, a [OneTapLocationGranted] or
  /// [OneTapLocationFailed] result grants access first, so that
  /// [OneTapLocationController.isLocating] turns true before the result is
  /// reported, as on a device. On iOS, a failure with
  /// [OneTapLocationErrorCode.locationServicesDisabled] is reported without it,
  /// because the system grants no access while location services are turned
  /// off.
  ///
  /// Throws a [StateError] if the request was answered.
  void complete(OneTapLocationResult result) {
    _checkNotAnswered();
    if (_isCancelled) {
      return;
    }
    if (_state == _FakeRequestState.waiting && _grantsAccessBefore(result)) {
      _listener.onLocating();
    }
    _state = _FakeRequestState.answered;
    _listener
      ..onResult(result)
      ..onDone();
  }

  /// Ends the request without a result, and the controller of the button
  /// reports [OneTapLocationDiagnostic.tapWithoutAuthorization].
  ///
  /// On a device, a tap ends this way when the user closes the confirmation of
  /// the system button on Android without answering it, when the permission
  /// request of the fallback button is interrupted before the user answers, and
  /// when a tap on iOS does not grant access. On iOS, access that is granted
  /// later still produces a result for that tap; to test the app in that case,
  /// tap the button again and answer the new request.
  ///
  /// Throws a [StateError] if access was granted or the request was answered.
  void dismiss() {
    _checkNotAnswered();
    if (_isCancelled) {
      return;
    }
    if (_state == _FakeRequestState.locating) {
      throw StateError(
        'A request that was granted access cannot be dismissed.',
      );
    }
    _state = _FakeRequestState.answered;
    _listener
      ..onDiagnostic(OneTapLocationDiagnostic.tapWithoutAuthorization)
      ..onDone();
  }

  // The request of a removed button is cancelled, as on a device.
  bool get _isCancelled => _state == _FakeRequestState.cancelled;

  void _checkNotAnswered() {
    if (_state == _FakeRequestState.answered) {
      throw StateError('This request was answered already.');
    }
  }

  void _cancel() {
    if (isPending) {
      _state = _FakeRequestState.cancelled;
    }
  }

  static bool _grantsAccessBefore(OneTapLocationResult result) {
    return switch (result) {
      OneTapLocationGranted() => true,
      OneTapLocationDenied() => false,
      OneTapLocationFailed(:final OneTapLocationException exception) =>
        exception.code != OneTapLocationErrorCode.locationServicesDisabled ||
            kIsWeb ||
            defaultTargetPlatform != TargetPlatform.iOS,
    };
  }
}

enum _FakeRequestState { waiting, locating, answered, cancelled }

final class _FakePlatform implements PlatformOverride {
  _FakePlatform(this._fake);

  final FakeOneTapLocation _fake;

  @override
  OneTapLocationAvailability get availability {
    if (kIsWeb) {
      return const OneTapLocationAvailability(
        buttonType: OneTapLocationButtonType.none,
      );
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => OneTapLocationAvailability(
        buttonType: _fake.hasIOSSystemButton
            ? OneTapLocationButtonType.system
            : OneTapLocationButtonType.none,
      ),
      TargetPlatform.android => OneTapLocationAvailability(
        buttonType: _fake.hasAndroidSystemButton
            ? OneTapLocationButtonType.system
            : OneTapLocationButtonType.fallback,
        isPreciseLocationRestrictedToSystemButton:
            _fake.isPreciseLocationRestrictedToSystemButton,
      ),
      TargetPlatform.fuchsia ||
      TargetPlatform.linux ||
      TargetPlatform.macOS ||
      TargetPlatform.windows => const OneTapLocationAvailability(
        buttonType: OneTapLocationButtonType.none,
      ),
    };
  }

  @override
  Size get iosButtonSize => _fake.iosButtonSize;

  @override
  LocationRequest createRequest() => _FakeRequest(_fake);
}

/// Connects a button to the [FakeLocationRequest] that its tap makes.
final class _FakeRequest implements LocationRequest {
  _FakeRequest(this._fake);

  final FakeOneTapLocation _fake;
  FakeLocationRequest? _request;

  @override
  void start(LocationRequestListener listener) {
    final FakeLocationRequest request = FakeLocationRequest._(listener);
    _request = request;
    _fake._requests.add(request);
    final OneTapLocationResult? result = _fake.result;
    if (result != null) {
      // A device answers after the tap has been handled.
      scheduleMicrotask(() {
        if (request.isPending) {
          request.complete(result);
        }
      });
    }
  }

  @override
  void cancel() {
    _request?._cancel();
  }
}
