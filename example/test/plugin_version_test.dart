// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_tap_location_example/src/plugin_version.dart';

void main() {
  test('matches the version in the plugin pubspec', () {
    final String pubspec = File('../pubspec.yaml').readAsStringSync();
    final RegExpMatch? version = RegExp(
      r'^version: (\S+)$',
      multiLine: true,
    ).firstMatch(pubspec);

    expect(pluginVersion, version?.group(1));
  });
}
