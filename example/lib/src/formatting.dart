// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Keeps a number with its unit, and a separator with the text before it, on
/// the same line.
const String _noBreakSpace = '\u00A0';

/// Formats [latitude] in degrees with its hemisphere, such as `41.025510° N`.
String formatLatitude(double latitude) {
  return _formatCoordinate(latitude, positive: 'N', negative: 'S');
}

/// Formats [longitude] in degrees with its hemisphere, such as `28.975380° E`.
String formatLongitude(double longitude) {
  return _formatCoordinate(longitude, positive: 'E', negative: 'W');
}

String _formatCoordinate(
  double degrees, {
  required String positive,
  required String negative,
}) {
  final String hemisphere = degrees < 0 ? negative : positive;
  return '${degrees.abs().toStringAsFixed(6)}° $hemisphere';
}

/// Formats a distance in meters, such as `41.2 m`, with a no-break space
/// before the unit.
String formatMeters(double meters) {
  return '${meters.toStringAsFixed(1)}${_noBreakSpace}m';
}

/// Formats [timestamp] as local time followed by its age at [now], such as
/// `14:32:07 · 9 min ago`, with no-break spaces before the separator and
/// before the unit of the age.
String formatTimestamp(DateTime timestamp, DateTime now) {
  final DateTime local = timestamp.toLocal();
  final String time = <int>[
    local.hour,
    local.minute,
    local.second,
  ].map((int part) => part.toString().padLeft(2, '0')).join(':');
  final Duration age = now.difference(timestamp);
  final String relative;
  if (age.inMinutes < 1) {
    relative = 'just now';
  } else if (age.inHours < 1) {
    relative = '${age.inMinutes}${_noBreakSpace}min ago';
  } else {
    relative = '${age.inHours}${_noBreakSpace}h ago';
  }
  return '$time$_noBreakSpace· $relative';
}
