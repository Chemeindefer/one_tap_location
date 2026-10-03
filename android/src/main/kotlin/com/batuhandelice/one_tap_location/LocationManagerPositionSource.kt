// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package com.batuhandelice.one_tap_location

import android.annotation.SuppressLint
import android.location.LocationManager

/** How long a request waits for a position. */
internal const val POSITION_TIMEOUT_MILLIS = 30_000L

/**
 * How long a request waits for the altitude above mean sea level of a position that it found,
 * before it reports the position without altitude.
 *
 * The first derivation in a process loads geoid data from the assets of the system, so it takes
 * longer than the derivations that follow.
 */
internal const val ALTITUDE_TIMEOUT_MILLIS = 2_000L

/**
 * The age up to which a known position is reported to an app with approximate access.
 *
 * Android updates the position for such an app at most every ten minutes and determines a new one
 * with low power, so a request for the current position can take long or produce none within the
 * timeout.
 */
private const val APPROXIMATE_POSITION_MAX_AGE_MILLIS = 10 * 60_000L

/** A position that Android determined earlier, with its age. */
internal data class KnownPosition(val position: Position, val ageMillis: Long)

/**
 * The parts of [LocationManager], of the granted permissions and of altitude conversion that the
 * position source uses.
 */
internal interface LocationManagerBackend {
    val isLocationEnabled: Boolean

    val isPreciseAccessGranted: Boolean

    val hasFusedProvider: Boolean

    val enabledProviders: Collection<String>

    fun lastKnownPosition(provider: String): KnownPosition?

    fun requestPosition(provider: String, callback: (PositionOutcome) -> Unit): Cancellable

    /**
     * Derives the altitude above mean sea level from an altitude above the WGS84 ellipsoid and
     * calls [callback] with it, or with null if it cannot be derived. [callback] is called on the
     * main thread, at most once, and not after cancellation.
     */
    fun requestMslAltitude(
        latitude: Double,
        longitude: Double,
        ellipsoidalAltitude: Double,
        callback: (Double?) -> Unit,
    ): Cancellable
}

/**
 * Chooses the providers to ask for a position.
 *
 * The fused provider combines the other providers on devices that have it. Otherwise, the GPS
 * provider requires precise access, and the network provider works with either access.
 */
@SuppressLint("InlinedApi")
internal fun selectLocationProviders(
    hasFusedProvider: Boolean,
    isPreciseAccessGranted: Boolean,
    enabledProviders: Collection<String>,
): List<String> {
    if (hasFusedProvider) {
        return listOf(LocationManager.FUSED_PROVIDER)
    }
    return buildList {
        if (isPreciseAccessGranted && LocationManager.GPS_PROVIDER in enabledProviders) {
            add(LocationManager.GPS_PROVIDER)
        }
        if (LocationManager.NETWORK_PROVIDER in enabledProviders) {
            add(LocationManager.NETWORK_PROVIDER)
        }
    }
}

/** Returns the newest of [candidates] that is at most [maxAgeMillis] old. */
internal fun <T> newestWithin(candidates: List<T>, maxAgeMillis: Long, ageMillis: (T) -> Long): T? =
    candidates.filter { ageMillis(it) in 0..maxAgeMillis }.minByOrNull(ageMillis)

/**
 * Obtains a single position from [LocationManager], without depending on Google Play services.
 *
 * With precise access, the current position is requested; Android can answer with a position that
 * it determined a few seconds before the request. With approximate access, a position that Android
 * determined in the last ten minutes is reported right away. When several providers are asked, the
 * first position found is reported.
 *
 * On Android 14 and later, when Android reports the altitude of a precise position only above the
 * WGS84 ellipsoid, the altitude above mean sea level is derived before the position is reported.
 * The position is reported without altitude if that fails or takes longer than
 * [ALTITUDE_TIMEOUT_MILLIS].
 */
internal class LocationManagerPositionSource(
    private val backend: LocationManagerBackend,
    private val scheduler: Scheduler,
) : PositionSource {
    override fun requestPosition(callback: (PositionOutcome) -> Unit): Cancellable {
        if (!backend.isLocationEnabled) {
            callback(PositionOutcome.ServicesDisabled)
            return Cancellable {}
        }
        val isPreciseAccessGranted = backend.isPreciseAccessGranted
        val providers = selectLocationProviders(
            hasFusedProvider = backend.hasFusedProvider,
            isPreciseAccessGranted = isPreciseAccessGranted,
            enabledProviders = backend.enabledProviders,
        )
        if (!isPreciseAccessGranted) {
            val knownPosition = newestWithin(
                providers.mapNotNull(backend::lastKnownPosition),
                APPROXIMATE_POSITION_MAX_AGE_MILLIS,
                KnownPosition::ageMillis,
            )
            if (knownPosition != null) {
                callback(PositionOutcome.Available(knownPosition.position))
                return Cancellable {}
            }
        }
        val sources = providers.map { provider ->
            PositionSource { providerCallback ->
                backend.requestPosition(provider, providerCallback)
            }
        }
        val firstPosition = PositionSource { positionCallback ->
            requestFirstPosition(sources, scheduler, POSITION_TIMEOUT_MILLIS, positionCallback)
        }
        return requestPositionWithMslAltitude(firstPosition, backend, scheduler, callback)
    }
}

/**
 * Reports the position that [source] finds, after adding its altitude above mean sea level when
 * Android reported only its altitude above the WGS84 ellipsoid.
 *
 * The altitude is derived once the position is found, so that deriving it neither counts against
 * the timeout of the request nor keeps the providers running.
 */
private fun requestPositionWithMslAltitude(
    source: PositionSource,
    backend: LocationManagerBackend,
    scheduler: Scheduler,
    callback: (PositionOutcome) -> Unit,
): Cancellable = MslAltitudeRequest(backend, scheduler, callback).apply { start(source) }

private class MslAltitudeRequest(
    private val backend: LocationManagerBackend,
    private val scheduler: Scheduler,
    private val callback: (PositionOutcome) -> Unit,
) : Cancellable {
    private var positionRequest: Cancellable? = null
    private var altitudeRequest: Cancellable? = null
    private var altitudeTimeout: Cancellable? = null
    private var isFinished = false

    fun start(source: PositionSource) {
        val request = source.requestPosition(::onPositionOutcome)
        // The position may have been found before the request was returned.
        if (!isFinished) {
            positionRequest = request
        }
    }

    override fun cancel() {
        if (isFinished) {
            return
        }
        isFinished = true
        positionRequest?.cancel()
        altitudeTimeout?.cancel()
        altitudeRequest?.cancel()
    }

    private fun onPositionOutcome(outcome: PositionOutcome) {
        if (isFinished) {
            return
        }
        val position = (outcome as? PositionOutcome.Available)?.position
        val ellipsoidalAltitude = position?.ellipsoidalAltitude
        if (position == null || !position.isPrecise || position.altitude != null ||
            ellipsoidalAltitude == null
        ) {
            finish(outcome)
            return
        }
        // The timeout is scheduled first, so that an altitude derived right away cancels it.
        altitudeTimeout = scheduler.schedule(ALTITUDE_TIMEOUT_MILLIS) { finish(outcome) }
        val request = backend.requestMslAltitude(
            latitude = position.latitude,
            longitude = position.longitude,
            ellipsoidalAltitude = ellipsoidalAltitude,
        ) { altitude ->
            finish(PositionOutcome.Available(position.copy(altitude = altitude)))
        }
        if (!isFinished) {
            altitudeRequest = request
        }
    }

    private fun finish(outcome: PositionOutcome) {
        if (isFinished) {
            return
        }
        cancel()
        callback(outcome)
    }
}
