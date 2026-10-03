// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import CoreLocation

/// Converts coordinator events into the channel messages that the Dart side of
/// the plugin understands.
enum LocationCodec {
  struct Message {
    let method: String
    let arguments: [String: Any]?
  }

  static func message(for event: LocationRequestEvent) -> Message {
    switch event {
    case .locating:
      return Message(method: "onLocating", arguments: nil)
    case .granted(let location, let isPrecise):
      return Message(
        method: "onResult",
        arguments: [
          "status": "granted",
          "position": position(from: location, isPrecise: isPrecise),
        ])
    case .denied:
      return Message(method: "onResult", arguments: ["status": "denied"])
    case .failed(let error):
      return Message(
        method: "onResult",
        arguments: [
          "status": "failed",
          "code": errorCode(for: error),
          "message": message(for: error),
        ])
    case .locationServicesDisabled:
      return Message(
        method: "onResult",
        arguments: ["status": "failed", "code": "locationServicesDisabled"])
    case .tapWithoutAuthorization:
      return Message(
        method: "onDiagnostic", arguments: ["diagnostic": "tapWithoutAuthorization"])
    }
  }

  static func position(from location: CLLocation, isPrecise: Bool) -> [String: Any] {
    var position: [String: Any] = [
      "latitude": location.coordinate.latitude,
      "longitude": location.coordinate.longitude,
      "timestamp": Int64((location.timestamp.timeIntervalSince1970 * 1000).rounded()),
      "isPrecise": isPrecise,
    ]
    if location.horizontalAccuracy >= 0 {
      position["horizontalAccuracy"] = location.horizontalAccuracy
    }
    // Approximate positions have no altitude, as on Android.
    if isPrecise && location.verticalAccuracy > 0 {
      position["altitude"] = location.altitude
    }
    return position
  }

  /// Describes `error` for logs. The localized description would change with
  /// the language of the app.
  static func message(for error: Error) -> String {
    let error = error as NSError
    return "\(error.domain) error \(error.code)"
  }

  static func errorCode(for error: Error) -> String {
    switch (error as? CLError)?.code {
    case .locationUnknown?, .network?:
      return "locationUnavailable"
    default:
      return "unknown"
    }
  }
}
