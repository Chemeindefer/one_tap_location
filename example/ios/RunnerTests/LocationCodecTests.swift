// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import CoreLocation
import XCTest

@testable import one_tap_location

final class LocationCodecTests: XCTestCase {
  func testEncodesLocatingMessage() {
    let message = LocationCodec.message(for: .locating)

    XCTAssertEqual(message.method, "onLocating")
    XCTAssertNil(message.arguments)
  }

  func testEncodesGrantedMessage() {
    let location = CLLocation(latitude: 41.0082, longitude: 28.9784)

    let message = LocationCodec.message(for: .granted(location, isPrecise: true))

    XCTAssertEqual(message.method, "onResult")
    XCTAssertEqual(message.arguments?["status"] as? String, "granted")
    let position = message.arguments?["position"] as? [String: Any]
    XCTAssertEqual(position?["latitude"] as? Double, 41.0082)
    XCTAssertEqual(position?["isPrecise"] as? Bool, true)
  }

  func testEncodesDeniedMessage() {
    let message = LocationCodec.message(for: .denied)

    XCTAssertEqual(message.method, "onResult")
    XCTAssertEqual(message.arguments?["status"] as? String, "denied")
  }

  func testEncodesFailedMessage() {
    let message = LocationCodec.message(for: .failed(CLError(.locationUnknown)))

    XCTAssertEqual(message.method, "onResult")
    XCTAssertEqual(message.arguments?["status"] as? String, "failed")
    XCTAssertEqual(message.arguments?["code"] as? String, "locationUnavailable")
    XCTAssertEqual(message.arguments?["message"] as? String, "kCLErrorDomain error 0")
  }

  func testEncodesLocationServicesDisabledMessage() {
    let message = LocationCodec.message(for: .locationServicesDisabled)

    XCTAssertEqual(message.method, "onResult")
    XCTAssertEqual(message.arguments?["status"] as? String, "failed")
    XCTAssertEqual(message.arguments?["code"] as? String, "locationServicesDisabled")
    XCTAssertNil(message.arguments?["message"])
  }

  func testEncodesDiagnosticMessage() {
    let message = LocationCodec.message(for: .tapWithoutAuthorization)

    XCTAssertEqual(message.method, "onDiagnostic")
    XCTAssertEqual(message.arguments?["diagnostic"] as? String, "tapWithoutAuthorization")
  }

  func testEncodesPosition() {
    let location = CLLocation(
      coordinate: CLLocationCoordinate2D(latitude: 41.0082, longitude: 28.9784),
      altitude: 39.5, horizontalAccuracy: 5, verticalAccuracy: 3,
      timestamp: Date(timeIntervalSince1970: 1_757_800_000))

    let position = LocationCodec.position(from: location, isPrecise: true)

    XCTAssertEqual(position["latitude"] as? Double, 41.0082)
    XCTAssertEqual(position["longitude"] as? Double, 28.9784)
    XCTAssertEqual(position["timestamp"] as? Int64, 1_757_800_000_000)
    XCTAssertEqual(position["isPrecise"] as? Bool, true)
    XCTAssertEqual(position["horizontalAccuracy"] as? Double, 5)
    XCTAssertEqual(position["altitude"] as? Double, 39.5)
  }

  func testOmitsInvalidAccuracyAndAltitude() {
    let location = CLLocation(
      coordinate: CLLocationCoordinate2D(latitude: 41, longitude: 29),
      altitude: 0, horizontalAccuracy: -1, verticalAccuracy: -1, timestamp: Date())

    let position = LocationCodec.position(from: location, isPrecise: true)

    XCTAssertNil(position["horizontalAccuracy"])
    XCTAssertNil(position["altitude"])
  }

  func testOmitsAltitudeOfApproximatePosition() {
    let location = CLLocation(
      coordinate: CLLocationCoordinate2D(latitude: 41.0082, longitude: 28.9784),
      altitude: 39.5, horizontalAccuracy: 2000, verticalAccuracy: 3,
      timestamp: Date(timeIntervalSince1970: 1_757_800_000))

    let position = LocationCodec.position(from: location, isPrecise: false)

    XCTAssertEqual(position["isPrecise"] as? Bool, false)
    XCTAssertEqual(position["horizontalAccuracy"] as? Double, 2000)
    XCTAssertNil(position["altitude"])
  }

  func testMapsErrorCodes() {
    XCTAssertEqual(LocationCodec.errorCode(for: CLError(.locationUnknown)), "locationUnavailable")
    XCTAssertEqual(LocationCodec.errorCode(for: CLError(.network)), "locationUnavailable")
    XCTAssertEqual(LocationCodec.errorCode(for: CLError(.headingFailure)), "unknown")
    XCTAssertEqual(LocationCodec.errorCode(for: NSError(domain: "test", code: 1)), "unknown")
  }
}
