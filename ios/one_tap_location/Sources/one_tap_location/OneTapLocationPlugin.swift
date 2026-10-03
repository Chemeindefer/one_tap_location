// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import CoreLocationUI
import Flutter
import UIKit

public final class OneTapLocationPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "one_tap_location", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(OneTapLocationPlugin(), channel: channel)
    registrar.register(
      LocationButtonFactory(messenger: registrar.messenger()),
      withId: "one_tap_location/location_button",
      gestureRecognizersBlockingPolicy: FlutterPlatformViewGestureRecognizersBlockingPolicyEager)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getAvailability":
      result([
        "isSystemButtonAvailable": !Self.isiOSAppOnVision,
        "isPreciseLocationRestrictedToSystemButton": false,
      ])
    case "measureButton":
      let button = CLLocationButton()
      LocationButtonStyle(arguments: call.arguments).apply(to: button)
      let size = button.intrinsicContentSize
      result(["width": Double(size.width), "height": Double(size.height)])
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Whether the app is an iPhone or iPad app on Apple Vision Pro, where
  /// `CLLocationButton` ignores taps. Apps built with Xcode 26.1 or later can
  /// detect this from visionOS 26.1 on.
  private static var isiOSAppOnVision: Bool {
    #if compiler(>=6.2.1)
      if #available(iOS 26.1, *) {
        return ProcessInfo.processInfo.isiOSAppOnVision
      }
    #endif
    return false
  }
}
