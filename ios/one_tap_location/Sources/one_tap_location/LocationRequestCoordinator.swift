// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import CoreLocation
import UIKit

protocol LocationManaging: AnyObject {
  var delegate: CLLocationManagerDelegate? { get set }
  var desiredAccuracy: CLLocationAccuracy { get set }
  var authorizationStatus: CLAuthorizationStatus { get }
  var accuracyAuthorization: CLAccuracyAuthorization { get }

  func requestLocation()
}

extension CLLocationManager: LocationManaging {}

enum LocationRequestEvent {
  case locating
  case granted(CLLocation, isPrecise: Bool)
  case denied
  case failed(Error)
  case locationServicesDisabled
  case tapWithoutAuthorization
}

protocol LocationRequestCoordinatorDelegate: AnyObject {
  func locationRequestCoordinator(
    _ coordinator: LocationRequestCoordinator,
    didProduce event: LocationRequestEvent)
}

/// Turns taps on a `CLLocationButton` into a single location request.
///
/// The button reports a tap before the system decides whether to grant access,
/// so the coordinator waits for the authorization change before requesting the
/// location. A tap that the system ignores produces no authorization change;
/// once the grace period passes, the coordinator reports
/// `tapWithoutAuthorization` and keeps waiting.
///
/// With location services turned off, the system denies the tap without an
/// alert and without an authorization change, so the coordinator checks
/// whether location services are enabled whenever access is missing.
///
/// Only the coordinator of the button tapped last waits for authorization.
final class LocationRequestCoordinator: NSObject {
  /// Answers whether location services are enabled, on the main queue.
  typealias LocationServicesCheck = (@escaping (Bool) -> Void) -> Void

  /// Performs a work item on the main queue once a delay has passed.
  typealias Scheduler = (TimeInterval, DispatchWorkItem) -> Void

  static let defaultGracePeriod: TimeInterval = 5

  static let mainQueueScheduler: Scheduler = { delay, workItem in
    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
  }

  /// Checks off the main queue, where CoreLocation warns that the check can
  /// make the interface unresponsive.
  static let systemLocationServicesCheck: LocationServicesCheck = { completion in
    DispatchQueue.global(qos: .userInitiated).async {
      let isEnabled = CLLocationManager.locationServicesEnabled()
      DispatchQueue.main.async { completion(isEnabled) }
    }
  }

  weak var delegate: LocationRequestCoordinatorDelegate?

  private enum State {
    case idle
    case awaitingAuthorization
    case locating
  }

  private let manager: LocationManaging
  private let notificationCenter: NotificationCenter
  private let gracePeriod: TimeInterval
  private let schedule: Scheduler
  private let checkLocationServices: LocationServicesCheck
  private let authorizationWait: AuthorizationWait
  private var state = State.idle
  private var requestGeneration = 0
  private var hasReportedTapWithoutAuthorization = false
  private var graceTimer: DispatchWorkItem?

  init(
    manager: LocationManaging = CLLocationManager(),
    notificationCenter: NotificationCenter = .default,
    gracePeriod: TimeInterval = LocationRequestCoordinator.defaultGracePeriod,
    schedule: @escaping Scheduler = LocationRequestCoordinator.mainQueueScheduler,
    checkLocationServices: @escaping LocationServicesCheck = LocationRequestCoordinator
      .systemLocationServicesCheck,
    authorizationWait: AuthorizationWait = .shared
  ) {
    self.manager = manager
    self.notificationCenter = notificationCenter
    self.gracePeriod = gracePeriod
    self.schedule = schedule
    self.checkLocationServices = checkLocationServices
    self.authorizationWait = authorizationWait
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyBest
    notificationCenter.addObserver(
      self, selector: #selector(applicationWillResignActive),
      name: UIApplication.willResignActiveNotification, object: nil)
    notificationCenter.addObserver(
      self, selector: #selector(applicationDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification, object: nil)
  }

  deinit {
    notificationCenter.removeObserver(self)
    graceTimer?.cancel()
  }

  func buttonTapped() {
    guard state != .locating else { return }
    requestGeneration += 1
    let status = manager.authorizationStatus
    if status.grantsLocation {
      startLocating()
    } else if status == .restricted {
      // A restriction set by a device policy cannot be lifted from the button.
      finish(with: .denied)
    } else {
      state = .awaitingAuthorization
      hasReportedTapWithoutAuthorization = false
      authorizationWait.begin(for: self)
      scheduleGraceTimer()
      whenLocationServicesAreChecked { [weak self] isEnabled in
        if !isEnabled {
          self?.finish(with: .locationServicesDisabled)
        }
      }
    }
  }

  /// Ends a wait for authorization without an event, so that a later grant does
  /// not produce a result for the tap.
  func stopWaitingForAuthorization() {
    guard state == .awaitingAuthorization else { return }
    cancelGraceTimer()
    authorizationWait.end(for: self)
    requestGeneration += 1
    state = .idle
  }

  private func startLocating() {
    cancelGraceTimer()
    authorizationWait.end(for: self)
    state = .locating
    report(.locating)
    manager.requestLocation()
  }

  /// Reports a denial, or disabled location services, which deny access too.
  private func finishWithDenial() {
    cancelGraceTimer()
    whenLocationServicesAreChecked { [weak self] isEnabled in
      self?.finish(with: isEnabled ? .denied : .locationServicesDisabled)
    }
  }

  /// Calls `action` with the result of the check unless the request has moved
  /// on in the meantime.
  private func whenLocationServicesAreChecked(_ action: @escaping (Bool) -> Void) {
    let generation = requestGeneration
    let checkedState = state
    checkLocationServices { [weak self] isEnabled in
      guard let self, self.requestGeneration == generation, self.state == checkedState else {
        return
      }
      action(isEnabled)
    }
  }

  private func finish(with event: LocationRequestEvent) {
    cancelGraceTimer()
    authorizationWait.end(for: self)
    state = .idle
    report(event)
  }

  private func report(_ event: LocationRequestEvent) {
    delegate?.locationRequestCoordinator(self, didProduce: event)
  }

  private func scheduleGraceTimer() {
    cancelGraceTimer()
    let timer = DispatchWorkItem { [weak self] in
      guard let self, self.state == .awaitingAuthorization else { return }
      self.graceTimer = nil
      self.hasReportedTapWithoutAuthorization = true
      self.report(.tapWithoutAuthorization)
    }
    graceTimer = timer
    schedule(gracePeriod, timer)
  }

  private func cancelGraceTimer() {
    graceTimer?.cancel()
    graceTimer = nil
  }

  @objc private func applicationWillResignActive() {
    // The first tap presents a system confirmation, which makes the app
    // inactive until the user answers it.
    cancelGraceTimer()
  }

  @objc private func applicationDidBecomeActive() {
    if state == .awaitingAuthorization && !hasReportedTapWithoutAuthorization {
      scheduleGraceTimer()
    }
  }
}

extension LocationRequestCoordinator: CLLocationManagerDelegate {
  func locationManagerDidChangeAuthorization(_ locationManager: CLLocationManager) {
    guard state == .awaitingAuthorization else { return }
    let status = manager.authorizationStatus
    if status.grantsLocation {
      startLocating()
    } else if status == .denied || status == .restricted {
      finishWithDenial()
    }
  }

  func locationManager(
    _ locationManager: CLLocationManager, didUpdateLocations locations: [CLLocation]
  ) {
    guard state == .locating, let location = locations.last else { return }
    finish(with: .granted(location, isPrecise: manager.accuracyAuthorization == .fullAccuracy))
  }

  func locationManager(_ locationManager: CLLocationManager, didFailWithError error: Error) {
    guard state == .locating else { return }
    if (error as? CLError)?.code == .denied {
      finishWithDenial()
    } else {
      finish(with: .failed(error))
    }
  }
}

extension CLAuthorizationStatus {
  fileprivate var grantsLocation: Bool {
    self == .authorizedWhenInUse || self == .authorizedAlways
  }
}
