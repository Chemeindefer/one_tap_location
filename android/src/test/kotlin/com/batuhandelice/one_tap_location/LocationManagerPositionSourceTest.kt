// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package com.batuhandelice.one_tap_location

import android.location.LocationManager
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class LocationManagerPositionSourceTest {
    private val position = Position(
        latitude = 41.0082,
        longitude = 28.9784,
        timestampMillis = 1_757_800_000_000,
        isPrecise = false,
        horizontalAccuracy = 2_000.0,
        altitude = null,
    )
    private val precisePosition = position.copy(
        isPrecise = true,
        horizontalAccuracy = 5.0,
        ellipsoidalAltitude = 250.0,
    )
    private val backend = FakeBackend()
    private val scheduler = FakeScheduler()
    private val source = LocationManagerPositionSource(backend, scheduler)
    private val outcomes = mutableListOf<PositionOutcome>()

    private fun request(): Cancellable = source.requestPosition { outcomes += it }

    @Test
    fun reportsDisabledLocationServicesBeforeLookingForAPosition() {
        backend.isLocationEnabled = false
        backend.isPreciseAccessGranted = false
        backend.knownPositions[LocationManager.FUSED_PROVIDER] = KnownPosition(position, 1_000)

        request()

        assertEquals(listOf(PositionOutcome.ServicesDisabled), outcomes)
        assertTrue(backend.lastKnownReads.isEmpty())
        assertTrue(backend.requests.isEmpty())
    }

    @Test
    fun reportsARecentKnownPositionWithApproximateAccess() {
        backend.isPreciseAccessGranted = false
        backend.knownPositions[LocationManager.FUSED_PROVIDER] = KnownPosition(position, 120_000)

        request()

        assertEquals(listOf(PositionOutcome.Available(position)), outcomes)
        assertTrue(backend.requests.isEmpty())
        assertTrue(scheduler.tasks.isEmpty())
    }

    @Test
    fun requestsAPositionWhenTheKnownOneIsTooOld() {
        backend.isPreciseAccessGranted = false
        backend.knownPositions[LocationManager.FUSED_PROVIDER] = KnownPosition(position, 600_001)

        request()
        backend.requests.single().callback(PositionOutcome.Available(position))

        assertEquals(LocationManager.FUSED_PROVIDER, backend.requests.single().provider)
        assertEquals(listOf(PositionOutcome.Available(position)), outcomes)
    }

    @Test
    fun ignoresKnownPositionsWithPreciseAccess() {
        backend.knownPositions[LocationManager.FUSED_PROVIDER] = KnownPosition(position, 1_000)

        request()

        assertTrue(outcomes.isEmpty())
        assertTrue(backend.lastKnownReads.isEmpty())
        assertEquals(LocationManager.FUSED_PROVIDER, backend.requests.single().provider)
    }

    @Test
    fun reportsTheFirstPositionOfTheProvidersWithoutAFusedProvider() {
        backend.hasFusedProvider = false

        request()
        val gps = backend.requests.single { it.provider == LocationManager.GPS_PROVIDER }
        val network = backend.requests.single { it.provider == LocationManager.NETWORK_PROVIDER }
        network.callback(PositionOutcome.Available(position))

        assertEquals(listOf(PositionOutcome.Available(position)), outcomes)
        assertTrue(gps.isCancelled)
    }

    @Test
    fun usesAKnownPositionOfTheNetworkProviderWithApproximateAccess() {
        backend.hasFusedProvider = false
        backend.isPreciseAccessGranted = false
        backend.knownPositions[LocationManager.GPS_PROVIDER] = KnownPosition(position, 1_000)
        backend.knownPositions[LocationManager.NETWORK_PROVIDER] = KnownPosition(position, 300_000)

        request()

        assertEquals(listOf(LocationManager.NETWORK_PROVIDER), backend.lastKnownReads)
        assertEquals(listOf(PositionOutcome.Available(position)), outcomes)
    }

    @Test
    fun reportsAnUnavailablePositionAfterTheTimeout() {
        request()

        val timeout = scheduler.tasks.single()
        timeout.run()

        assertEquals(POSITION_TIMEOUT_MILLIS, timeout.delayMillis)
        assertEquals(listOf(PositionOutcome.Unavailable), outcomes)
        assertTrue(backend.requests.single().isCancelled)
    }

    @Test
    fun stopsLookingForAPositionOnceCancelled() {
        request().cancel()

        assertTrue(backend.requests.single().isCancelled)
        assertTrue(scheduler.task(POSITION_TIMEOUT_MILLIS).isCancelled)
        assertTrue(outcomes.isEmpty())
    }

    @Test
    fun derivesTheMslAltitudeOfAPrecisePositionOnceItIsFound() {
        request()
        backend.requests.single().callback(PositionOutcome.Available(precisePosition))

        val altitudeRequest = backend.altitudeRequests.single()
        assertTrue(outcomes.isEmpty())
        assertEquals(listOf(41.0082, 28.9784, 250.0), altitudeRequest.arguments)
        assertTrue(scheduler.task(POSITION_TIMEOUT_MILLIS).isCancelled)

        altitudeRequest.callback(212.67)

        assertEquals(
            listOf(PositionOutcome.Available(precisePosition.copy(altitude = 212.67))),
            outcomes,
        )
        assertTrue(scheduler.task(ALTITUDE_TIMEOUT_MILLIS).isCancelled)
    }

    @Test
    fun keepsTheMslAltitudeThatAndroidReports() {
        val reported = precisePosition.copy(altitude = 212.67, ellipsoidalAltitude = null)

        request()
        backend.requests.single().callback(PositionOutcome.Available(reported))

        assertEquals(listOf(PositionOutcome.Available(reported)), outcomes)
        assertTrue(backend.altitudeRequests.isEmpty())
        assertTrue(scheduler.tasks.none { it.delayMillis == ALTITUDE_TIMEOUT_MILLIS })
    }

    @Test
    fun reportsAPrecisePositionWithoutAnyAltitudeRightAway() {
        val reported = precisePosition.copy(ellipsoidalAltitude = null)

        request()
        backend.requests.single().callback(PositionOutcome.Available(reported))

        assertEquals(listOf(PositionOutcome.Available(reported)), outcomes)
        assertTrue(backend.altitudeRequests.isEmpty())
    }

    @Test
    fun doesNotDeriveTheAltitudeOfAnApproximatePosition() {
        val approximate = position.copy(ellipsoidalAltitude = 250.0)
        backend.isPreciseAccessGranted = false
        backend.knownPositions[LocationManager.FUSED_PROVIDER] = KnownPosition(approximate, 71_000)

        request()
        backend.knownPositions.clear()
        request()
        backend.requests.single().callback(PositionOutcome.Available(approximate))

        assertEquals(List(2) { PositionOutcome.Available(approximate) }, outcomes)
        assertTrue(backend.altitudeRequests.isEmpty())
        assertTrue(scheduler.tasks.none { it.delayMillis == ALTITUDE_TIMEOUT_MILLIS })
    }

    @Test
    fun reportsThePositionWithoutAltitudeWhenTheAltitudeCannotBeDerived() {
        request()
        backend.requests.single().callback(PositionOutcome.Available(precisePosition))
        backend.altitudeRequests.single().callback(null)

        assertEquals(listOf(PositionOutcome.Available(precisePosition)), outcomes)
        assertTrue(scheduler.task(ALTITUDE_TIMEOUT_MILLIS).isCancelled)
    }

    @Test
    fun reportsThePositionWithoutAltitudeWhenDerivingTheAltitudeTakesTooLong() {
        request()
        backend.requests.single().callback(PositionOutcome.Available(precisePosition))
        scheduler.task(ALTITUDE_TIMEOUT_MILLIS).run()
        backend.altitudeRequests.single().callback(212.67)

        assertEquals(listOf(PositionOutcome.Available(precisePosition)), outcomes)
        assertTrue(backend.altitudeRequests.single().isCancelled)
    }

    @Test
    fun reportsNothingWhenCancelledWhileTheAltitudeIsDerived() {
        val request = request()
        backend.requests.single().callback(PositionOutcome.Available(precisePosition))

        request.cancel()
        scheduler.task(ALTITUDE_TIMEOUT_MILLIS).run()
        backend.altitudeRequests.single().callback(212.67)

        assertTrue(outcomes.isEmpty())
        assertTrue(backend.altitudeRequests.single().isCancelled)
    }

    @Test
    fun reportsAnAltitudeThatIsDerivedRightAway() {
        backend.derivesAltitudeRightAway = true

        val request = request()
        backend.requests.single().callback(PositionOutcome.Available(precisePosition))
        request.cancel()

        assertEquals(
            listOf(PositionOutcome.Available(precisePosition.copy(altitude = 212.67))),
            outcomes,
        )
        assertTrue(scheduler.task(ALTITUDE_TIMEOUT_MILLIS).isCancelled)
    }

    @Test
    fun derivesTheAltitudeOfAPositionThatIsFoundRightAway() {
        backend.positionFoundRightAway = precisePosition

        val request = request()
        request.cancel()

        assertTrue(outcomes.isEmpty())
        assertTrue(backend.altitudeRequests.single().isCancelled)
        assertTrue(scheduler.task(ALTITUDE_TIMEOUT_MILLIS).isCancelled)
    }

    private class AltitudeRequest(
        val arguments: List<Double>,
        val callback: (Double?) -> Unit,
    ) : Cancellable {
        var isCancelled = false
            private set

        override fun cancel() {
            isCancelled = true
        }
    }

    private class ProviderRequest(
        val provider: String,
        val callback: (PositionOutcome) -> Unit,
    ) : Cancellable {
        var isCancelled = false
            private set

        override fun cancel() {
            isCancelled = true
        }
    }

    private class FakeBackend : LocationManagerBackend {
        override var isLocationEnabled = true
        override var isPreciseAccessGranted = true
        override var hasFusedProvider = true
        override var enabledProviders: Collection<String> =
            listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)
        var positionFoundRightAway: Position? = null
        var derivesAltitudeRightAway = false
        val knownPositions = mutableMapOf<String, KnownPosition>()
        val lastKnownReads = mutableListOf<String>()
        val requests = mutableListOf<ProviderRequest>()
        val altitudeRequests = mutableListOf<AltitudeRequest>()

        override fun lastKnownPosition(provider: String): KnownPosition? {
            lastKnownReads += provider
            return knownPositions[provider]
        }

        override fun requestPosition(
            provider: String,
            callback: (PositionOutcome) -> Unit,
        ): Cancellable {
            positionFoundRightAway?.let { callback(PositionOutcome.Available(it)) }
            return ProviderRequest(provider, callback).also { requests += it }
        }

        override fun requestMslAltitude(
            latitude: Double,
            longitude: Double,
            ellipsoidalAltitude: Double,
            callback: (Double?) -> Unit,
        ): Cancellable {
            if (derivesAltitudeRightAway) {
                callback(212.67)
            }
            return AltitudeRequest(listOf(latitude, longitude, ellipsoidalAltitude), callback)
                .also { altitudeRequests += it }
        }
    }

    private class FakeScheduler : Scheduler {
        val tasks = mutableListOf<ScheduledTask>()

        fun task(delayMillis: Long): ScheduledTask = tasks.single { it.delayMillis == delayMillis }

        override fun schedule(delayMillis: Long, action: () -> Unit): Cancellable =
            ScheduledTask(delayMillis, action).also { tasks += it }
    }

    private class ScheduledTask(
        val delayMillis: Long,
        private val action: () -> Unit,
    ) : Cancellable {
        var isCancelled = false
            private set

        override fun cancel() {
            isCancelled = true
        }

        fun run() {
            if (!isCancelled) {
                action()
            }
        }
    }
}
