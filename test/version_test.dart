// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The files that carry the version of the package, and the pattern that reads
/// it from each of them. A release moves the version in every one of them.
const Map<String, String> versionedFiles = <String, String>{
  'ios/one_tap_location.podspec': r"^\s*s\.version\s*=\s*'(\S+)'$",
  'example/lib/src/plugin_version.dart':
      r"^const String pluginVersion = '(\S+)';$",
};

void main() {
  test('every file that carries the version agrees with the pubspec', () {
    final String pubspec = File('pubspec.yaml').readAsStringSync();
    final RegExpMatch? declared = RegExp(
      r'^version: (\S+)$',
      multiLine: true,
    ).firstMatch(pubspec);
    expect(declared, isNotNull, reason: 'pubspec.yaml declares no version');
    final String version = declared!.group(1)!;

    for (final MapEntry<String, String> entry in versionedFiles.entries) {
      final File file = File(entry.key);
      expect(
        file.existsSync(),
        isTrue,
        reason: '${entry.key} is missing; update versionedFiles',
      );
      final RegExpMatch? found = RegExp(
        entry.value,
        multiLine: true,
      ).firstMatch(file.readAsStringSync());
      expect(
        found,
        isNotNull,
        reason: 'no version found in ${entry.key}; update versionedFiles',
      );
      expect(
        found!.group(1),
        version,
        reason: '${entry.key} is not at the version of the pubspec',
      );
    }
  });

  test('the changelog has an entry for the version of the pubspec', () {
    final RegExpMatch? declared = RegExp(
      r'^version: (\S+)$',
      multiLine: true,
    ).firstMatch(File('pubspec.yaml').readAsStringSync());
    final String version = declared!.group(1)!;

    expect(
      File('CHANGELOG.md').readAsLinesSync().first,
      '## $version',
      reason: 'the changelog does not open with the version being released',
    );
  });
}
