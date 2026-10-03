// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import CoreLocationUI
import Flutter
import UIKit

/// Hosts a `CLLocationButton` in a Flutter platform view and forwards the
/// outcome of each tap to Dart.
final class LocationButtonPlatformView: NSObject, FlutterPlatformView {
  private let button = CLLocationButton()
  private let channel: FlutterMethodChannel
  private let coordinator = LocationRequestCoordinator()

  init(
    frame: CGRect,
    viewIdentifier: Int64,
    arguments: Any?,
    messenger: FlutterBinaryMessenger
  ) {
    channel = FlutterMethodChannel(
      name: "one_tap_location/location_button/\(viewIdentifier)",
      binaryMessenger: messenger)
    super.init()
    LocationButtonStyle(arguments: arguments).apply(to: button)
    button.frame = frame
    button.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
    coordinator.delegate = self
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterMethodNotImplemented)
        return
      }
      self.handle(call, result: result)
    }
  }

  deinit {
    channel.setMethodCallHandler(nil)
  }

  func view() -> UIView {
    button
  }

  private func handle(_ call: FlutterMethodCall, result: FlutterResult) {
    switch call.method {
    case "setStyle":
      // The button is restyled in place, which keeps a request in progress.
      LocationButtonStyle(arguments: call.arguments).apply(to: button)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  @objc private func buttonTapped() {
    coordinator.buttonTapped()
  }
}

extension LocationButtonPlatformView: LocationRequestCoordinatorDelegate {
  func locationRequestCoordinator(
    _ coordinator: LocationRequestCoordinator,
    didProduce event: LocationRequestEvent
  ) {
    let message = LocationCodec.message(for: event)
    channel.invokeMethod(message.method, arguments: message.arguments)
  }
}
