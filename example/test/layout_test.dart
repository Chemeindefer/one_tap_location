// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_tap_location/one_tap_location.dart';
import 'package:one_tap_location/testing.dart';
import 'package:one_tap_location_example/main.dart';
import 'package:one_tap_location_example/src/decorations.dart';
import 'package:one_tap_location_example/src/formatting.dart';
import 'package:one_tap_location_example/src/panels.dart';
import 'package:one_tap_location_example/src/theme.dart';

import 'ios_button_size.dart';

/// Roboto as the Flutter SDK downloads it for Material tests.
final String? _robotoDirectory = switch (Platform.environment['FLUTTER_ROOT']) {
  final String flutterRoot => '$flutterRoot/bin/cache/artifacts/material_fonts',
  null => null,
};

/// A monospaced font with the character width of Android's monospace font,
/// available on macOS.
const String _monospaceFontFile =
    '/System/Library/Fonts/Supplemental/Courier New.ttf';

/// Whether text in these tests has the metrics it has on an Android device.
/// Without these fonts, the tests fall back to the square test font and skip
/// the checks that depend on exact widths.
final bool _hasDeviceFonts =
    _robotoDirectory != null &&
    Directory(_robotoDirectory!).existsSync() &&
    File(_monospaceFontFile).existsSync();

Future<void> _loadFont(String family, List<String> files) async {
  final FontLoader loader = FontLoader(family);
  for (final String file in files) {
    loader.addFont(File(file).readAsBytes().then(ByteData.sublistView));
  }
  await loader.load();
}

void main() {
  late FakeOneTapLocation location;

  setUpAll(() async {
    if (!_hasDeviceFonts) {
      return;
    }
    await _loadFont('Roboto', <String>[
      for (final String style in <String>['Regular', 'Medium', 'Bold'])
        '$_robotoDirectory/Roboto-$style.ttf',
    ]);
    await _loadFont('monospace', <String>[_monospaceFontFile]);
  });

  setUp(() {
    location = FakeOneTapLocation.install()
      ..iosButtonSize = shareCurrentLocationButtonSize;
    addTearDown(location.uninstall);
  });

  Future<void> startApp(
    WidgetTester tester, {
    required Size screen,
    required double textScale,
    bool boldText = false,
  }) async {
    tester.view
      ..physicalSize = screen
      ..devicePixelRatio = 1;
    tester.platformDispatcher
      ..textScaleFactorTestValue = textScale
      ..accessibilityFeaturesTestValue = FakeAccessibilityFeatures(
        boldText: boldText,
      );
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(
      ExampleApp(availability: await OneTapLocationButton.checkAvailability()),
    );
    await tester.pump();
  }

  Future<FakeLocationRequest> tapButton(WidgetTester tester) async {
    await tester.tap(find.byType(OneTapLocationButton));
    await tester.pump();
    return location.requests.last;
  }

  /// The footer of the position card, whose top edge is the divider.
  Finder positionCardFooter() {
    return find
        .ancestor(
          of: find.text('OneTapLocationGranted'),
          matching: find.byType(DecoratedBox),
        )
        .first;
  }

  RenderParagraph paragraphOf(WidgetTester tester, String text) {
    return tester.renderObject<RenderParagraph>(find.text(text));
  }

  // Checks the spacing of the position card footer against the design, which
  // the tap target of the copy button can stretch.
  void expectFooterSpacing(WidgetTester tester) {
    const double divider = 1;
    const double tapTarget = 48;
    final Rect footer = tester.getRect(positionCardFooter());
    final Rect label = tester.getRect(find.text('OneTapLocationGranted'));
    final Rect buttonText = tester.getRect(find.text('Copy result'));
    final Rect button = tester.getRect(find.byType(TextButton));
    expect(button.height, greaterThanOrEqualTo(tapTarget));
    if (label.bottom <= buttonText.top) {
      expect(label.top - footer.top, moreOrLessEquals(divider + 12));
      expect(buttonText.top - label.bottom, moreOrLessEquals(4));
      expect(buttonText.top, moreOrLessEquals(button.top));
    } else {
      expect(buttonText.top - footer.top, moreOrLessEquals(divider + 12));
      expect(label.center.dy, moreOrLessEquals(buttonText.center.dy));
    }
    expect(
      footer.bottom - buttonText.bottom,
      moreOrLessEquals(
        math.max(20, button.top + tapTarget - buttonText.bottom),
      ),
    );
  }

  Finder tag(String label) {
    return find.ancestor(of: find.text(label), matching: find.byType(Tag));
  }

  void expectApart(WidgetTester tester, Finder first, Finder second) {
    for (final Element a in first.evaluate()) {
      for (final Element b in second.evaluate()) {
        final Rect rectA = tester.getRect(
          find.byElementPredicate((Element element) => element == a),
        );
        final Rect rectB = tester.getRect(
          find.byElementPredicate((Element element) => element == b),
        );
        expect(
          rectA.overlaps(rectB),
          isFalse,
          reason: '${a.widget} at $rectA overlaps ${b.widget} at $rectB',
        );
      }
    }
  }

  // Checks that no word of the texts breaks across lines. Only Android text
  // has device metrics in these tests.
  void expectWholeWords(List<String> texts) {
    if (defaultTargetPlatform != TargetPlatform.android || !_hasDeviceFonts) {
      return;
    }
    for (final String text in texts) {
      final Iterable<Element> elements = find.text(text).evaluate();
      expect(elements, isNotEmpty, reason: '"$text" is not shown');
      for (final Element element in elements) {
        final RenderParagraph paragraph =
            element.renderObject! as RenderParagraph;
        expect(
          paragraph.size.width,
          greaterThanOrEqualTo(
            paragraph.getMinIntrinsicWidth(double.infinity) - 0.01,
          ),
          reason: '"$text" is ${paragraph.size.width} wide',
        );
      }
    }
  }

  // Checks that [part] of the text of [paragraph] is laid out on one line.
  void expectOnOneLine(RenderParagraph paragraph, String part) {
    final String text = paragraph.text.toPlainText();
    final int start = text.indexOf(part);
    expect(start, isNot(-1), reason: '"$part" is not in "$text"');
    final List<TextBox> boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: start, extentOffset: start + part.length),
    );
    expect(
      boxes.map((TextBox box) => box.top).toSet(),
      hasLength(1),
      reason: '"$part" breaks across lines in "$text"',
    );
  }

  // The first paragraph whose text contains [part].
  RenderParagraph paragraphContaining(WidgetTester tester, String part) {
    return tester.renderObject<RenderParagraph>(
      find.textContaining(part).first,
    );
  }

  // Checks that each text, such as a name from the plugin API, stays on one
  // line, spaces included.
  void expectSingleLine(List<String> texts) {
    for (final String text in texts) {
      final Iterable<Element> elements = find.text(text).evaluate();
      expect(elements, isNotEmpty, reason: '"$text" is not shown');
      for (final Element element in elements) {
        final RenderParagraph paragraph =
            element.renderObject! as RenderParagraph;
        expect(
          paragraph.size.width,
          greaterThanOrEqualTo(
            paragraph.getMaxIntrinsicWidth(double.infinity) - 0.01,
          ),
          reason: '"$text" is ${paragraph.size.width} wide',
        );
      }
    }
  }

  Future<void> expectEveryStateLaidOut(
    WidgetTester tester, {
    required bool systemButton,
  }) async {
    final String buttonType = systemButton ? 'system' : 'fallback';
    expect(tester.takeException(), isNull);
    expectApart(
      tester,
      tag('button: $buttonType'),
      find.text('One Tap Example'),
    );
    expectApart(
      tester,
      tag('button: $buttonType'),
      find.textContaining('one_tap_location '),
    );
    expectSingleLine(<String>['button: $buttonType']);

    final FakeLocationRequest locating = await tapButton(tester);
    locating.grantAccess();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expectApart(tester, tag('isLocating: true'), find.byType(ProgressSpinner));
    expectApart(
      tester,
      tag('isLocating: true'),
      find.text('Getting location…'),
    );
    expectWholeWords(<String>['Getting location…']);
    expectSingleLine(<String>['isLocating: true']);

    locating.complete(
      OneTapLocationGranted(
        OneTapPosition(
          latitude: -33.868819,
          longitude: -151.209295,
          horizontalAccuracy: 2000,
          timestamp: DateTime.now(),
          isPrecise: false,
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expectApart(tester, tag('APPROXIMATE'), find.text('Location received'));
    expectApart(
      tester,
      find.text('OneTapLocationGranted'),
      find.byType(TextButton),
    );
    expectApart(
      tester,
      find.byType(AccuracyRing),
      find.text('— (null when approximate)'),
    );
    expectApart(
      tester,
      find.byType(AccuracyRing),
      find.text('horizontalAccuracy'),
    );
    expectWholeWords(<String>[
      'Location received',
      'horizontalAccuracy',
      'timestamp',
      '±2000.0\u00A0m',
      '— (null when approximate)',
      'false',
      '33.868819° S\n151.209295° W',
    ]);
    expectFooterSpacing(tester);
    // The type label shares a row with the copy button only at its full size.
    final Rect typeLabel = tester.getRect(find.text('OneTapLocationGranted'));
    if (typeLabel.bottom > tester.getRect(find.byType(TextButton)).top) {
      expect(
        typeLabel.width,
        moreOrLessEquals(
          paragraphOf(tester, 'OneTapLocationGranted').size.width,
        ),
      );
    }
    expectSingleLine(<String>[
      'APPROXIMATE',
      'horizontalAccuracy',
      'altitude',
      'timestamp',
      'isPrecise',
      'OneTapLocationGranted',
    ]);

    (await tapButton(tester)).complete(const OneTapLocationDenied());
    await tester.pump();
    expect(tester.takeException(), isNull);
    expectApart(tester, tag('OneTapLocationDenied'), find.byType(Icon));
    expectApart(
      tester,
      tag('OneTapLocationDenied'),
      find.text('Access declined'),
    );
    expectSingleLine(<String>['OneTapLocationDenied']);

    (await tapButton(tester)).complete(
      const OneTapLocationFailed(
        OneTapLocationException(
          OneTapLocationErrorCode.locationServicesDisabled,
          'The provider reported that location services are disabled',
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expectApart(tester, tag('locationServicesDisabled'), find.byType(Icon));
    expectApart(
      tester,
      tag('locationServicesDisabled'),
      find.text('Couldn’t get a location'),
    );
    expectSingleLine(<String>['locationServicesDisabled']);

    (await tapButton(tester)).dismiss();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Tap without authorization'), findsOneWidget);
    expectSingleLine(<String>['diagnostics: tapWithoutAuthorization']);
  }

  const List<(String, TargetPlatform, bool)> devices =
      <(String, TargetPlatform, bool)>[
        ('iOS', TargetPlatform.iOS, true),
        ('Android 17', TargetPlatform.android, true),
        ('Android 16', TargetPlatform.android, false),
      ];

  for (final (String device, TargetPlatform platform, bool systemButton)
      in devices) {
    for (final Size screen in const <Size>[
      Size(320, 568),
      Size(360, 640),
      Size(412, 915),
      Size(667, 375),
    ]) {
      for (final double textScale in const <double>[1, 2]) {
        testWidgets('lays out every state on $device at '
            '${screen.width.round()}x${screen.height.round()} with text scale '
            '$textScale', (WidgetTester tester) async {
          location.hasAndroidSystemButton = systemButton;
          await startApp(tester, screen: screen, textScale: textScale);
          await expectEveryStateLaidOut(tester, systemButton: systemButton);
        }, variant: TargetPlatformVariant.only(platform));
      }
    }

    for (final Size screen in const <Size>[Size(360, 640), Size(412, 915)]) {
      testWidgets('lays out every state on $device at '
          '${screen.width.round()}x${screen.height.round()} with bold text', (
        WidgetTester tester,
      ) async {
        location.hasAndroidSystemButton = systemButton;
        await startApp(tester, screen: screen, textScale: 1, boldText: true);
        await expectEveryStateLaidOut(tester, systemButton: systemButton);
      }, variant: TargetPlatformVariant.only(platform));
    }
  }

  testWidgets(
    'keeps the words of the position card whole at every width',
    (WidgetTester tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(boldText: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final OneTapPosition position = OneTapPosition(
        latitude: 41.03,
        longitude: 28.98,
        horizontalAccuracy: 2000,
        timestamp: DateTime.now(),
        isPrecise: false,
      );
      // The widths cover the points where the ring and then the table give
      // way, which bold text moves.
      for (double width = 240; width <= 420; width += 2) {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildExampleTheme(Brightness.light),
            home: Scaffold(
              body: DefaultTextStyle.merge(
                style: baseTextStyle,
                child: Center(
                  child: SizedBox(
                    width: width,
                    child: PositionCard(
                      position: position,
                      note: null,
                      onCopy: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull, reason: 'width $width');
        expectWholeWords(<String>[
          'horizontalAccuracy',
          'timestamp',
          '±2000.0\u00A0m',
          '— (null when approximate)',
          'false',
        ]);
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
    skip: !_hasDeviceFonts,
  );

  for (final double width in const <double>[360, 384, 393, 402, 412]) {
    for (final double textScale in const <double>[1, 1.5]) {
      testWidgets(
        'keeps numbers with their units at a width of ${width.round()} with '
        'text scale $textScale',
        (WidgetTester tester) async {
          await startApp(
            tester,
            screen: Size(width, 915),
            textScale: textScale,
          );
          for (final (bool isPrecise, double? altitude)
              in const <(bool, double?)>[
                (true, 1609.3),
                (true, 41.2),
                (false, null),
              ]) {
            (await tapButton(tester)).complete(
              OneTapLocationGranted(
                OneTapPosition(
                  latitude: 39.7392,
                  longitude: -104.9903,
                  horizontalAccuracy: isPrecise ? 12 : 2000,
                  altitude: altitude,
                  timestamp: DateTime.now().subtract(
                    const Duration(minutes: 10, seconds: 5),
                  ),
                  isPrecise: isPrecise,
                ),
              ),
            );
            await tester.pump();

            if (altitude != null) {
              final String formattedAltitude = formatMeters(altitude);
              expectOnOneLine(
                paragraphContaining(tester, formattedAltitude),
                formattedAltitude,
              );
            }
            expectOnOneLine(
              paragraphContaining(tester, '±'),
              isPrecise ? '±12.0\u00A0m' : '±2000.0\u00A0m',
            );
            final RenderParagraph timestamp = paragraphContaining(
              tester,
              'min ago',
            );
            // The separator stays with the time, and the age with its unit.
            final String time = timestamp.text.toPlainText();
            expectOnOneLine(
              timestamp,
              time.substring(0, time.indexOf('·') + 1),
            );
            expectOnOneLine(timestamp, '10\u00A0min');
            if (!isPrecise) {
              expectOnOneLine(
                paragraphContaining(tester, 'Approximate fixes'),
                '10\u00A0minutes',
              );
            }
          }
        },
        variant: TargetPlatformVariant.only(TargetPlatform.android),
        skip: !_hasDeviceFonts,
      );
    }
  }

  testWidgets(
    'stacks the footer of the position card when it does not fit on a line',
    (WidgetTester tester) async {
      await startApp(tester, screen: const Size(412, 915), textScale: 2);
      (await tapButton(tester)).complete(
        OneTapLocationGranted(
          OneTapPosition(
            latitude: 41.03,
            longitude: 28.98,
            horizontalAccuracy: 12,
            timestamp: DateTime.now(),
            isPrecise: true,
          ),
        ),
      );
      await tester.pump();

      expectFooterSpacing(tester);
      final Rect label = tester.getRect(find.text('OneTapLocationGranted'));
      expect(
        tester.getRect(find.text('Copy result')).top,
        greaterThan(label.bottom),
      );
      // The confirmation starts where the label starts.
      await tester.tap(find.byType(TextButton));
      await tester.pump();
      expect(tester.getRect(find.text('Copied')).left, label.left);
      expect(tester.getRect(find.byType(TextButton)).left, label.left);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
    skip: !_hasDeviceFonts,
  );

  testWidgets(
    'shows the design layout of the cards on a common Android phone',
    (WidgetTester tester) async {
      await startApp(tester, screen: const Size(412, 915), textScale: 1);

      final FakeLocationRequest request = await tapButton(tester);
      request.grantAccess();
      await tester.pump();
      // The tag sits beside the spinner row instead of above it.
      expect(
        tester.getRect(tag('isLocating: true')).bottom,
        greaterThan(tester.getRect(find.byType(ProgressSpinner)).top),
      );

      request.complete(
        OneTapLocationGranted(
          OneTapPosition(
            latitude: 41.03,
            longitude: 28.98,
            horizontalAccuracy: 2000,
            timestamp: DateTime.now(),
            isPrecise: false,
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(AccuracyRing), findsOneWidget);
      expect(find.byType(Table), findsOneWidget);

      // The type label and the copy button share one row, with the label at
      // its full size and the button at the end.
      final Rect label = tester.getRect(find.text('OneTapLocationGranted'));
      final Rect buttonText = tester.getRect(find.text('Copy result'));
      expect(label.bottom, greaterThan(buttonText.top));
      expect(
        label.width,
        moreOrLessEquals(
          paragraphOf(tester, 'OneTapLocationGranted').size.width,
        ),
      );
      expect(buttonText.right, tester.getRect(positionCardFooter()).right);
      expectFooterSpacing(tester);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
    skip: !_hasDeviceFonts,
  );
}
