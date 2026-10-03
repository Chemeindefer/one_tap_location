// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Flutter
import XCTest

@testable import one_tap_location

final class OneTapLocationPluginTests: XCTestCase {
  private func measure(arguments: Any?) -> [String: Double]? {
    var size: [String: Double]?
    OneTapLocationPlugin().handle(
      FlutterMethodCall(methodName: "measureButton", arguments: arguments)
    ) { result in
      size = result as? [String: Double]
    }
    return size
  }

  func testGetAvailabilityReportsTheSystemButton() {
    var availability: [String: Bool]?
    OneTapLocationPlugin().handle(
      FlutterMethodCall(methodName: "getAvailability", arguments: nil)
    ) { result in
      availability = result as? [String: Bool]
    }

    XCTAssertEqual(
      availability,
      ["isSystemButtonAvailable": true, "isPreciseLocationRestrictedToSystemButton": false])
  }

  func testMeasureButtonReportsAPositiveSize() {
    let size = measure(arguments: nil)

    XCTAssertGreaterThan(size?["width"] ?? 0, 0)
    XCTAssertGreaterThan(size?["height"] ?? 0, 0)
  }

  func testMeasureButtonGrowsWithTheFontSize() {
    let regular = measure(arguments: ["iosFontSize": 17.0])
    let large = measure(arguments: ["iosFontSize": 34.0])

    XCTAssertGreaterThan(large?["height"] ?? 0, regular?["height"] ?? 0)
  }

  func testUnknownMethodIsNotImplemented() {
    var reply: Any?
    OneTapLocationPlugin().handle(FlutterMethodCall(methodName: "unknown", arguments: nil)) {
      result in
      reply = result
    }

    XCTAssertTrue((reply as AnyObject) === FlutterMethodNotImplemented)
  }
}
