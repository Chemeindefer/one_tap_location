// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import CoreLocationUI
import UIKit
import XCTest

@testable import one_tap_location

final class LocationButtonStyleTests: XCTestCase {
  func testDecodesEveryProperty() {
    let style = LocationButtonStyle(arguments: [
      "iosLabel": "shareMyCurrentLocation",
      "iosIcon": "arrowOutline",
      "iosFontSize": 20.0,
      "cornerRadius": 12.0,
      "backgroundColor": NSNumber(value: UInt32(0xFF33_66FF)),
      "foregroundColor": NSNumber(value: UInt32(0xFFFF_FFFF)),
    ])

    XCTAssertEqual(style.label, .shareMyCurrentLocation)
    XCTAssertEqual(style.icon, .arrowOutline)
    XCTAssertEqual(style.fontSize, 20)
    XCTAssertEqual(style.cornerRadius, 12)
    XCTAssertEqual(style.backgroundColor, UIColor(red: 0.2, green: 0.4, blue: 1, alpha: 1))
    XCTAssertEqual(style.foregroundColor, UIColor(red: 1, green: 1, blue: 1, alpha: 1))
  }

  func testUsesSystemDefaultsForMissingArguments() {
    let style = LocationButtonStyle(arguments: nil)

    XCTAssertEqual(style.label, .currentLocation)
    XCTAssertEqual(style.icon, .arrowFilled)
    XCTAssertNil(style.fontSize)
    XCTAssertNil(style.cornerRadius)
    XCTAssertNil(style.backgroundColor)
    XCTAssertNil(style.foregroundColor)
  }

  func testRestylingReturnsMissingPropertiesToTheSystemDefaults() {
    let button = CLLocationButton()
    let pristine = CLLocationButton()
    let defaults = CLLocationButton()
    LocationButtonStyle(arguments: nil).apply(to: defaults)

    LocationButtonStyle(arguments: [
      "iosFontSize": 30.0,
      "cornerRadius": 12.0,
      "backgroundColor": NSNumber(value: UInt32(0xFF33_66FF)),
      "foregroundColor": NSNumber(value: UInt32(0xFF00_0000)),
    ]).apply(to: button)
    LocationButtonStyle(arguments: nil).apply(to: button)

    XCTAssertEqual(button.fontSize, pristine.fontSize)
    XCTAssertEqual(button.cornerRadius, pristine.cornerRadius)
    XCTAssertNotNil(button.backgroundColor)
    XCTAssertEqual(button.backgroundColor, pristine.backgroundColor)
    XCTAssertNotNil(button.tintColor)
    XCTAssertEqual(button.tintColor, pristine.tintColor)
    XCTAssertEqual(button.intrinsicContentSize, defaults.intrinsicContentSize)
  }

  func testAppliesAnOpaqueBackground() {
    let button = CLLocationButton()

    LocationButtonStyle(arguments: ["backgroundColor": NSNumber(value: UInt32(0x8033_66FF))])
      .apply(to: button)

    var alpha: CGFloat = 0
    button.backgroundColor?.getRed(nil, green: nil, blue: nil, alpha: &alpha)
    XCTAssertEqual(alpha, 1)
  }
}
