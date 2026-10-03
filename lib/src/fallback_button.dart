// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'style.dart';

/// The space that the system button on Android leaves between each side of
/// the button and its visible shape. The whole button still receives taps.
const double _androidShapeInset = 4;

/// The widest outline that the system button draws.
const double _maxStrokeWidth = 3;

/// The sizes of the content of the system button, which follow the sizes of
/// Material 3 buttons.
///
/// The system button on Android is at most 136 logical pixels tall, so its
/// visible shape is never tall enough for the extra large size.
enum _ContentSize {
  small(iconSize: 20, iconLabelGap: 4, maxPadding: 16),
  medium(iconSize: 24, iconLabelGap: 8, maxPadding: 24),
  large(iconSize: 32, iconLabelGap: 12, maxPadding: 48);

  const _ContentSize({
    required this.iconSize,
    required this.iconLabelGap,
    required this.maxPadding,
  });

  /// The size for a visible shape whose shorter side is [extent] logical
  /// pixels long.
  factory _ContentSize.forExtent(double extent) {
    if (extent < 56) {
      return small;
    }
    return extent < 96 ? medium : large;
  }

  final double iconSize;

  final double iconLabelGap;

  /// The largest space between the visible shape and the content.
  final double maxPadding;

  TextStyle textStyle(TextTheme textTheme) {
    return switch (this) {
      small => textTheme.labelLarge!,
      medium => textTheme.titleMedium!,
      large => textTheme.headlineSmall!,
    };
  }

  /// The corner radius of a pressed visible shape whose shorter side is
  /// [extent] logical pixels long, unless the style sets one.
  static double pressedCornerRadiusFor(double extent) {
    if (extent <= 48) {
      return 8;
    }
    return extent <= 76 ? 12 : 16;
  }
}

/// A button that resembles the system location button.
///
/// Shown on Android versions without the system location button, and in place
/// of the system button while a fake is installed in a test.
class FallbackLocationButton extends StatelessWidget {
  /// Creates a fallback button that looks as [style] describes.
  const FallbackLocationButton({
    super.key,
    required this.style,
    required this.onPressed,
    this.label,
    this.showsLabel,
    this.showsIcon = true,
    this.shapeInset = _androidShapeInset,
  });

  /// The appearance of the button.
  final OneTapLocationButtonStyle style;

  /// Called when the button is tapped; null while a request is in progress.
  final VoidCallback? onPressed;

  /// The text of the button.
  ///
  /// When null, the button shows [OneTapLocationButtonStyle.androidFallbackLabel]
  /// or the English text of [OneTapLocationButtonStyle.androidLabel].
  final String? label;

  /// Whether the button shows its text next to its icon.
  ///
  /// When null, the button shows its text unless
  /// [OneTapLocationButtonStyle.androidLabel] is
  /// [AndroidLocationButtonLabel.none].
  final bool? showsLabel;

  /// Whether the button shows its icon next to its text.
  ///
  /// A button without text always shows its icon.
  final bool showsIcon;

  /// The space between each side of the button and its visible shape, in
  /// logical pixels.
  final double shapeInset;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color backgroundColor =
        style.backgroundColor ?? colors.secondaryContainer;
    final Color foregroundColor =
        style.foregroundColor ?? colors.onSecondaryContainer;
    final Color? strokeColor = style.androidStrokeColor;
    final double strokeWidth = math.min(
      style.androidStrokeWidth ?? 0,
      _maxStrokeWidth,
    );
    // Like the system button, the button has no outline without a color.
    final BorderSide side = strokeColor != null && strokeWidth > 0
        ? BorderSide(color: strokeColor, width: strokeWidth)
        : BorderSide.none;
    final String label =
        this.label ??
        style.androidFallbackLabel ??
        englishAndroidLabel(style.androidLabel);
    final bool showsLabel =
        this.showsLabel ??
        style.androidLabel != AndroidLocationButtonLabel.none;
    OutlinedBorder shapeFor(double? cornerRadius) {
      return InsetBorder(
        cornerRadius == null
            ? StadiumBorder(side: side)
            : RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(cornerRadius),
                side: side,
              ),
        shapeInset,
      );
    }

    // Like the system button, the label keeps its typography whatever the text
    // theme of the app.
    final ScriptCategory scriptCategory =
        Localizations.of<MaterialLocalizations>(
          context,
          MaterialLocalizations,
        )?.scriptCategory ??
        ScriptCategory.englishLike;
    final TextTheme textTheme = switch (scriptCategory) {
      ScriptCategory.englishLike => Typography.englishLike2021,
      ScriptCategory.dense => Typography.dense2021,
      ScriptCategory.tall => Typography.tall2021,
    };
    // A disabled button gives its focus away in the traditional navigation
    // mode, which would move the focus of a keyboard user off the button while
    // a request is in progress.
    final MediaQueryData mediaQuery =
        (MediaQuery.maybeOf(context) ?? const MediaQueryData()).copyWith(
          navigationMode: NavigationMode.directional,
        );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size shapeSize = constraints
            .deflate(EdgeInsets.all(shapeInset))
            .biggest;
        // Like the system button, the content grows with the shorter side of
        // the visible shape, so that a tall and narrow button does not clip it.
        final double extent = shapeSize.shortestSide;
        final _ContentSize contentSize = _ContentSize.forExtent(extent);
        final OutlinedBorder shape = shapeFor(style.cornerRadius);
        final OutlinedBorder pressedShape = shapeFor(
          style.androidPressedCornerRadius ??
              _ContentSize.pressedCornerRadiusFor(extent),
        );
        // Like the system button, a narrow button keeps its icon and cuts the
        // label off, so the padding gives way before the icon does.
        final double contentPadding = showsLabel
            ? clampDouble(
                (shapeSize.width - contentSize.iconSize) / 2,
                0,
                contentSize.maxPadding,
              )
            : 0;
        final ButtonStyle buttonStyle = FilledButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          // Like the system button, the button keeps its look while a request
          // is in progress.
          disabledBackgroundColor: backgroundColor,
          disabledForegroundColor: foregroundColor,
          // The disabled button stays focusable, and activating it from a
          // keyboard would still show press feedback.
          splashFactory: onPressed == null ? NoSplash.splashFactory : null,
          textStyle: contentSize.textStyle(textTheme),
          iconSize: contentSize.iconSize,
          minimumSize: constraints.biggest,
          padding: EdgeInsets.symmetric(
            horizontal: showsLabel ? shapeInset + contentPadding : 0,
          ),
          visualDensity: VisualDensity.standard,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
        return Center(
          // The look follows the system button rather than the filled buttons
          // of the app.
          child: FilledButtonTheme(
            data: const FilledButtonThemeData(),
            child: MediaQuery(
              data: mediaQuery,
              child: FilledButton(
                onPressed: onPressed,
                style: buttonStyle.copyWith(
                  shape: WidgetStateProperty.resolveWith(
                    (Set<WidgetState> states) =>
                        states.contains(WidgetState.pressed) &&
                            !states.contains(WidgetState.disabled)
                        ? pressedShape
                        : shape,
                  ),
                  overlayColor: WidgetStateProperty.resolveWith(
                    (Set<WidgetState> states) =>
                        states.contains(WidgetState.pressed) &&
                            states.contains(WidgetState.disabled)
                        ? const Color(0x00000000)
                        : buttonStyle.overlayColor?.resolve(states),
                  ),
                ),
                child: showsLabel
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (showsIcon) const _LocationIcon(),
                          // The gap disappears together with the label.
                          Flexible(
                            child: Padding(
                              padding: EdgeInsetsDirectional.only(
                                start: showsIcon ? contentSize.iconLabelGap : 0,
                              ),
                              child: Text(
                                label,
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Semantics(label: label, child: const _LocationIcon()),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The English text of the system button on Android for [label].
///
/// A button without text uses the text of
/// [AndroidLocationButtonLabel.preciseLocation] for its semantics.
String englishAndroidLabel(AndroidLocationButtonLabel label) {
  return switch (label) {
    AndroidLocationButtonLabel.none ||
    AndroidLocationButtonLabel.preciseLocation => 'Precise location',
    AndroidLocationButtonLabel.usePreciseLocation => 'Use precise location',
    AndroidLocationButtonLabel.sharePreciseLocation => 'Share precise location',
    AndroidLocationButtonLabel.nearMyPreciseLocation =>
      'Near my precise location',
    AndroidLocationButtonLabel.nearYourPreciseLocation =>
      'Near your precise location',
  };
}

/// The English text of the system button on iOS for [label].
///
/// A button without text uses the text of
/// [IOSLocationButtonLabel.currentLocation] for its semantics.
String englishIOSLabel(IOSLocationButtonLabel label) {
  return switch (label) {
    IOSLocationButtonLabel.none ||
    IOSLocationButtonLabel.currentLocation => 'Current Location',
    IOSLocationButtonLabel.sendCurrentLocation => 'Send Current Location',
    IOSLocationButtonLabel.sendMyCurrentLocation => 'Send My Current Location',
    IOSLocationButtonLabel.shareCurrentLocation => 'Share Current Location',
    IOSLocationButtonLabel.shareMyCurrentLocation =>
      'Share My Current Location',
  };
}

/// Draws [border] inside the area it is given, leaving [inset] logical pixels
/// on every side.
///
/// A button with this shape receives taps in the whole area, including the
/// space around the visible shape.
@immutable
class InsetBorder extends OutlinedBorder {
  /// Creates a border that draws [border] inset by [inset] on every side.
  InsetBorder(this.border, this.inset)
    : assert(inset >= 0),
      super(side: border.side);

  /// The border that is drawn.
  final OutlinedBorder border;

  /// The space on every side, in logical pixels.
  final double inset;

  Rect _insetRect(Rect rect) {
    final double horizontal = math.min(inset, rect.width / 2);
    final double vertical = math.min(inset, rect.height / 2);
    return Rect.fromLTRB(
      rect.left + horizontal,
      rect.top + vertical,
      rect.right - horizontal,
      rect.bottom - vertical,
    );
  }

  @override
  EdgeInsetsGeometry get dimensions => border.dimensions;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return border.getInnerPath(_insetRect(rect), textDirection: textDirection);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return border.getOuterPath(_insetRect(rect), textDirection: textDirection);
  }

  @override
  bool get preferPaintInterior => border.preferPaintInterior;

  @override
  void paintInterior(
    Canvas canvas,
    Rect rect,
    Paint paint, {
    TextDirection? textDirection,
  }) {
    border.paintInterior(
      canvas,
      _insetRect(rect),
      paint,
      textDirection: textDirection,
    );
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    border.paint(canvas, _insetRect(rect), textDirection: textDirection);
  }

  @override
  InsetBorder copyWith({BorderSide? side}) {
    return InsetBorder(border.copyWith(side: side), inset);
  }

  @override
  ShapeBorder scale(double t) {
    final ShapeBorder scaled = border.scale(t);
    return scaled is OutlinedBorder ? InsetBorder(scaled, inset * t) : scaled;
  }

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is InsetBorder) {
      final ShapeBorder? lerped = ShapeBorder.lerp(a.border, border, t);
      if (lerped is OutlinedBorder) {
        return InsetBorder(lerped, lerpDouble(a.inset, inset, t)!);
      }
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is InsetBorder) {
      final ShapeBorder? lerped = ShapeBorder.lerp(border, b.border, t);
      if (lerped is OutlinedBorder) {
        return InsetBorder(lerped, lerpDouble(inset, b.inset, t)!);
      }
    }
    return super.lerpTo(b, t);
  }

  @override
  bool operator ==(Object other) =>
      other is InsetBorder && other.border == border && other.inset == inset;

  @override
  int get hashCode => Object.hash(border, inset);

  @override
  String toString() => 'InsetBorder($border, $inset)';
}

/// The location icon of the system button, in the color and size of the
/// ambient [IconTheme].
class _LocationIcon extends StatelessWidget {
  const _LocationIcon();

  @override
  Widget build(BuildContext context) {
    final IconThemeData iconTheme = IconTheme.of(context);
    return SizedBox.square(
      dimension: iconTheme.size ?? _ContentSize.small.iconSize,
      child: CustomPaint(
        painter: _LocationIconPainter(
          iconTheme.color ?? const Color(0xFF000000),
        ),
      ),
    );
  }
}

/// Paints a crosshair: two rings and four ticks, measured on a grid of 960
/// units.
class _LocationIconPainter extends CustomPainter {
  const _LocationIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double unit = size.shortestSide / 960;
    final Offset center = size.center(Offset.zero);
    final Paint paint = Paint()..color = color;
    for (final Offset direction in const <Offset>[
      Offset(0, -1),
      Offset(1, 0),
      Offset(0, 1),
      Offset(-1, 0),
    ]) {
      canvas.drawRect(
        Rect.fromCenter(
          center: center + direction * 398 * unit,
          width: 80 * unit,
          height: 80 * unit,
        ),
        paint,
      );
    }
    paint.style = PaintingStyle.stroke;
    canvas
      ..drawCircle(center, 319 * unit, paint..strokeWidth = 78 * unit)
      ..drawCircle(center, 120 * unit, paint..strokeWidth = 80 * unit);
  }

  @override
  bool shouldRepaint(_LocationIconPainter oldDelegate) {
    return color != oldDelegate.color;
  }
}
