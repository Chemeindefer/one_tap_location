// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Test support for apps that show a [OneTapLocationButton].
///
/// Tests that run on the host, such as widget tests, do not run the platform
/// code of the plugin, so a [OneTapLocationButton] shows nothing that can be
/// tapped, and [OneTapLocationButton.checkAvailability] cannot determine the
/// availability on iOS and Android. Install a [FakeOneTapLocation] before
/// pumping the widgets under test:
///
/// ```dart
/// late FakeOneTapLocation location;
///
/// setUp(() {
///   location = FakeOneTapLocation.install();
///   addTearDown(location.uninstall);
/// });
/// ```
///
/// @docImport 'one_tap_location.dart';
library;

export 'src/fake.dart' show FakeLocationRequest, FakeOneTapLocation;
