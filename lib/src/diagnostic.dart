// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// @docImport 'button.dart';
library;

/// A signal that explains why a [OneTapLocationButton] has not produced a
/// result.
enum OneTapLocationDiagnostic {
  /// The button may have been tapped, but access was not granted.
  ///
  /// On iOS, the diagnostic is reported when a tap does not grant access within
  /// a few seconds. The system ignores taps on a button that is not fully
  /// visible, not fully opaque, smaller than the size the system requires, or
  /// covered by other content, without reporting an error. The waiting period
  /// starts again when the app becomes active after being inactive, for example
  /// after a system prompt, and the diagnostic is reported at most once per
  /// tap. If access is granted afterwards, the button still reports the result,
  /// unless another button was tapped in the meantime.
  ///
  /// For the system location button on Android, the diagnostic is reported
  /// when the user closes the system confirmation without answering it. The
  /// confirmation is told apart from other screens that pause the app, such as
  /// a permission dialog of another plugin, by the activity that the system
  /// opens; where that activity cannot be identified, such screens have the
  /// same effect. The diagnostic is not reported while several buttons are
  /// shown, because the tapped one is unknown. The system reports nothing for
  /// taps that it ignores.
  ///
  /// For the fallback button, the diagnostic is reported only when the
  /// permission request is interrupted before the user answers, for example
  /// because another permission request is in progress. On Android 11 and
  /// later, a permission dialog that the user closes without answering produces
  /// a result instead: a denial, or an approximate position when approximate
  /// access was granted before. On Android 7 to 10, Back does not close the
  /// dialog.
  tapWithoutAuthorization,
}
