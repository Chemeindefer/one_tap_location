// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import CoreLocation
import UIKit
import XCTest

@testable import one_tap_location

final class LocationRequestCoordinatorTests: XCTestCase {
  private let systemManager = CLLocationManager()
  private var manager: FakeLocationManager!
  private var notificationCenter: NotificationCenter!
  private var recorder: EventRecorder!
  private var locationServicesEnabled = true
  private var defersLocationServicesChecks = false
  private var pendingLocationServicesChecks: [(Bool) -> Void] = []
  private var authorizationWait: AuthorizationWait!

  override func setUp() {
    super.setUp()
    manager = FakeLocationManager()
    notificationCenter = NotificationCenter()
    recorder = EventRecorder()
    locationServicesEnabled = true
    defersLocationServicesChecks = false
    pendingLocationServicesChecks = []
    authorizationWait = AuthorizationWait()
  }

  private func makeCoordinator(
    gracePeriod: TimeInterval = 60,
    schedule: @escaping LocationRequestCoordinator.Scheduler = LocationRequestCoordinator
      .mainQueueScheduler,
    recorder: EventRecorder? = nil
  ) -> LocationRequestCoordinator {
    let coordinator = LocationRequestCoordinator(
      manager: manager, notificationCenter: notificationCenter, gracePeriod: gracePeriod,
      schedule: schedule,
      checkLocationServices: { [unowned self] completion in
        if self.defersLocationServicesChecks {
          self.pendingLocationServicesChecks.append(completion)
        } else {
          completion(self.locationServicesEnabled)
        }
      },
      authorizationWait: authorizationWait)
    coordinator.delegate = recorder ?? self.recorder
    return coordinator
  }

  func testTapWithExistingAuthorizationRequestsLocationImmediately() {
    manager.authorizationStatus = .authorizedWhenInUse
    let coordinator = makeCoordinator()

    coordinator.buttonTapped()

    XCTAssertEqual(manager.requestLocationCount, 1)
    XCTAssertEqual(recorder.events, [.locating])
  }

  func testTapWhileLocatingIsIgnored() {
    manager.authorizationStatus = .authorizedWhenInUse
    let coordinator = makeCoordinator()

    coordinator.buttonTapped()
    coordinator.buttonTapped()

    XCTAssertEqual(manager.requestLocationCount, 1)
    XCTAssertEqual(recorder.events, [.locating])
  }

  func testTapWithRestrictedAuthorizationReportsDenied() {
    manager.authorizationStatus = .restricted
    let coordinator = makeCoordinator()

    coordinator.buttonTapped()

    XCTAssertEqual(manager.requestLocationCount, 0)
    XCTAssertEqual(recorder.events, [.denied])
  }

  func testGrantAfterTapReportsASinglePosition() {
    let coordinator = makeCoordinator()

    coordinator.buttonTapped()
    XCTAssertEqual(manager.requestLocationCount, 0)

    manager.authorizationStatus = .authorizedWhenInUse
    coordinator.locationManagerDidChangeAuthorization(systemManager)
    let location = CLLocation(latitude: 41.0082, longitude: 28.9784)
    coordinator.locationManager(systemManager, didUpdateLocations: [location])
    coordinator.locationManager(systemManager, didUpdateLocations: [location])

    XCTAssertEqual(manager.requestLocationCount, 1)
    XCTAssertEqual(recorder.events, [.locating, .granted(isPrecise: true)])
  }

  func testReducedAccuracyIsReportedAsApproximate() {
    manager.authorizationStatus = .authorizedWhenInUse
    manager.accuracyAuthorization = .reducedAccuracy
    let coordinator = makeCoordinator()

    coordinator.buttonTapped()
    coordinator.locationManager(
      systemManager, didUpdateLocations: [CLLocation(latitude: 41, longitude: 29)])

    XCTAssertEqual(recorder.events, [.locating, .granted(isPrecise: false)])
  }

  func testAuthorizationChangeWithoutTapIsIgnored() {
    let coordinator = makeCoordinator()

    manager.authorizationStatus = .authorizedWhenInUse
    coordinator.locationManagerDidChangeAuthorization(systemManager)

    XCTAssertEqual(manager.requestLocationCount, 0)
    XCTAssertEqual(recorder.events, [])
  }

  func testDenialAfterTapReportsDenied() {
    let coordinator = makeCoordinator()

    coordinator.buttonTapped()
    manager.authorizationStatus = .denied
    coordinator.locationManagerDidChangeAuthorization(systemManager)

    XCTAssertEqual(recorder.events, [.denied])
  }

  func testDeniedLocationErrorReportsDenied() {
    manager.authorizationStatus = .authorizedWhenInUse
    let coordinator = makeCoordinator()

    coordinator.buttonTapped()
    coordinator.locationManager(systemManager, didFailWithError: CLError(.denied))

    XCTAssertEqual(recorder.events, [.locating, .denied])
  }

  func testLocationErrorReportsFailure() {
    manager.authorizationStatus = .authorizedWhenInUse
    let coordinator = makeCoordinator()

    coordinator.buttonTapped()
    coordinator.locationManager(systemManager, didFailWithError: CLError(.locationUnknown))

    XCTAssertEqual(recorder.events, [.locating, .failed(.locationUnknown)])
  }

  func testTapWithLocationServicesDisabledReportsFailure() {
    manager.authorizationStatus = .denied
    locationServicesEnabled = false
    let coordinator = makeCoordinator(gracePeriod: 0.05)
    let diagnostic = expectation(description: "no diagnostic")
    diagnostic.isInverted = true
    recorder.onEvent = { event in
      if event == .tapWithoutAuthorization { diagnostic.fulfill() }
    }

    coordinator.buttonTapped()
    wait(for: [diagnostic], timeout: 0.2)

    XCTAssertEqual(manager.requestLocationCount, 0)
    XCTAssertEqual(recorder.events, [.locationServicesDisabled])
  }

  func testDenialWithLocationServicesDisabledReportsFailure() {
    let coordinator = makeCoordinator()

    coordinator.buttonTapped()
    locationServicesEnabled = false
    manager.authorizationStatus = .denied
    coordinator.locationManagerDidChangeAuthorization(systemManager)

    XCTAssertEqual(recorder.events, [.locationServicesDisabled])
  }

  func testDeniedLocationErrorWithLocationServicesDisabledReportsFailure() {
    manager.authorizationStatus = .authorizedWhenInUse
    let coordinator = makeCoordinator()

    coordinator.buttonTapped()
    locationServicesEnabled = false
    coordinator.locationManager(systemManager, didFailWithError: CLError(.denied))

    XCTAssertEqual(recorder.events, [.locating, .locationServicesDisabled])
  }

  func testLocationServicesAnswerAfterAGrantIsIgnored() {
    defersLocationServicesChecks = true
    let coordinator = makeCoordinator()

    coordinator.buttonTapped()
    manager.authorizationStatus = .authorizedWhenInUse
    coordinator.locationManagerDidChangeAuthorization(systemManager)
    for check in pendingLocationServicesChecks {
      check(false)
    }

    XCTAssertEqual(manager.requestLocationCount, 1)
    XCTAssertEqual(recorder.events, [.locating])
  }

  func testUnansweredTapReportsDiagnosticAndStillDeliversALaterGrant() {
    let coordinator = makeCoordinator(gracePeriod: 0.05)
    let diagnostic = expectation(description: "tapWithoutAuthorization")
    recorder.onEvent = { event in
      if event == .tapWithoutAuthorization { diagnostic.fulfill() }
    }

    coordinator.buttonTapped()
    wait(for: [diagnostic], timeout: 1)

    manager.authorizationStatus = .authorizedWhenInUse
    coordinator.locationManagerDidChangeAuthorization(systemManager)

    XCTAssertEqual(manager.requestLocationCount, 1)
    XCTAssertEqual(recorder.events, [.tapWithoutAuthorization, .locating])
  }

  func testRepeatedTapRestartsTheGracePeriod() {
    var gracePeriods: [(delay: TimeInterval, workItem: DispatchWorkItem)] = []
    let coordinator = makeCoordinator(
      gracePeriod: 5, schedule: { gracePeriods.append((delay: $0, workItem: $1)) })

    coordinator.buttonTapped()
    coordinator.buttonTapped()

    XCTAssertEqual(gracePeriods.map(\.delay), [5, 5])
    XCTAssertTrue(gracePeriods[0].workItem.isCancelled)
    XCTAssertFalse(gracePeriods[1].workItem.isCancelled)
    XCTAssertEqual(recorder.events, [])

    gracePeriods[1].workItem.perform()

    XCTAssertEqual(recorder.events, [.tapWithoutAuthorization])
  }

  func testOnlyTheButtonTappedLastLocatesAfterAGrant() {
    let earlierRecorder = EventRecorder()
    let earlier = makeCoordinator(recorder: earlierRecorder)
    let later = makeCoordinator()

    earlier.buttonTapped()
    later.buttonTapped()
    manager.authorizationStatus = .authorizedWhenInUse
    earlier.locationManagerDidChangeAuthorization(systemManager)
    later.locationManagerDidChangeAuthorization(systemManager)

    XCTAssertEqual(manager.requestLocationCount, 1)
    XCTAssertEqual(earlierRecorder.events, [])
    XCTAssertEqual(recorder.events, [.locating])
  }

  func testGrantAfterReturningFromTheBackgroundIsReported() {
    let coordinator = makeCoordinator()

    // The first-use alert stays on screen while the user switches apps.
    coordinator.buttonTapped()
    notificationCenter.post(name: UIApplication.willResignActiveNotification, object: nil)
    notificationCenter.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
    notificationCenter.post(name: UIApplication.didBecomeActiveNotification, object: nil)
    manager.authorizationStatus = .authorizedWhenInUse
    coordinator.locationManagerDidChangeAuthorization(systemManager)

    XCTAssertEqual(manager.requestLocationCount, 1)
    XCTAssertEqual(recorder.events, [.locating])
  }

  func testInactiveApplicationDefersDiagnostic() {
    let coordinator = makeCoordinator(gracePeriod: 0.05)
    let deferred = expectation(description: "no diagnostic while inactive")
    deferred.isInverted = true
    recorder.onEvent = { event in
      if event == .tapWithoutAuthorization { deferred.fulfill() }
    }

    coordinator.buttonTapped()
    notificationCenter.post(name: UIApplication.willResignActiveNotification, object: nil)
    wait(for: [deferred], timeout: 0.2)

    let reported = expectation(description: "diagnostic after becoming active")
    recorder.onEvent = { event in
      if event == .tapWithoutAuthorization { reported.fulfill() }
    }
    notificationCenter.post(name: UIApplication.didBecomeActiveNotification, object: nil)
    wait(for: [reported], timeout: 1)
  }

  func testDiagnosticIsNotRepeatedAfterReturningToTheApp() {
    let coordinator = makeCoordinator(gracePeriod: 0.05)
    let reported = expectation(description: "first diagnostic")
    recorder.onEvent = { event in
      if event == .tapWithoutAuthorization { reported.fulfill() }
    }

    coordinator.buttonTapped()
    wait(for: [reported], timeout: 1)

    let repeated = expectation(description: "no second diagnostic")
    repeated.isInverted = true
    recorder.onEvent = { event in
      if event == .tapWithoutAuthorization { repeated.fulfill() }
    }
    notificationCenter.post(name: UIApplication.willResignActiveNotification, object: nil)
    notificationCenter.post(name: UIApplication.didBecomeActiveNotification, object: nil)
    wait(for: [repeated], timeout: 0.3)
  }
}

private final class FakeLocationManager: LocationManaging {
  weak var delegate: CLLocationManagerDelegate?
  var desiredAccuracy: CLLocationAccuracy = kCLLocationAccuracyHundredMeters
  var authorizationStatus: CLAuthorizationStatus = .notDetermined
  var accuracyAuthorization: CLAccuracyAuthorization = .fullAccuracy
  private(set) var requestLocationCount = 0

  func requestLocation() {
    requestLocationCount += 1
  }
}

private final class EventRecorder: LocationRequestCoordinatorDelegate {
  enum Event: Equatable {
    case locating
    case granted(isPrecise: Bool)
    case denied
    case failed(CLError.Code?)
    case locationServicesDisabled
    case tapWithoutAuthorization
  }

  private(set) var events: [Event] = []
  var onEvent: ((Event) -> Void)?

  func locationRequestCoordinator(
    _ coordinator: LocationRequestCoordinator,
    didProduce event: LocationRequestEvent
  ) {
    let recorded: Event
    switch event {
    case .locating: recorded = .locating
    case .granted(_, let isPrecise): recorded = .granted(isPrecise: isPrecise)
    case .denied: recorded = .denied
    case .failed(let error): recorded = .failed((error as? CLError)?.code)
    case .locationServicesDisabled: recorded = .locationServicesDisabled
    case .tapWithoutAuthorization: recorded = .tapWithoutAuthorization
    }
    events.append(recorded)
    onEvent?(recorded)
  }
}
