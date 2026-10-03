// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:one_tap_location/one_tap_location.dart';

import 'src/announcements.dart';
import 'src/panels.dart';
import 'src/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The first frame shows what depends on the button type, so nothing moves
  // when the check completes.
  OneTapLocationAvailability? availability;
  try {
    availability = await OneTapLocationButton.checkAvailability();
  } on Exception catch (exception, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: exception,
        stack: stack,
        library: 'one_tap_location example',
        context: ErrorDescription('while checking the location button'),
      ),
    );
  }
  runApp(ExampleApp(availability: availability));
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key, required this.availability});

  /// What the device offers, or null if the check failed.
  final OneTapLocationAvailability? availability;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'One Tap Example',
      theme: buildExampleTheme(Brightness.light),
      darkTheme: buildExampleTheme(Brightness.dark),
      debugShowCheckedModeBanner: false,
      home: LocationScreen(availability: availability),
    );
  }
}

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key, required this.availability});

  /// What the device offers, or null if the check failed.
  final OneTapLocationAvailability? availability;

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen>
    with Announcements<LocationScreen> {
  final OneTapLocationController _controller = OneTapLocationController();
  late final StreamSubscription<OneTapLocationDiagnostic>
  _diagnosticSubscription;
  OneTapLocationResult? _result;
  bool _isTapWithoutAuthorization = false;

  /// How many times the status was reported, repeats of the same status
  /// included.
  int _reportCount = 0;

  final GlobalKey _statusKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleProgress);
    _diagnosticSubscription = _controller.diagnostics.listen(_handleDiagnostic);
  }

  @override
  void dispose() {
    unawaited(_diagnosticSubscription.cancel());
    _controller.dispose();
    super.dispose();
  }

  /// What the content shows, in the words a screen reader announces, or null
  /// while nothing happened yet.
  String? get _status {
    if (_isTapWithoutAuthorization) {
      return 'Tap without authorization';
    }
    if (_controller.isLocating) {
      return 'Getting location…';
    }
    return switch (_result) {
      null => null,
      OneTapLocationGranted(:final OneTapPosition position) =>
        position.isPrecise
            ? 'Location received, precise'
            : 'Location received, approximate',
      OneTapLocationDenied() => 'Access declined',
      OneTapLocationFailed() => 'Couldn’t get a location',
    };
  }

  /// Applies [change] and announces the content it leads to, even when a
  /// repeated tap leads to the same content again.
  void _report(VoidCallback change) {
    setState(() {
      change();
      _reportCount++;
    });
    announce(_status!);
    // With a large font size or in landscape, the content can end below the
    // visible area. The status is always last, so scrolling to its start shows
    // all of it, or as much as fits.
    WidgetsBinding.instance.addPostFrameCallback((Duration timeStamp) {
      final BuildContext? statusContext = _statusKey.currentContext;
      // Scrolling while the user drags or flings the content would take it
      // away from them.
      if (statusContext == null ||
          Scrollable.of(statusContext).position.userScrollDirection !=
              ScrollDirection.idle) {
        return;
      }
      unawaited(
        Scrollable.ensureVisible(
          statusContext,
          duration: MediaQuery.disableAnimationsOf(statusContext)
              ? Duration.zero
              : const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        ),
      );
    });
  }

  void _handleProgress() {
    if (_controller.isLocating) {
      // A request in progress replaces what the previous tap showed.
      _report(() {
        _result = null;
        _isTapWithoutAuthorization = false;
      });
    } else {
      setState(() {});
    }
  }

  void _handleResult(OneTapLocationResult result) {
    _report(() {
      _result = result;
      _isTapWithoutAuthorization = false;
    });
  }

  void _handleDiagnostic(OneTapLocationDiagnostic diagnostic) {
    switch (diagnostic) {
      case OneTapLocationDiagnostic.tapWithoutAuthorization:
        _report(() {
          _result = null;
          _isTapWithoutAuthorization = true;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    return Scaffold(
      body: DefaultTextStyle.merge(
        style: baseTextStyle,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: EdgeInsets.only(
                    top: isIOS ? 14 : 20,
                    bottom: isIOS ? 10 : 28,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            _buildContent(),
                            StatusLiveRegion(
                              status: _status,
                              reportCount: _reportCount,
                            ),
                          ],
                        ),
                      ),
                      _buildButtonArea(isIOS: isIOS),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final OneTapLocationButtonType? buttonType =
        widget.availability?.buttonType;
    final OneTapLocationResult? result = _result;
    final bool showsIntro = result == null && !_controller.isLocating;
    final Widget top = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ExampleHeader(buttonType: buttonType),
        if (showsIntro)
          ?switch (buttonType) {
            OneTapLocationButtonType.system => const SystemButtonIntro(),
            OneTapLocationButtonType.fallback => const FallbackButtonIntro(),
            OneTapLocationButtonType.none || null => null,
          },
      ],
    );
    final Widget body;
    if (_isTapWithoutAuthorization) {
      body = const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: TapWithoutAuthorizationBanner(),
      );
    } else {
      final Widget card = switch (result) {
        _ when _controller.isLocating => const LocatingCard(),
        null => const EmptyStateCard(),
        OneTapLocationGranted(:final OneTapPosition position) => PositionCard(
          key: ObjectKey(position),
          position: position,
          note: _noteFor(position),
          onCopy: () => _copy(result),
        ),
        OneTapLocationDenied() => const DeniedCard(),
        OneTapLocationFailed(:final OneTapLocationException exception) =>
          FailedCard(exception: exception),
      };
      final bool isWaiting = result == null || _controller.isLocating;
      body = Padding(
        padding: EdgeInsets.symmetric(vertical: isWaiting ? 24 : 20),
        child: card,
      );
    }

    // The content scrolls when it does not fit, for example in landscape or
    // with a large font size, while the button stays in place below it: the
    // system button on Android is hidden while a scroll view clips it.
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                top,
                KeyedSubtree(key: _statusKey, child: body),
                // An empty last child centers the card in the space below the
                // top, while the banner stays at the bottom.
                if (!_isTapWithoutAuthorization) const SizedBox.shrink(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildButtonArea({required bool isIOS}) {
    final ExampleColors colors = ExampleColors.of(context);
    const String promptHint = 'Nothing is shared until you tap.';
    const String grantedHint =
        'Each tap grants access again — no alert after the first.';
    final String? hint = switch (_result) {
      null when !_controller.isLocating && !_isTapWithoutAuthorization =>
        promptHint,
      OneTapLocationGranted() when isIOS => grantedHint,
      _ => null,
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        OneTapLocationButton(
          controller: _controller,
          style: const OneTapLocationButtonStyle(
            iosLabel: IOSLocationButtonLabel.shareCurrentLocation,
            androidLabel: AndroidLocationButtonLabel.sharePreciseLocation,
          ),
          onResult: _handleResult,
        ),
        const SizedBox(height: 10),
        // Every hint keeps its space, so the button does not move when the
        // hint changes.
        Stack(
          alignment: Alignment.topCenter,
          children: <Widget>[
            for (final String text in <String>[
              promptHint,
              if (isIOS) grantedHint,
            ])
              Visibility(
                visible: text == hint,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: colors.secondaryText),
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// Explains the age of an approximate position, which only the fallback
  /// button on Android reports that way.
  String? _noteFor(OneTapPosition position) {
    if (position.isPrecise ||
        widget.availability?.buttonType != OneTapLocationButtonType.fallback) {
      return null;
    }
    return 'Approximate fixes can be up to 10\u00A0minutes old — check the '
        'timestamp.';
  }

  void _copy(OneTapLocationResult result) {
    unawaited(Clipboard.setData(ClipboardData(text: result.toString())));
  }
}
