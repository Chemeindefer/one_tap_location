// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// @docImport 'fake.dart';
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'availability.dart';
import 'codec.dart';
import 'diagnostic.dart';
import 'fallback_button.dart';
import 'location_request.dart';
import 'platform.dart';
import 'result.dart';
import 'style.dart';
import 'visibility.dart';

const String _viewType = 'one_tap_location/location_button';

/// The smallest width and height the system accepts on Android.
const double _androidMinExtent = 48;

/// The largest height the system accepts on Android.
const double _androidMaxHeight = 136;

/// How long the button must stay fully visible before it is shown on Android.
///
/// Routes ignore pointer events while they close, so a closing dialog, menu or
/// sheet is not detected as covering the button. The delay outlasts the closing
/// transitions of the dialogs, menus and modal bottom sheets of the Material
/// library and of the dialogs and modal popups of the Cupertino library.
const Duration _showDelay = Duration(milliseconds: 350);

/// Builds the button that a [OneTapLocationButton] shows on Android where the
/// system location button is not available.
///
/// [onPressed] requests location access. It is null while a request is in
/// progress.
typedef OneTapLocationFallbackBuilder =
    Widget Function(BuildContext context, VoidCallback? onPressed);

/// Reports the state of a [OneTapLocationButton].
///
/// A controller can be attached to only one button at a time. Dispose it when
/// it is no longer needed.
final class OneTapLocationController extends ChangeNotifier {
  final StreamController<OneTapLocationDiagnostic> _diagnostics =
      StreamController<OneTapLocationDiagnostic>.broadcast();
  final Set<Object> _buttons = <Object>{};
  bool _isLocating = false;
  bool _isAttachmentCheckScheduled = false;
  bool _isDisposed = false;

  /// Whether the button is obtaining a position after access was granted.
  bool get isLocating => _isLocating;

  /// The diagnostics reported by the button.
  Stream<OneTapLocationDiagnostic> get diagnostics => _diagnostics.stream;

  void _attach(Object button, {required bool isLocating}) {
    _buttons.add(button);
    assert(_scheduleAttachmentCheck());
    _updateLocating(button, isLocating, deferNotification: true);
  }

  void _detach(Object button) {
    if (_buttons.remove(button) && _buttons.isEmpty) {
      _setLocating(false, deferNotification: true);
    }
  }

  // A button that replaces another one can attach before its predecessor
  // detaches, so the check runs once the frame is complete.
  bool _scheduleAttachmentCheck() {
    if (!_isAttachmentCheckScheduled) {
      _isAttachmentCheckScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((Duration timeStamp) {
        _isAttachmentCheckScheduled = false;
        assert(
          _isDisposed || _buttons.length <= 1,
          'A OneTapLocationController can be attached to only one '
          'OneTapLocationButton at a time.',
        );
      }, debugLabel: 'OneTapLocationController.checkAttachment');
    }
    return true;
  }

  void _updateLocating(
    Object button,
    bool value, {
    bool deferNotification = false,
  }) {
    if (_buttons.contains(button)) {
      _setLocating(value, deferNotification: deferNotification);
    }
  }

  // Buttons attach and detach while the widget tree is being built or
  // finalized, when listeners must not be notified synchronously.
  void _setLocating(bool value, {required bool deferNotification}) {
    if (_isDisposed || _isLocating == value) {
      return;
    }
    _isLocating = value;
    if (!deferNotification) {
      notifyListeners();
      return;
    }
    scheduleMicrotask(() {
      if (!_isDisposed) {
        notifyListeners();
      }
    });
  }

  void _addDiagnostic(OneTapLocationDiagnostic diagnostic) {
    if (!_isDisposed) {
      _diagnostics.add(diagnostic);
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    unawaited(_diagnostics.close());
    super.dispose();
  }
}

/// A button that obtains the user's location with a single tap.
///
/// The system draws the button: `CLLocationButton` on iOS 15 and later, and the
/// system location button on Android 17 and later. A tap grants one-time
/// access. The first tap shows a system confirmation; once the user allows
/// access, later taps grant access right away. On platforms other than iOS and
/// Android, the widget renders nothing and reports no results. In iPhone and
/// iPad apps on Apple Vision Pro, the system button does not respond to taps;
/// with visionOS 26.1 or later, the widget renders nothing there either. See
/// [checkAvailability].
///
/// ## Android 7 to 16
///
/// Where the system location button is not available, on Android 7 through 16
/// and on devices that lack it, the widget shows a fallback button of the same
/// size instead. By default, the fallback button resembles the system button
/// and takes its colors from [style] or from the ambient theme;
/// [fallbackBuilder] replaces it.
///
/// The fallback button requires the app to declare both
/// `ACCESS_FINE_LOCATION` and `ACCESS_COARSE_LOCATION`; otherwise a tap reports
/// a `PlatformException` with the code `missingPermission` to
/// [FlutterError.onError] instead of a result.
///
/// A tap on the fallback button asks for access with the permission dialog of
/// the system, unless precise access was granted before, or approximate access
/// was granted while
/// [OneTapLocationAvailability.isPreciseLocationRestrictedToSystemButton] is
/// true. Access granted in the dialog lasts as long as the user chooses there.
/// On Android 11 and later, the user can also choose to allow access only this
/// time, which Android revokes some time after the app leaves the foreground.
/// When the user allows only approximate location, the position is reported
/// with [OneTapPosition.isPrecise] set to false.
///
/// ## Size
///
/// On iOS, the widget takes the size that the system requires for the label,
/// the icon and the font size. The system ignores taps on a smaller button, so
/// the parent must allow at least that size in both directions.
///
/// On Android, the widget fills the width that its parent allows and is 48
/// logical pixels tall, unless the parent requires another size. The system
/// draws the label inside that area and cuts it off when the area is too
/// narrow, so leave room for the label in every language the app supports.
/// Without a label, the button is a 48 by 48 square unless the parent requires
/// a larger size. The system requires at least 48 logical pixels in each
/// direction and at most 136 in height. The fallback button has the same size.
///
/// ## Visibility
///
/// The system accepts a tap only while the button is fully visible. On iOS,
/// Flutter clips, fades and covers the button like any other widget, and the
/// system ignores taps while it does.
///
/// On Android, the system draws the button above all Flutter content. The
/// widget hides it while its route is not the current route or is animating,
/// while an ancestor clips it, lowers its opacity, scales it, rotates it or
/// applies an image filter to it, while it lies under the system bars or the
/// keyboard, and while content that keeps pointer events from reaching it, such
/// as a dialog, an open drawer, a bottom sheet or a menu, covers it. Once
/// hidden, the button reappears after it has stayed fully visible for a moment,
/// which lets standard dialogs, menus and sheets finish their closing
/// transitions. Covering content is found by hit testing points across the
/// button, so content that lets pointer events through, such as a tooltip, or
/// that is narrower than 48 logical pixels can go unnoticed; keep such content
/// away from the button. Shader masks and color filters of ancestors, such as a
/// list that fades at its edges, neither apply to the system button nor hide
/// it. When the font size or the display size changes, the widget replaces the
/// system button, which is missing for a moment; a change of the display size
/// also ends a request in progress without a result.
///
/// The fallback button on Android is an ordinary widget, which Flutter clips,
/// fades and covers like any other.
///
/// ## Testing
///
/// Tests that run on the host, such as widget tests, do not run the platform
/// code of the plugin, so there the widget shows nothing that can be tapped.
/// Install a [FakeOneTapLocation] from `package:one_tap_location/testing.dart`
/// to show a button that tests can find, tap and compare with golden files, and
/// to answer its taps.
class OneTapLocationButton extends StatefulWidget {
  /// Creates a location button.
  const OneTapLocationButton({
    super.key,
    required this.onResult,
    this.controller,
    this.style = const OneTapLocationButtonStyle(),
    this.fallbackBuilder,
  });

  /// Determines which button this widget shows on the device that the app runs
  /// on, and whether the app can obtain precise location only through the
  /// system location button.
  ///
  /// The button type is:
  ///
  ///  * [OneTapLocationButtonType.system] on iOS, and on Android 17 and later
  ///    where the system provides the location button.
  ///  * [OneTapLocationButtonType.fallback] on Android 7 to 16, and on devices
  ///    with a later version of Android whose system does not provide the
  ///    location button.
  ///  * [OneTapLocationButtonType.none] on the web, on other platforms, and in
  ///    iPhone and iPad apps running on Apple Vision Pro with visionOS 26.1 or
  ///    later, where the system button does not respond to taps. Earlier
  ///    versions of visionOS, and apps built with Xcode earlier than 26.1,
  ///    cannot detect this, so there the button type is
  ///    [OneTapLocationButtonType.system]; apps can turn off their availability
  ///    on Apple Vision Pro in App Store Connect.
  ///
  /// The availability does not change while the app runs. On iOS and Android,
  /// the device is checked once, and buttons use the same check to decide
  /// which button to show. If the check fails, for example because the plugin
  /// is not registered with the Flutter engine, the future completes with the
  /// error, and the next call checks again.
  ///
  /// The availability describes the device, not whether the button can be
  /// shown. Where the device provides the system location button, the button
  /// type is [OneTapLocationButtonType.system] even when the app does not
  /// declare `ACCESS_FINE_LOCATION`, or when the system fails to open the
  /// button; the button then reports the error to [FlutterError.onError]
  /// instead of showing.
  ///
  /// In tests that run on the host, such as widget tests, the check cannot
  /// reach the platform code on iOS and Android: it fails with a
  /// [MissingPluginException], or never completes when awaited in a widget
  /// test. Install a [FakeOneTapLocation] to provide the availability.
  static Future<OneTapLocationAvailability> checkAvailability() {
    return loadAvailability();
  }

  /// Called with the outcome of a tap.
  final ValueChanged<OneTapLocationResult> onResult;

  /// Receives the state and the diagnostics of the button.
  final OneTapLocationController? controller;

  /// The appearance of the button.
  final OneTapLocationButtonStyle style;

  /// Builds the button shown on Android where the system location button is
  /// not available.
  ///
  /// The built widget is given the size of the system button. When null, a
  /// button that resembles the system button is shown, styled by [style].
  ///
  /// Not used on iOS.
  final OneTapLocationFallbackBuilder? fallbackBuilder;

  @override
  State<OneTapLocationButton> createState() => _OneTapLocationButtonState();
}

class _OneTapLocationButtonState extends State<OneTapLocationButton> {
  /// Stands in for the platform while a fake is installed in a test.
  final PlatformOverride? _platformOverride = platformOverride;

  /// The device that the override describes, read when the button is created.
  ({OneTapLocationButtonType buttonType, Size iosButtonSize})? _standIn;

  MethodChannel? _viewChannel;
  Map<String, Object?>? _nativeStyle;
  bool _isLocating = false;

  /// The request started by a tap on a button that the plugin draws.
  LocationRequest? _request;

  // iOS.
  OneTapLocationButtonType? _iosButtonType;
  Size? _iosButtonSize;
  int _measureGeneration = 0;
  late final Map<String, Object?> _iosCreationStyle = encodeIOSStyle(
    widget.style,
  );

  // Android.
  AndroidEmbedding? _androidEmbedding;
  ModalRoute<Object?>? _route;
  final List<ScrollPosition> _scrollPositions = <ScrollPosition>[];
  bool _isFullyVisible = false;
  bool _isShown = false;
  Timer? _showTimer;
  bool _isSystemButtonUnavailable = false;

  bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this, isLocating: false);
    final PlatformOverride? override = _platformOverride;
    if (override != null) {
      _standIn = (
        buttonType: override.availability.buttonType,
        iosButtonSize: override.iosButtonSize,
      );
    } else if (_isIOS) {
      _iosButtonType = knownPlatformAvailability?.buttonType;
      _iosButtonSize = knownIOSButtonSize(widget.style);
      if (_iosButtonType == null) {
        unawaited(_loadIOSButtonType());
      } else if (_iosButtonType == OneTapLocationButtonType.system &&
          _iosButtonSize == null) {
        unawaited(_measure());
      }
    } else if (_isAndroid) {
      _androidEmbedding = knownAndroidEmbedding;
      if (_androidEmbedding == null) {
        unawaited(_loadAndroidEmbedding());
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isAndroid && _platformOverride == null) {
      _updateRoute(ModalRoute.of(context));
      _updateScrollPositions();
    }
  }

  @override
  void didUpdateWidget(OneTapLocationButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this, isLocating: _isLocating);
    }
    if (_platformOverride != null) {
      return;
    }
    _sendStyle();
    if (_iosButtonType == OneTapLocationButtonType.system &&
        iosButtonContent(widget.style) != iosButtonContent(oldWidget.style)) {
      final Size? knownSize = knownIOSButtonSize(widget.style);
      if (knownSize == null) {
        unawaited(_measure());
      } else {
        // A measurement of an earlier style that is still in progress no
        // longer applies.
        _measureGeneration += 1;
        _iosButtonSize = knownSize;
      }
    }
  }

  @override
  void activate() {
    super.activate();
    widget.controller?._attach(this, isLocating: _isLocating);
  }

  @override
  void deactivate() {
    widget.controller?._detach(this);
    super.deactivate();
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    _removeRouteListeners();
    _removeScrollListeners();
    _viewChannel?.setMethodCallHandler(null);
    _request?.cancel();
    super.dispose();
  }

  Future<void> _loadIOSButtonType() async {
    final OneTapLocationAvailability availability;
    try {
      availability = await loadPlatformAvailability();
    } catch (exception, stack) {
      reportError(
        exception,
        stack,
        'while checking for the system location button',
      );
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() => _iosButtonType = availability.buttonType);
    if (availability.buttonType == OneTapLocationButtonType.system &&
        _iosButtonSize == null) {
      await _measure();
    }
  }

  Future<void> _measure() async {
    final int generation = ++_measureGeneration;
    final Size size;
    try {
      size = await measureIOSButton(widget.style);
    } catch (exception, stack) {
      reportError(
        exception,
        stack,
        'while measuring the system location button',
      );
      return;
    }
    if (mounted && generation == _measureGeneration && size != _iosButtonSize) {
      setState(() => _iosButtonSize = size);
    }
  }

  Future<void> _loadAndroidEmbedding() async {
    final AndroidEmbedding embedding;
    try {
      embedding = await determineAndroidEmbedding();
    } catch (exception, stack) {
      reportError(
        exception,
        stack,
        'while checking for the system location button',
      );
      return;
    }
    if (mounted) {
      setState(() => _androidEmbedding = embedding);
    }
  }

  void _handlePressed() {
    // A tap can arrive before the button is rebuilt without its callback.
    if (_request != null) {
      return;
    }
    final LocationRequest request =
        _platformOverride?.createRequest() ?? FallbackLocationRequest();
    setState(() => _request = request);
    request.start(_RequestListener(this));
  }

  void _handleRequestDone() {
    setState(() => _request = null);
    _setLocating(false);
  }

  void _setLocating(bool value) {
    _isLocating = value;
    widget.controller?._updateLocating(this, value);
  }

  void _updateRoute(ModalRoute<Object?>? route) {
    if (route != _route) {
      _removeRouteListeners();
      _route = route;
      route?.animation?.addStatusListener(_handleRouteAnimationStatus);
      route?.secondaryAnimation?.addStatusListener(_handleRouteAnimationStatus);
    }
    _updateShown();
  }

  void _removeRouteListeners() {
    _route?.animation?.removeStatusListener(_handleRouteAnimationStatus);
    _route?.secondaryAnimation?.removeStatusListener(
      _handleRouteAnimationStatus,
    );
  }

  void _handleRouteAnimationStatus(AnimationStatus status) {
    _updateShown();
  }

  void _updateScrollPositions() {
    final List<ScrollPosition> positions = <ScrollPosition>[
      for (
        ScrollableState? scrollable = Scrollable.maybeOf(context);
        scrollable != null;
        scrollable = Scrollable.maybeOf(scrollable.context)
      )
        scrollable.position,
    ];
    if (listEquals(positions, _scrollPositions)) {
      return;
    }
    _removeScrollListeners();
    _scrollPositions.addAll(positions);
    for (final ScrollPosition position in positions) {
      position.isScrollingNotifier.addListener(_handleScrollingChanged);
    }
  }

  void _removeScrollListeners() {
    for (final ScrollPosition position in _scrollPositions) {
      position.isScrollingNotifier.removeListener(_handleScrollingChanged);
    }
    _scrollPositions.clear();
  }

  // Content ignores pointer events while it scrolls, which keeps the button
  // from finding out whether content covers it. Scrolling can end without a
  // new frame, so one is requested to check the button again.
  void _handleScrollingChanged() {
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _handleVisibilityChanged(bool isFullyVisible) {
    _isFullyVisible = isFullyVisible;
    _updateShown();
  }

  bool get _isRouteSettled {
    final ModalRoute<Object?>? route = _route;
    return route == null ||
        route.isCurrent &&
            (route.animation?.isCompleted ?? true) &&
            (route.secondaryAnimation?.isDismissed ?? true);
  }

  void _updateShown() {
    if (!_isFullyVisible || !_isRouteSettled) {
      _showTimer?.cancel();
      _showTimer = null;
      _setShown(false);
    } else if (!_isShown) {
      _showTimer ??= Timer(_showDelay, () {
        _showTimer = null;
        _setShown(true);
      });
    }
  }

  void _setShown(bool isShown) {
    if (isShown != _isShown) {
      _isShown = isShown;
      _invokeView('setVisible', isShown);
    }
  }

  void _sendStyle() {
    // A view that is still being created receives the style once it exists.
    if (_viewChannel == null) {
      return;
    }
    final Map<String, Object?> style = _isIOS
        ? encodeIOSStyle(widget.style)
        : encodeAndroidStyle(widget.style);
    if (!mapEquals(style, _nativeStyle)) {
      _nativeStyle = style;
      _invokeView('setStyle', style);
    }
  }

  void _invokeView(String method, Object? arguments) {
    final MethodChannel? channel = _viewChannel;
    if (channel == null) {
      return;
    }
    unawaited(
      channel
          .invokeMethod<void>(method, arguments)
          // The native view is disposed asynchronously after the widget.
          .catchError(
            (Object error) {},
            test: (Object error) => error is MissingPluginException,
          ),
    );
  }

  void _handlePlatformViewCreated(int id) {
    final MethodChannel? previousChannel = _viewChannel;
    if (previousChannel != null) {
      // The previous system button was replaced, together with any request it
      // had in progress.
      previousChannel.setMethodCallHandler(null);
      _setLocating(false);
    }
    _viewChannel = MethodChannel('$_viewType/$id')
      ..setMethodCallHandler(_handleViewCall);
    if (_isIOS) {
      _nativeStyle = _iosCreationStyle;
    }
    _sendStyle();
    if (_isAndroid && _isShown) {
      _invokeView('setVisible', true);
    }
  }

  Future<void> _handleViewCall(MethodCall call) async {
    try {
      _dispatchViewCall(call);
    } on MissingPluginException {
      rethrow;
    } catch (exception, stack) {
      reportError(
        exception,
        stack,
        'while handling ${call.method} from the system location button',
      );
    }
  }

  void _dispatchViewCall(MethodCall call) {
    final Map<Object?, Object?>? arguments =
        call.arguments as Map<Object?, Object?>?;
    switch (call.method) {
      case 'onLocating':
        _setLocating(true);
      case 'onResult':
        _setLocating(false);
        widget.onResult(decodeResult(arguments!));
      case 'onDiagnostic':
        widget.controller?._addDiagnostic(decodeDiagnostic(arguments!));
      case 'onUnavailable':
        // Removing the system button cancels a request in progress.
        _setLocating(false);
        setState(() => _isSystemButtonUnavailable = true);
        throw FlutterError(
          'The system location button could not be shown.\n'
          '${arguments!['message']}',
        );
      default:
        throw MissingPluginException(
          'Method ${call.method} is not implemented.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    assert(
      widget.style.backgroundColor == null ||
          widget.style.backgroundColor!.a == 1.0,
      'OneTapLocationButtonStyle.backgroundColor must be fully opaque.',
    );
    final ({OneTapLocationButtonType buttonType, Size iosButtonSize})? standIn =
        _standIn;
    if (standIn != null) {
      return _buildStandIn(standIn);
    }
    if (_isIOS) {
      return _buildIOSButton();
    }
    if (_isAndroid) {
      return _buildAndroidButton();
    }
    return const SizedBox.shrink();
  }

  Widget _buildIOSButton() {
    final Size? size = _iosButtonSize;
    if (_iosButtonType != OneTapLocationButtonType.system || size == null) {
      return const SizedBox.shrink();
    }
    // The view is restyled in place, so that a change of the style keeps a
    // request in progress.
    return _IOSButtonBox(
      requiredSize: size,
      child: UiKitView(
        viewType: _viewType,
        creationParams: _iosCreationStyle,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _handlePlatformViewCreated,
      ),
    );
  }

  bool get _fillsWidth =>
      widget.style.androidLabel != AndroidLocationButtonLabel.none;

  VoidCallback? get _onPressed => _request == null ? _handlePressed : null;

  Widget _buildStandIn(
    ({OneTapLocationButtonType buttonType, Size iosButtonSize}) standIn,
  ) {
    final OneTapLocationButtonStyle style = widget.style;
    return switch (standIn.buttonType) {
      OneTapLocationButtonType.none => const SizedBox.shrink(),
      OneTapLocationButtonType.fallback => _AndroidButtonBox(
        fillsWidth: _fillsWidth,
        child: _buildFallbackButton(),
      ),
      // Only the properties that the system button on iOS uses apply. Like the
      // system button, the stand-in fills its area, has square corners by
      // default and keeps its shape while pressed.
      OneTapLocationButtonType.system when _isIOS => _IOSButtonBox(
        requiredSize: standIn.iosButtonSize,
        child: FallbackLocationButton(
          style: OneTapLocationButtonStyle(
            backgroundColor: style.backgroundColor,
            foregroundColor: style.foregroundColor,
            cornerRadius: style.cornerRadius ?? 0,
            androidPressedCornerRadius: style.cornerRadius ?? 0,
          ),
          onPressed: _onPressed,
          label: englishIOSLabel(style.iosLabel),
          showsLabel: style.iosLabel != IOSLocationButtonLabel.none,
          showsIcon: style.iosIcon != IOSLocationButtonIcon.none,
          shapeInset: 0,
        ),
      ),
      OneTapLocationButtonType.system => _AndroidButtonBox(
        fillsWidth: _fillsWidth,
        child: FallbackLocationButton(
          style: style,
          onPressed: _onPressed,
          label: englishAndroidLabel(style.androidLabel),
        ),
      ),
    };
  }

  Widget _buildAndroidButton() {
    return _AndroidButtonBox(
      fillsWidth: _fillsWidth,
      child: switch (_androidEmbedding) {
        // The space stays reserved while the device is checked for the system
        // button.
        null => null,
        AndroidEmbedding.fallback => _buildFallbackButton(),
        _ when _isSystemButtonUnavailable => null,
        final AndroidEmbedding embedding => VisibilityProbe(
          onVisibilityChanged: _handleVisibilityChanged,
          child: _buildAndroidView(embedding),
        ),
      },
    );
  }

  Widget _buildFallbackButton() {
    final OneTapLocationFallbackBuilder? fallbackBuilder =
        widget.fallbackBuilder;
    if (fallbackBuilder != null) {
      return fallbackBuilder(context, _onPressed);
    }
    return FallbackLocationButton(style: widget.style, onPressed: _onPressed);
  }

  Widget _buildAndroidView(AndroidEmbedding embedding) {
    return PlatformViewLink(
      // The Flutter embedding on Android draws a native view at the pixel
      // ratio that the view was created with, so the system button is created
      // again when the pixel ratio changes.
      key: ValueKey<double?>(MediaQuery.maybeDevicePixelRatioOf(context)),
      viewType: _viewType,
      surfaceFactory:
          (BuildContext context, PlatformViewController controller) {
            return AndroidViewSurface(
              controller: controller as AndroidViewController,
              // The system window receives touches directly, so no gesture
              // needs to be forwarded to the view.
              gestureRecognizers:
                  const <Factory<OneSequenceGestureRecognizer>>{},
              hitTestBehavior: PlatformViewHitTestBehavior.opaque,
            );
          },
      onCreatePlatformView: (PlatformViewCreationParams params) {
        final Map<String, Object?> style = encodeAndroidStyle(widget.style);
        _nativeStyle = style;
        final AndroidViewController controller =
            embedding == AndroidEmbedding.hybridCompositionPlusPlus
            ? PlatformViewsService.initHybridAndroidView(
                id: params.id,
                viewType: _viewType,
                layoutDirection: TextDirection.ltr,
                creationParams: style,
                creationParamsCodec: const StandardMessageCodec(),
                onFocus: () => params.onFocusChanged(true),
              )
            : PlatformViewsService.initExpensiveAndroidView(
                id: params.id,
                viewType: _viewType,
                layoutDirection: TextDirection.ltr,
                creationParams: style,
                creationParamsCodec: const StandardMessageCodec(),
                onFocus: () => params.onFocusChanged(true),
              );
        controller
          ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
          ..addOnPlatformViewCreatedListener(_handlePlatformViewCreated);
        unawaited(controller.create());
        return controller;
      },
    );
  }
}

/// Forwards the progress of a request to the button that started it.
class _RequestListener implements LocationRequestListener {
  _RequestListener(this._state);

  final _OneTapLocationButtonState _state;

  @override
  void onLocating() {
    _state._setLocating(true);
  }

  @override
  void onResult(OneTapLocationResult result) {
    _state._setLocating(false);
    try {
      _state.widget.onResult(result);
    } catch (exception, stack) {
      reportError(exception, stack, 'while handling a location result');
    }
  }

  @override
  void onDiagnostic(OneTapLocationDiagnostic diagnostic) {
    _state.widget.controller?._addDiagnostic(diagnostic);
  }

  @override
  void onDone() {
    _state._handleRequestDone();
  }
}

/// Gives the button its size on Android: the width of the parent, or a square
/// without a label, at the smallest height the system button accepts.
class _AndroidButtonBox extends SingleChildRenderObjectWidget {
  const _AndroidButtonBox({required this.fillsWidth, super.child});

  final bool fillsWidth;

  @override
  _RenderAndroidButtonBox createRenderObject(BuildContext context) {
    return _RenderAndroidButtonBox(fillsWidth);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderAndroidButtonBox renderObject,
  ) {
    renderObject.fillsWidth = fillsWidth;
  }
}

class _RenderAndroidButtonBox extends RenderProxyBox {
  _RenderAndroidButtonBox(this._fillsWidth);

  bool get fillsWidth => _fillsWidth;
  bool _fillsWidth;
  set fillsWidth(bool value) {
    if (value != _fillsWidth) {
      _fillsWidth = value;
      markNeedsLayout();
    }
  }

  @override
  double computeMinIntrinsicWidth(double height) => _androidMinExtent;

  @override
  double computeMaxIntrinsicWidth(double height) => _androidMinExtent;

  @override
  double computeMinIntrinsicHeight(double width) => _androidMinExtent;

  @override
  double computeMaxIntrinsicHeight(double width) => _androidMinExtent;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    return _sizeFor(constraints);
  }

  // The system button has no baseline. The fallback button reports none either,
  // so the button does not move in a baseline-aligned parent when the device
  // turns out not to have the system button.
  @override
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    return null;
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) => null;

  @override
  void performLayout() {
    assert(
      !fillsWidth || constraints.hasBoundedWidth,
      'OneTapLocationButton was given an unbounded width. On Android, the '
      'button fills the width of its parent. Place it in a parent with a '
      'bounded width, such as a SizedBox or an Expanded, or use '
      'AndroidLocationButtonLabel.none.',
    );
    size = _sizeFor(constraints);
    assert(
      size.width >= _androidMinExtent &&
          size.height >= _androidMinExtent &&
          size.height <= _androidMaxHeight,
      'OneTapLocationButton was given the size $size. On Android, the system '
      'requires at least $_androidMinExtent logical pixels in each direction '
      'and at most $_androidMaxHeight in height.',
    );
    child?.layout(BoxConstraints.tight(size));
  }

  Size _sizeFor(BoxConstraints constraints) {
    final double width = fillsWidth && constraints.hasBoundedWidth
        ? constraints.maxWidth
        : _androidMinExtent;
    return constraints.constrain(Size(width, _androidMinExtent));
  }
}

/// Gives the button on iOS the size that the system requires.
class _IOSButtonBox extends SingleChildRenderObjectWidget {
  const _IOSButtonBox({required this.requiredSize, super.child});

  final Size requiredSize;

  @override
  _RenderIOSButtonBox createRenderObject(BuildContext context) {
    return _RenderIOSButtonBox(requiredSize);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderIOSButtonBox renderObject,
  ) {
    renderObject.requiredSize = requiredSize;
  }
}

class _RenderIOSButtonBox extends RenderProxyBox {
  _RenderIOSButtonBox(this._requiredSize);

  Size get requiredSize => _requiredSize;
  Size _requiredSize;
  set requiredSize(Size value) {
    if (value != _requiredSize) {
      _requiredSize = value;
      markNeedsLayout();
    }
  }

  @override
  double computeMinIntrinsicWidth(double height) => requiredSize.width;

  @override
  double computeMaxIntrinsicWidth(double height) => requiredSize.width;

  @override
  double computeMinIntrinsicHeight(double width) => requiredSize.height;

  @override
  double computeMaxIntrinsicHeight(double width) => requiredSize.height;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    return constraints.constrain(requiredSize);
  }

  // CLLocationButton has no baseline. The stand-in of a fake reports none
  // either, so a baseline-aligned parent lays out the same in tests as on a
  // device.
  @override
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    return null;
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) => null;

  @override
  void performLayout() {
    size = constraints.constrain(requiredSize);
    child?.layout(BoxConstraints.tight(size));
    assert(
      size.width >= requiredSize.width && size.height >= requiredSize.height,
      'OneTapLocationButton was given the size $size. On iOS, the system '
      'requires at least $requiredSize for the label, the icon and the font '
      'size of the button, and it ignores taps on a smaller button.',
    );
  }
}
