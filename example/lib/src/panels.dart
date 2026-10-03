// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:one_tap_location/one_tap_location.dart';

import 'announcements.dart';
import 'decorations.dart';
import 'formatting.dart';
import 'plugin_version.dart';
import 'theme.dart';

const List<FontFeature> _tabularFigures = <FontFeature>[
  FontFeature.tabularFigures(),
];

/// The width of [text] on a single line, as a [Text] with [style] lays it out
/// here.
double _textWidth(BuildContext context, String text, TextStyle style) {
  TextStyle effectiveStyle = DefaultTextStyle.of(context).style.merge(style);
  if (MediaQuery.boldTextOf(context)) {
    effectiveStyle = effectiveStyle.merge(
      const TextStyle(fontWeight: FontWeight.bold),
    );
  }
  final TextPainter painter = TextPainter(
    text: TextSpan(text: text, style: effectiveStyle),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final double width = painter.width.ceilToDouble();
  painter.dispose();
  return width;
}

/// The app title, the plugin version and the type of button on the device.
class ExampleHeader extends StatelessWidget {
  const ExampleHeader({super.key, required this.buttonType});

  /// The type of button on the device, or null if the check failed.
  final OneTapLocationButtonType? buttonType;

  @override
  Widget build(BuildContext context) {
    final ExampleColors colors = ExampleColors.of(context);
    final OneTapLocationButtonType? buttonType = this.buttonType;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 12,
      runSpacing: 8,
      children: <Widget>[
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Semantics(
              header: true,
              headingLevel: 1,
              child: Text(
                'One Tap Example',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'one_tap_location $pluginVersion',
              style: monospaceStyle(
                context,
                fontSize: 10,
                color: colors.secondaryText,
              ),
            ),
          ],
        ),
        if (buttonType != null)
          Tag(
            label: 'button: ${buttonType.name}',
            foreground: colors.accent,
            background: colors.accentSurface,
          ),
      ],
    );
  }
}

/// A rounded label in the monospaced font.
class Tag extends StatelessWidget {
  const Tag({
    super.key,
    required this.label,
    required this.foreground,
    required this.background,
    this.horizontalPadding = 10,
    this.isEmphasized = false,
  });

  final String label;
  final Color foreground;
  final Color background;
  final double horizontalPadding;
  final bool isEmphasized;

  /// The width of the tag when its label stays on one line.
  double measureWidth(BuildContext context) {
    return _textWidth(context, label, _textStyle(context)) +
        2 * horizontalPadding;
  }

  TextStyle _textStyle(BuildContext context) {
    return monospaceStyle(
      context,
      fontSize: 9.5,
      color: foreground,
      fontWeight: isEmphasized ? FontWeight.w600 : null,
      letterSpacing: isEmphasized ? 0.8 : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: background,
        shape: const StadiumBorder(),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: 4,
        ),
        child: _SingleLine(Text(label, style: _textStyle(context))),
      ),
    );
  }
}

/// Keeps [text], such as an identifier from the plugin API, on one line and
/// scales it down when the space is too narrow.
class _SingleLine extends StatelessWidget {
  const _SingleLine(this.text);

  final Text text;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: text,
    );
  }
}

/// The introduction shown with the system button.
class SystemButtonIntro extends StatelessWidget {
  const SystemButtonIntro({super.key});

  @override
  Widget build(BuildContext context) {
    final ExampleColors colors = ExampleColors.of(context);
    final bool isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    return Padding(
      padding: EdgeInsets.only(top: isIOS ? 30 : 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(
            header: true,
            headingLevel: 2,
            child: Text(
              'Share your location once',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
                height: 1.15,
                color: colors.text,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'One user-initiated fix. Access expires on its own.',
            style: TextStyle(
              fontSize: 13,
              height: 1.55,
              color: colors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

/// The introduction shown with the fallback button.
class FallbackButtonIntro extends StatelessWidget {
  const FallbackButtonIntro({super.key});

  @override
  Widget build(BuildContext context) {
    final ExampleColors colors = ExampleColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.accentSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Text(
            'This device doesn’t offer the system location button — the '
            'package draws its own and opens the standard permission dialog.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.55,
              color: colors.accentSurfaceText,
            ),
          ),
        ),
      ),
    );
  }
}

/// The card shown while there is no result and no request in progress.
class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({super.key});

  @override
  Widget build(BuildContext context) {
    final ExampleColors colors = ExampleColors.of(context);
    return CustomPaint(
      painter: DashedOutlinePainter(
        color: colors.emptyCardBorder,
        fillColor: colors.card,
        cornerRadius: 16,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 20 + DashedOutlinePainter.strokeWidth,
          vertical: 30 + DashedOutlinePainter.strokeWidth,
        ),
        child: Column(
          children: <Widget>[
            Semantics(
              header: true,
              headingLevel: 2,
              child: Text(
                'NO LOCATION YET',
                textAlign: TextAlign.center,
                style: monospaceStyle(
                  context,
                  fontSize: 11.5,
                  color: colors.tertiaryText,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Tap the button below to share a single fix.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: colors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The outlined surface of the cards. The border lies outside [padding].
class _Card extends StatelessWidget {
  const _Card({this.padding, required this.child});

  final EdgeInsetsGeometry? padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ExampleColors colors = ExampleColors.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colors.card,
        border: Border.all(color: colors.cardBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

/// The space between the border of a tagged card and its content.
const EdgeInsetsDirectional _taggedCardPadding =
    EdgeInsetsDirectional.symmetric(horizontal: 20, vertical: 22);

/// The space between the border of a tagged card and its tag.
const double _tagInset = 14;

/// The smallest space between a tag and the content beside it.
const double _tagGap = 8;

/// A card with a tag in its top end corner.
///
/// The tag overlaps the first line of the content, which is [leadingWidth]
/// wide. When the tag does not fit beside that line, it moves above the
/// content.
class _TaggedCard extends StatelessWidget {
  const _TaggedCard({
    required this.tag,
    required this.leadingWidth,
    required this.child,
  });

  final Tag tag;
  final double leadingWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double contentWidth =
              constraints.maxWidth - _taggedCardPadding.horizontal;
          final double tagOverlap =
              tag.measureWidth(context) - (_taggedCardPadding.end - _tagInset);
          if (leadingWidth + _tagGap + tagOverlap <= contentWidth) {
            return Stack(
              children: <Widget>[
                Padding(padding: _taggedCardPadding, child: child),
                PositionedDirectional(
                  top: _tagInset,
                  end: _tagInset,
                  child: tag,
                ),
              ],
            );
          }
          return Padding(
            padding: EdgeInsetsDirectional.only(
              top: _tagInset,
              bottom: _taggedCardPadding.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: _tagInset,
                    end: _tagInset,
                  ),
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: tag,
                  ),
                ),
                const SizedBox(height: _tagGap),
                Padding(
                  padding: EdgeInsetsDirectional.only(
                    start: _taggedCardPadding.start,
                    end: _taggedCardPadding.end,
                  ),
                  child: child,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The card shown while the position is determined.
class LocatingCard extends StatelessWidget {
  const LocatingCard({super.key});

  static const double _spinnerGap = 14;

  @override
  Widget build(BuildContext context) {
    final ExampleColors colors = ExampleColors.of(context);
    const String title = 'Getting location…';
    final TextStyle titleStyle = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: colors.text,
    );
    return _TaggedCard(
      tag: Tag(
        label: 'isLocating: true',
        foreground: colors.accent,
        background: colors.accentSurface,
        horizontalPadding: 9,
      ),
      leadingWidth:
          ProgressSpinner.size +
          _spinnerGap +
          _textWidth(context, title, titleStyle),
      child: Row(
        children: <Widget>[
          const ProgressSpinner(),
          const SizedBox(width: _spinnerGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Semantics(
                  header: true,
                  headingLevel: 2,
                  child: Text(title, style: titleStyle),
                ),
                const SizedBox(height: 3),
                Text(
                  'The button stays unchanged while the system searches.',
                  style: TextStyle(fontSize: 12.5, color: colors.secondaryText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The card shown for a granted result.
class PositionCard extends StatefulWidget {
  const PositionCard({
    super.key,
    required this.position,
    required this.note,
    required this.onCopy,
    this.clock = DateTime.now,
  });

  final OneTapPosition position;

  /// A remark about the position, or null.
  final String? note;

  final VoidCallback onCopy;

  /// Tells the current time, against which the age of the position is shown.
  final DateTime Function() clock;

  @override
  State<PositionCard> createState() => _PositionCardState();
}

class _PositionCardState extends State<PositionCard>
    with Announcements<PositionCard> {
  static const double _ringGap = 18;
  static const double _labelGap = 12;
  static const double _footerGap = 8;

  /// The space above the texts of the footer, which starts with the 1 logical
  /// pixel of the divider.
  static const double _footerTextTop = 1 + 12;

  /// The space below the texts of the footer, the padding of the card.
  static const double _footerTextBottom = 20;

  late final Timer _ageTimer;
  Timer? _copiedTimer;

  bool get _isCopied => _copiedTimer?.isActive ?? false;

  @override
  void initState() {
    super.initState();
    // Keeps the age of the position current.
    _ageTimer = Timer.periodic(
      const Duration(seconds: 15),
      (Timer timer) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _ageTimer.cancel();
    _copiedTimer?.cancel();
    super.dispose();
  }

  void _copy() {
    widget.onCopy();
    _copiedTimer?.cancel();
    setState(() {
      _copiedTimer = Timer(
        const Duration(milliseconds: 1500),
        () => setState(() {}),
      );
    });
    announce('Copied');
  }

  @override
  Widget build(BuildContext context) {
    final ExampleColors colors = ExampleColors.of(context);
    final OneTapPosition position = widget.position;
    final String? note = widget.note;
    final double? horizontalAccuracy = position.horizontalAccuracy;
    final double? altitude = position.altitude;
    final List<(String, String)> fields = <(String, String)>[
      (
        'horizontalAccuracy',
        horizontalAccuracy == null
            ? '—'
            : '±${formatMeters(horizontalAccuracy)}',
      ),
      (
        'altitude',
        switch (altitude) {
          final double altitude => formatMeters(altitude),
          null when !position.isPrecise => '— (null when approximate)',
          null => '—',
        },
      ),
      ('timestamp', formatTimestamp(position.timestamp, widget.clock())),
      ('isPrecise', '${position.isPrecise}'),
    ];
    final TextStyle labelStyle = TextStyle(
      fontSize: 12,
      height: 1.5,
      color: colors.secondaryText,
    );
    final TextStyle valueStyle = labelStyle.copyWith(
      color: colors.text,
      fontFeatures: _tabularFigures,
    );
    final Widget coordinates = Text(
      '${formatLatitude(position.latitude)}\n'
      '${formatLongitude(position.longitude)}',
      // The coordinates are large already, so they grow less than other text
      // and keep each number on one line.
      textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.5),
      style: TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        height: 1.35,
        color: colors.text,
        fontFeatures: _tabularFigures,
      ),
    );

    return _Card(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: position.isPrecise
                          ? colors.success
                          : colors.warning,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Semantics(
                      header: true,
                      headingLevel: 2,
                      child: Text(
                        'Location received',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: colors.text,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (position.isPrecise)
                Tag(
                  label: 'PRECISE',
                  foreground: colors.successText,
                  background: colors.successSurface,
                  isEmphasized: true,
                )
              else
                Tag(
                  label: 'APPROXIMATE',
                  foreground: colors.warningText,
                  background: colors.warningSurface,
                  isEmphasized: true,
                ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              // The fields keep their columns while the widest label and the
              // longest word of a value fit side by side. With less room, the
              // decorative ring goes first, then each value moves below its
              // label.
              final double labelWidth = fields
                  .map(((String, String) field) {
                    return _textWidth(context, field.$1, labelStyle);
                  })
                  .reduce(math.max);
              final double valueWordWidth = fields
                  .expand(((String, String) field) => field.$2.split(' '))
                  .map((String word) => _textWidth(context, word, valueStyle))
                  .reduce(math.max);
              final double tableWidth = labelWidth + _labelGap + valueWordWidth;
              final double widthBesideRing =
                  constraints.maxWidth - _ringGap - AccuracyRing.size;
              if (tableWidth > constraints.maxWidth) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    coordinates,
                    for (final (String label, String value)
                        in fields) ...<Widget>[
                      const SizedBox(height: 6),
                      _SingleLine(Text(label, style: labelStyle)),
                      Text(value, style: valueStyle),
                    ],
                  ],
                );
              }
              final Widget details = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  coordinates,
                  const SizedBox(height: 10),
                  Table(
                    columnWidths: const <int, TableColumnWidth>{
                      0: IntrinsicColumnWidth(),
                    },
                    children: <TableRow>[
                      for (final (int index, (String label, String value))
                          in fields.indexed)
                        TableRow(
                          children: <Widget>[
                            Padding(
                              padding: EdgeInsetsDirectional.only(
                                end: _labelGap,
                                bottom: index == fields.length - 1 ? 0 : 3,
                              ),
                              child: Text(label, style: labelStyle),
                            ),
                            Text(value, style: valueStyle),
                          ],
                        ),
                    ],
                  ),
                ],
              );
              if (tableWidth > widthBesideRing) {
                return details;
              }
              return Row(
                children: <Widget>[
                  Expanded(child: details),
                  const SizedBox(width: _ringGap),
                  ExcludeSemantics(
                    child: AccuracyRing(isPrecise: position.isPrecise),
                  ),
                ],
              );
            },
          ),
          if (note != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              note,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: colors.secondaryText,
              ),
            ),
          ],
          SizedBox(height: note == null ? 16 : 14),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: colors.divider)),
            ),
            child: _buildFooter(context, colors),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, ExampleColors colors) {
    const String resultType = 'OneTapLocationGranted';
    const String copyLabel = 'Copy result';
    const String copiedLabel = 'Copied';
    final TextStyle resultTypeStyle = monospaceStyle(
      context,
      fontSize: 10.5,
      color: colors.tertiaryText,
    );
    // A button does not inherit the ambient text style, so its text style
    // includes it, as the measured width of the text does.
    final TextStyle buttonTextStyle = DefaultTextStyle.of(
      context,
    ).style.merge(const TextStyle(fontSize: 13, fontWeight: FontWeight.w600));
    final Widget label = _SingleLine(Text(resultType, style: resultTypeStyle));
    Widget buildButton({
      required EdgeInsetsGeometry padding,
      required AlignmentGeometry alignment,
    }) {
      return TextButton(
        onPressed: _copy,
        style: TextButton.styleFrom(
          foregroundColor: colors.accent,
          padding: padding,
          minimumSize: const Size(48, 48),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          alignment: alignment,
          textStyle: buttonTextStyle,
        ),
        // Where the platform has no announcements, the confirmation is spoken
        // as the label of the button changes, but not the label that returns
        // after it.
        child: Semantics(
          liveRegion: usesLiveRegion && _isCopied,
          // Both texts keep their space, so the button does not change size
          // while it confirms the copy.
          child: Stack(
            alignment: alignment,
            children: <Widget>[
              for (final String text in <String>[copyLabel, copiedLabel])
                Visibility(
                  visible: (text == copiedLabel) == _isCopied,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: Text(text),
                ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double buttonTextWidth = math.max(
          _textWidth(context, copyLabel, buttonTextStyle),
          _textWidth(context, copiedLabel, buttonTextStyle),
        );
        final bool fitsOnOneLine =
            _textWidth(context, resultType, resultTypeStyle) +
                _footerGap +
                buttonTextWidth <=
            constraints.maxWidth;
        if (fitsOnOneLine) {
          // Both texts share a center line, and the tap target of the button
          // extends over the space around them.
          const EdgeInsets padding = EdgeInsets.only(
            top: _footerTextTop,
            bottom: _footerTextBottom,
          );
          return Row(
            children: <Widget>[
              Expanded(
                child: Padding(padding: padding, child: label),
              ),
              const SizedBox(width: _footerGap),
              buildButton(
                padding: padding,
                alignment: AlignmentDirectional.centerEnd,
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: _footerTextTop),
            label,
            const SizedBox(height: 4),
            buildButton(
              padding: const EdgeInsets.only(bottom: _footerTextBottom),
              alignment: AlignmentDirectional.topStart,
            ),
          ],
        );
      },
    );
  }
}

/// The card shown when access was denied.
class DeniedCard extends StatelessWidget {
  const DeniedCard({super.key});

  @override
  Widget build(BuildContext context) {
    final ExampleColors colors = ExampleColors.of(context);
    return _OutcomeCard(
      tag: Tag(
        label: 'OneTapLocationDenied',
        foreground: colors.errorText,
        background: colors.errorSurface,
        horizontalPadding: 9,
      ),
      icon: Icons.do_not_disturb,
      iconColor: colors.error,
      iconBackground: colors.errorSurface,
      title: 'Access declined',
      text:
          'You or a device policy declined this request. No location was shared.',
    );
  }
}

/// The card shown when no position could be obtained.
class FailedCard extends StatelessWidget {
  const FailedCard({super.key, required this.exception});

  final OneTapLocationException exception;

  @override
  Widget build(BuildContext context) {
    final ExampleColors colors = ExampleColors.of(context);
    final String? message = exception.message;
    return _OutcomeCard(
      tag: Tag(
        label: exception.code.name,
        foreground: colors.warningText,
        background: colors.warningSurface,
        horizontalPadding: 9,
      ),
      icon: Icons.warning_amber,
      iconColor: colors.warning,
      iconBackground: colors.warningSurface,
      title: 'Couldn’t get a location',
      text: switch (exception.code) {
        OneTapLocationErrorCode.locationUnavailable =>
          'The system didn’t deliver a fix and doesn’t say why.',
        OneTapLocationErrorCode.locationServicesDisabled =>
          'Location services are off. Turn them on in system settings.',
        OneTapLocationErrorCode.unknown => null,
      },
      detail: message == null
          ? null
          : DecoratedBox(
              decoration: BoxDecoration(
                color: colors.codeSurface,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                child: Text(
                  'message: "$message"\nfor logs only\u00A0· untranslated',
                  style: monospaceStyle(
                    context,
                    fontSize: 10.5,
                    color: colors.secondaryText,
                    height: 1.5,
                  ),
                ),
              ),
            ),
    );
  }
}

/// The shared layout of the outcome cards: a round icon, a title, and the
/// optional [text] and [detail] below it.
class _OutcomeCard extends StatelessWidget {
  const _OutcomeCard({
    required this.tag,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.text,
    this.detail,
  });

  static const double _iconSize = 40;

  final Tag tag;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;

  /// The sentence below the title, or null when the card has none.
  final String? text;

  /// A box as wide as the card content, below [text] where there is one and
  /// below the title otherwise, or null when the card has none.
  final Widget? detail;

  @override
  Widget build(BuildContext context) {
    final ExampleColors colors = ExampleColors.of(context);
    final String? text = this.text;
    final Widget? detail = this.detail;
    return _TaggedCard(
      tag: tag,
      leadingWidth: _iconSize,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: _iconSize,
            height: _iconSize,
            decoration: BoxDecoration(
              color: iconBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(height: 14),
          Semantics(
            header: true,
            headingLevel: 2,
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w600,
                color: colors.text,
              ),
            ),
          ),
          if (text != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              text,
              style: TextStyle(
                fontSize: 13,
                height: 1.55,
                color: colors.secondaryText,
              ),
            ),
          ],
          if (detail != null) ...<Widget>[
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: detail),
          ],
        ],
      ),
    );
  }
}

/// The notice shown when a tap did not grant access.
class TapWithoutAuthorizationBanner extends StatelessWidget {
  const TapWithoutAuthorizationBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final ExampleColors colors = ExampleColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.warningSurface,
        border: Border.all(color: colors.warningBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.warning_amber, size: 16, color: colors.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  header: true,
                  headingLevel: 2,
                  child: Text(
                    'Tap without authorization',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: colors.warningText,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'The button may have been tapped, but access wasn’t granted. No '
            'reason is reported.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.55,
              color: colors.warningText,
            ),
          ),
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.bannerCodeSurface,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: _SingleLine(
                Text(
                  'diagnostics: tapWithoutAuthorization',
                  style: monospaceStyle(
                    context,
                    fontSize: 10,
                    color: colors.warning,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
