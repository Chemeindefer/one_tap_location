// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:ui' show FlutterView;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// Tells screen reader users about content that changes away from their
/// focus.
///
/// Where the platform supports announcements, as iOS does, [announce] sends
/// one. Elsewhere, as on Android, the changing content belongs in a
/// [Semantics] live region, which [usesLiveRegion] tells.
mixin Announcements<T extends StatefulWidget> on State<T> {
  Timer? _announcementTimer;

  /// Whether changes are announced through a live region instead of
  /// [announce].
  bool get usesLiveRegion => !MediaQuery.supportsAnnounceOf(context);

  /// Announces [message], replacing an announcement that has not been sent
  /// yet.
  void announce(String message) {
    if (usesLiveRegion) {
      return;
    }
    final FlutterView view = View.of(context);
    final TextDirection textDirection = Directionality.of(context);
    _announcementTimer?.cancel();
    // VoiceOver drops an announcement that arrives together with the layout
    // change it describes (https://github.com/flutter/flutter/issues/122101).
    _announcementTimer = Timer(const Duration(seconds: 1), () {
      unawaited(
        SemanticsService.sendAnnouncement(
          view,
          message,
          textDirection,
        ).catchError((Object exception, StackTrace stack) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: exception,
              stack: stack,
              library: 'one_tap_location example',
              context: ErrorDescription('while announcing "$message"'),
            ),
          );
        }),
      );
    });
  }

  @override
  void dispose() {
    _announcementTimer?.cancel();
    super.dispose();
  }
}

/// Reports [status] to screen readers through a live region where the
/// platform offers no announcements, and renders nothing.
///
/// The region fills its parent without taking accessibility focus or touches.
/// Placed over content that scrolls, it stays on screen while the content that
/// shows the status is scrolled out of view, where a live region would not
/// speak.
class StatusLiveRegion extends StatelessWidget {
  const StatusLiveRegion({
    super.key,
    required this.status,
    required this.reportCount,
  });

  /// The status in the words a screen reader speaks, or null for none.
  final String? status;

  /// How many times the status was reported.
  ///
  /// A live region speaks when its label changes. A new count creates a new
  /// region, which also speaks a status that repeats the previous one.
  final int reportCount;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.supportsAnnounceOf(context)) {
      return const SizedBox.expand();
    }
    return Semantics(
      key: ValueKey<int>(reportCount),
      container: true,
      liveRegion: true,
      label: status,
      accessibilityFocusBlockType: AccessibilityFocusBlockType.blockNode,
      child: const SizedBox.expand(),
    );
  }
}
