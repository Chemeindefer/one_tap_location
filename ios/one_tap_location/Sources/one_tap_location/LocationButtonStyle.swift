// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import CoreLocationUI
import UIKit

/// The appearance of a `CLLocationButton`, decoded from the creation
/// parameters of the Dart `OneTapLocationButtonStyle`.
struct LocationButtonStyle {
  var label: CLLocationButtonLabel = .currentLocation
  var icon: CLLocationButtonIcon = .arrowFilled
  var fontSize: CGFloat?
  var cornerRadius: CGFloat?
  var backgroundColor: UIColor?
  var foregroundColor: UIColor?

  init(arguments: Any?) {
    guard let arguments = arguments as? [String: Any] else { return }
    label = Self.label(named: arguments["iosLabel"] as? String)
    icon = Self.icon(named: arguments["iosIcon"] as? String)
    fontSize = (arguments["iosFontSize"] as? NSNumber).map { CGFloat($0.doubleValue) }
    cornerRadius = (arguments["cornerRadius"] as? NSNumber).map { CGFloat($0.doubleValue) }
    backgroundColor = (arguments["backgroundColor"] as? NSNumber).map {
      UIColor(argb: $0.uint32Value)
    }
    foregroundColor = (arguments["foregroundColor"] as? NSNumber).map {
      UIColor(argb: $0.uint32Value)
    }
  }

  /// Applies the style to `button`. Properties without a value take the
  /// defaults of the system, so that a restyled button loses earlier values.
  func apply(to button: CLLocationButton) {
    let defaults = Self.defaultButton
    button.label = label
    button.icon = icon
    button.fontSize = fontSize ?? defaults.fontSize
    button.cornerRadius = cornerRadius ?? defaults.cornerRadius
    // The system ignores taps on a translucent button.
    button.backgroundColor = backgroundColor?.withAlphaComponent(1) ?? defaults.backgroundColor
    button.tintColor = foregroundColor ?? defaults.tintColor
  }

  /// A button that keeps the defaults of the system. Its colors cannot be
  /// restored by setting them to nil.
  private static let defaultButton = CLLocationButton()

  private static func label(named name: String?) -> CLLocationButtonLabel {
    switch name {
    case "none": return CLLocationButtonLabel.none
    case "sendCurrentLocation": return .sendCurrentLocation
    case "sendMyCurrentLocation": return .sendMyCurrentLocation
    case "shareCurrentLocation": return .shareCurrentLocation
    case "shareMyCurrentLocation": return .shareMyCurrentLocation
    default: return .currentLocation
    }
  }

  private static func icon(named name: String?) -> CLLocationButtonIcon {
    switch name {
    case "none": return CLLocationButtonIcon.none
    case "arrowOutline": return .arrowOutline
    default: return .arrowFilled
    }
  }
}

extension UIColor {
  /// Creates a color from a 32-bit ARGB value, as produced by the Dart
  /// `Color.toARGB32()`.
  convenience init(argb: UInt32) {
    self.init(
      red: CGFloat((argb >> 16) & 0xFF) / 255,
      green: CGFloat((argb >> 8) & 0xFF) / 255,
      blue: CGFloat(argb & 0xFF) / 255,
      alpha: CGFloat((argb >> 24) & 0xFF) / 255)
  }
}
