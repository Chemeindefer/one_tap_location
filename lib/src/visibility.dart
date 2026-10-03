// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// The distance, in physical pixels, by which a child may extend past the
/// visible area and still count as fully visible. Absorbs rounding in layout.
const double _tolerance = 1;

/// The distance, in logical pixels, between the edges of the child and the
/// points that are hit tested. A hit test exactly on the right or bottom edge
/// misses the child.
const double _hitTestInset = 1;

/// The largest horizontal distance, in logical pixels, between two points that
/// are hit tested. Covering content at least this wide is detected.
const double _hitTestSpacing = 48;

/// The largest relative difference between the scale of the child and the
/// scale of the view at which the child still counts as drawn at its own size.
/// Absorbs rounding in the transforms of the ancestors.
const double _scaleTolerance = 0.001;

/// Reports whether its child is fully visible on the screen.
///
/// The child is fully visible when it is composited, no ancestor clips it,
/// lowers its opacity, scales it, rotates it or applies an image filter to it,
/// it lies within the area that the system bars and the on-screen keyboard
/// leave uncovered, and no content above it keeps pointer events from reaching
/// it. Covering content is found by hit testing points across the child, so
/// content that lets pointer events through, or that is narrower than 48
/// logical pixels, can go unnoticed. Shader masks and color filters of
/// ancestors are not taken into account.
///
/// While an ancestor ignores pointer events, as a scroll view does while it
/// scrolls, covering content cannot be found: the child keeps the answer it
/// had, and a child that was not hit tested at its position before counts as
/// covered.
class VisibilityProbe extends SingleChildRenderObjectWidget {
  /// Creates a probe that calls [onVisibilityChanged] after each frame in which
  /// the visibility of [child] changes.
  const VisibilityProbe({
    super.key,
    required this.onVisibilityChanged,
    super.child,
  });

  /// Called with true when the child becomes fully visible, and with false when
  /// it stops being fully visible.
  final ValueChanged<bool> onVisibilityChanged;

  @override
  RenderVisibilityProbe createRenderObject(BuildContext context) {
    return RenderVisibilityProbe(
      view: View.of(context),
      onVisibilityChanged: onVisibilityChanged,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderVisibilityProbe renderObject,
  ) {
    renderObject
      ..view = View.of(context)
      ..onVisibilityChanged = onVisibilityChanged;
  }
}

/// The render object of a [VisibilityProbe].
class RenderVisibilityProbe extends RenderProxyBox {
  /// Creates a render object that reports the visibility of its child in
  /// [view].
  RenderVisibilityProbe({
    required this.view,
    required this.onVisibilityChanged,
    RenderBox? child,
  }) : super(child);

  /// The view that the child is shown in.
  ui.FlutterView view;

  /// Called after each frame in which the visibility of the child changes.
  ValueChanged<bool> onVisibilityChanged;

  bool _isVisible = false;
  bool _isCovered = true;
  bool? _pendingLayerVisibility;

  @override
  bool get alwaysNeedsCompositing => child != null;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) {
      layer = null;
      return;
    }
    final _VisibilityProbeLayer probeLayer =
        layer as _VisibilityProbeLayer? ?? _VisibilityProbeLayer(this);
    probeLayer.bounds = offset & size;
    layer = probeLayer;
    context.pushLayer(probeLayer, super.paint, offset);
  }

  // Layers are composited and detached in the middle of a frame, before hit
  // tests are reliable and while the listener must not change the widget tree.
  void _report(bool isLayerVisible) {
    final bool isScheduled = _pendingLayerVisibility != null;
    _pendingLayerVisibility = isLayerVisible;
    if (isScheduled) {
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((Duration timeStamp) {
      final bool isLayerVisible = _pendingLayerVisibility!;
      _pendingLayerVisibility = null;
      if (!isLayerVisible) {
        // Covering content is checked again at the next position.
        _isCovered = true;
      }
      if (!attached) {
        return;
      }
      final bool isVisible = isLayerVisible && _isUncovered();
      if (isVisible != _isVisible) {
        _isVisible = isVisible;
        onVisibilityChanged(isVisible);
      }
    }, debugLabel: 'VisibilityProbe.report');
  }

  bool _isUncovered() {
    for (RenderObject? node = parent; node != null; node = node.parent) {
      // An ancestor that ignores pointer events, such as the one a scroll view
      // uses while it scrolls, keeps hit tests from reaching the child whether
      // or not content covers it, so the last answer stands until the ancestor
      // stops ignoring them.
      if (node is RenderIgnorePointer && node.ignoring ||
          node is RenderSliverIgnorePointer && node.ignoring) {
        return !_isCovered;
      }
    }
    final Rect area = (Offset.zero & size).deflate(
      math.min(_hitTestInset, size.shortestSide / 2),
    );
    final int intervals = math.max(2, (area.width / _hitTestSpacing).ceil());
    // Points on the top and bottom edges stay clear of the rounded ends of a
    // fully rounded child, where a clip of that shape does not hit the child.
    final double endRadius = area.height / 2;
    for (int interval = 0; interval <= intervals; interval += 1) {
      final double dx = area.left + area.width * interval / intervals;
      final bool isBetweenEnds =
          dx >= area.left + endRadius && dx <= area.right - endRadius;
      final List<double> rows = isBetweenEnds
          ? <double>[area.top, area.center.dy, area.bottom]
          : <double>[area.center.dy];
      for (final double dy in rows) {
        if (_isCoveredAt(Offset(dx, dy))) {
          _isCovered = true;
          return false;
        }
      }
    }
    _isCovered = false;
    return true;
  }

  // The child receives pointer events in its whole area, so a point where a
  // hit test does not reach it is covered: by content that receives the event,
  // or by content that absorbs it, such as an AbsorbPointer. Content that lets
  // pointer events through, such as the edge of a closed drawer, does not cover
  // the child.
  bool _isCoveredAt(Offset point) {
    final HitTestResult result = HitTestResult();
    RendererBinding.instance.hitTestInView(
      result,
      localToGlobal(point),
      view.viewId,
    );
    return !result.path.any(
      (HitTestEntry entry) => identical(entry.target, this),
    );
  }
}

class _VisibilityProbeLayer extends ContainerLayer {
  _VisibilityProbeLayer(this._probe);

  final RenderVisibilityProbe _probe;

  /// The area of the child, in the coordinate space of this layer.
  Rect bounds = Rect.zero;

  // Evaluating the visibility on every frame keeps it current while ancestors
  // move, even when this layer could otherwise be retained.
  @override
  bool get alwaysNeedsAddToScene => true;

  @override
  void addToScene(ui.SceneBuilder builder) {
    super.addToScene(builder);
    _probe._report(_isFullyVisible());
  }

  @override
  void detach() {
    super.detach();
    _probe._report(false);
  }

  bool _isFullyVisible() {
    final List<ContainerLayer> ancestors = <ContainerLayer>[];
    for (ContainerLayer? ancestor = parent; ancestor != null;) {
      ancestors.add(ancestor);
      ancestor = ancestor.parent;
    }
    Rect visibleArea = _uncoveredArea(_probe.view);
    // Maps the coordinate space of the current layer to the physical pixels of
    // the view, starting at the root layer.
    final Matrix4 transform = Matrix4.identity();
    for (int index = ancestors.length - 1; index >= 0; index -= 1) {
      final ContainerLayer ancestor = ancestors[index];
      // The engine applies neither opacity nor image filters to the system
      // button, and a Transform with a filter quality scales through an image
      // filter.
      if (ancestor is OpacityLayer && (ancestor.alpha ?? 255) < 255 ||
          ancestor is ImageFilterLayer) {
        return false;
      }
      final Rect? clip = _clipBounds(ancestor);
      if (clip != null) {
        visibleArea = visibleArea.intersect(
          MatrixUtils.transformRect(transform, clip),
        );
      }
      ancestor.applyTransform(
        index == 0 ? this : ancestors[index - 1],
        transform,
      );
    }
    final Rect area = MatrixUtils.transformRect(transform, bounds);
    final Rect visiblePart = area.intersect(visibleArea);
    return _isUpright(transform, _probe.view.devicePixelRatio) &&
        !area.isEmpty &&
        visiblePart.width >= area.width - _tolerance &&
        visiblePart.height >= area.height - _tolerance;
  }

  /// Whether [transform] maps logical pixels to the physical pixels of a view
  /// with [devicePixelRatio] without scaling, rotating, skewing or projecting
  /// them.
  static bool _isUpright(Matrix4 transform, double devicePixelRatio) {
    final double tolerance = devicePixelRatio * _scaleTolerance;
    return (transform.entry(0, 0) - devicePixelRatio).abs() <= tolerance &&
        (transform.entry(1, 1) - devicePixelRatio).abs() <= tolerance &&
        transform.entry(0, 1).abs() <= tolerance &&
        transform.entry(1, 0).abs() <= tolerance &&
        transform.entry(3, 0) == 0 &&
        transform.entry(3, 1) == 0;
  }

  static Rect _uncoveredArea(ui.FlutterView view) {
    final ui.ViewPadding padding = view.viewPadding;
    final ui.ViewPadding insets = view.viewInsets;
    return Rect.fromLTRB(
      math.max(padding.left, insets.left),
      math.max(padding.top, insets.top),
      view.physicalSize.width - math.max(padding.right, insets.right),
      view.physicalSize.height - math.max(padding.bottom, insets.bottom),
    );
  }

  static Rect? _clipBounds(ContainerLayer layer) {
    return switch (layer) {
      ClipRectLayer(:final Rect? clipRect, :final Clip clipBehavior)
          when clipBehavior != Clip.none =>
        clipRect,
      ClipRRectLayer(:final RRect? clipRRect, :final Clip clipBehavior)
          when clipBehavior != Clip.none =>
        clipRRect?.outerRect,
      ClipRSuperellipseLayer(
        :final RSuperellipse? clipRSuperellipse,
        :final Clip clipBehavior,
      )
          when clipBehavior != Clip.none =>
        clipRSuperellipse?.outerRect,
      ClipPathLayer(:final Path? clipPath, :final Clip clipBehavior)
          when clipBehavior != Clip.none =>
        clipPath?.getBounds(),
      _ => null,
    };
  }
}
