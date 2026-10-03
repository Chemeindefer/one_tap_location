// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package com.batuhandelice.one_tap_location

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class LocationRequestCoordinatorTest {
    private val position = Position(
        latitude = 41.0082,
        longitude = 28.9784,
        timestampMillis = 1_757_800_000_000,
        isPrecise = true,
        horizontalAccuracy = 5.0,
        altitude = null,
    )

    private lateinit var events: MutableList<LocationRequestEvent>
    private lateinit var positionRequests: MutableList<PositionRequest>
    private lateinit var coordinator: LocationRequestCoordinator

    @Before
    fun setUp() {
        events = mutableListOf()
        positionRequests = mutableListOf()
        coordinator = createCoordinator { callback ->
            PositionRequest(callback).also { positionRequests += it }
        }
    }

    private fun createCoordinator(positionSource: PositionSource) = LocationRequestCoordinator(
        positionSource = positionSource,
        onEvent = { events += it },
    )

    @Test
    fun reportsThePositionOnceAccessIsGranted() {
        coordinator.onPermissionResult(isGranted = true)
        positionRequests.single().callback(PositionOutcome.Available(position))

        assertEquals(
            listOf(LocationRequestEvent.Locating, LocationRequestEvent.Granted(position)),
            events,
        )
    }

    @Test
    fun reportsADeniedAnswer() {
        coordinator.onPermissionResult(isGranted = false)

        assertEquals(listOf(LocationRequestEvent.Denied), events)
    }

    @Test
    fun reportsADismissedConfirmation() {
        coordinator.onConfirmationDismissed()

        assertEquals(listOf(LocationRequestEvent.TapWithoutAuthorization), events)
    }

    @Test
    fun ignoresADismissedConfirmationWhileLocating() {
        coordinator.onPermissionResult(isGranted = true)
        coordinator.onConfirmationDismissed()

        assertEquals(listOf(LocationRequestEvent.Locating), events)
    }

    @Test
    fun reportsAFailureWhenNoPositionIsAvailable() {
        coordinator.onPermissionResult(isGranted = true)
        positionRequests.single().callback(PositionOutcome.Unavailable)

        assertEquals(
            LocationRequestEvent.Failed(LocationErrorCode.LOCATION_UNAVAILABLE, null),
            events.last(),
        )
    }

    @Test
    fun reportsAFailureWhenLocationServicesAreOff() {
        coordinator.onPermissionResult(isGranted = true)
        positionRequests.single().callback(PositionOutcome.ServicesDisabled)

        assertEquals(
            LocationRequestEvent.Failed(LocationErrorCode.LOCATION_SERVICES_DISABLED, null),
            events.last(),
        )
    }

    @Test
    fun reportsAnUnknownFailureForAnError() {
        coordinator.onPermissionResult(isGranted = true)
        positionRequests.single().callback(PositionOutcome.Error(IllegalStateException("Broken")))

        assertEquals(
            LocationRequestEvent.Failed(LocationErrorCode.UNKNOWN, "Broken"),
            events.last(),
        )
    }

    @Test
    fun reportsDeniedWhenAccessIsRevokedWhileLocating() {
        coordinator.onPermissionResult(isGranted = true)
        positionRequests.single().callback(PositionOutcome.Error(SecurityException()))

        assertEquals(LocationRequestEvent.Denied, events.last())
    }

    @Test
    fun ignoresAnswersWhileLocating() {
        coordinator.onPermissionResult(isGranted = true)
        coordinator.onPermissionResult(isGranted = true)
        coordinator.onPermissionResult(isGranted = false)

        assertEquals(listOf(LocationRequestEvent.Locating), events)
        assertEquals(1, positionRequests.size)
    }

    @Test
    fun dropsThePositionOfADisposedRequest() {
        coordinator.onPermissionResult(isGranted = true)
        coordinator.dispose()
        positionRequests.single().callback(PositionOutcome.Available(position))

        assertTrue(positionRequests.single().isCancelled)
        assertEquals(listOf(LocationRequestEvent.Locating), events)
    }

    @Test
    fun acceptsAPositionThatIsReportedSynchronously() {
        coordinator = createCoordinator { callback ->
            callback(PositionOutcome.Available(position))
            Cancellable { error("A finished request must not be cancelled.") }
        }

        coordinator.onPermissionResult(isGranted = true)
        coordinator.dispose()
        coordinator.onPermissionResult(isGranted = true)

        assertEquals(
            listOf(
                LocationRequestEvent.Locating,
                LocationRequestEvent.Granted(position),
                LocationRequestEvent.Locating,
                LocationRequestEvent.Granted(position),
            ),
            events,
        )
    }

    private class PositionRequest(val callback: (PositionOutcome) -> Unit) : Cancellable {
        var isCancelled = false
            private set

        override fun cancel() {
            isCancelled = true
        }
    }
}
