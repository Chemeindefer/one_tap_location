// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tracks the coordinator whose tap waits for the system to grant access.
///
/// Authorization belongs to the app, so the location manager of every button
/// reports each change. Only the button tapped last can have caused a grant, so
/// a tap on another button ends the wait of the previous one.
final class AuthorizationWait {
  static let shared = AuthorizationWait()

  private weak var coordinator: LocationRequestCoordinator?

  func begin(for coordinator: LocationRequestCoordinator) {
    if let waitingCoordinator = self.coordinator, waitingCoordinator !== coordinator {
      waitingCoordinator.stopWaitingForAuthorization()
    }
    self.coordinator = coordinator
  }

  func end(for coordinator: LocationRequestCoordinator) {
    if self.coordinator === coordinator {
      self.coordinator = nil
    }
  }
}
