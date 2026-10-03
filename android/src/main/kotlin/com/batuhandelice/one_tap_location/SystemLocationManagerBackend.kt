// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package com.batuhandelice.one_tap_location

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.location.LocationRequest
import android.location.altitude.AltitudeConverter
import android.os.Build
import android.os.Bundle
import android.os.CancellationSignal
import android.os.Looper
import android.os.SystemClock
import androidx.annotation.RequiresApi
import androidx.annotation.WorkerThread
import java.io.IOException
import java.util.concurrent.Executor
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.ThreadFactory
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit

/**
 * Reads positions from the [LocationManager] of the device, and derives their altitude above mean
 * sea level with [AltitudeConverter].
 */
internal class SystemLocationManagerBackend(private val context: Context) : LocationManagerBackend {
    private val manager = context.getSystemService(LocationManager::class.java)

    override val isLocationEnabled: Boolean
        get() = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            manager.isLocationEnabled
        } else {
            manager.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
                manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
        }

    override val isPreciseAccessGranted: Boolean
        get() = context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED

    override val hasFusedProvider: Boolean
        get() = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            manager.hasProvider(LocationManager.FUSED_PROVIDER)

    override val enabledProviders: Collection<String>
        get() = manager.getProviders(true)

    @SuppressLint("MissingPermission")
    override fun lastKnownPosition(provider: String): KnownPosition? {
        val location = try {
            manager.getLastKnownLocation(provider)
        } catch (exception: SecurityException) {
            null
        } ?: return null
        return KnownPosition(
            position = location.toPosition(),
            ageMillis =
                (SystemClock.elapsedRealtimeNanos() - location.elapsedRealtimeNanos) / 1_000_000,
        )
    }

    // Access is granted before a position is requested. A grant that is revoked in the meantime
    // surfaces as a SecurityException.
    @SuppressLint("MissingPermission")
    override fun requestPosition(
        provider: String,
        callback: (PositionOutcome) -> Unit,
    ): Cancellable =
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                requestCurrentLocation(provider, callback)
            } else {
                requestSingleUpdate(provider, callback)
            }
        } catch (exception: SecurityException) {
            callback(PositionOutcome.Error(exception))
            Cancellable {}
        }

    @RequiresApi(Build.VERSION_CODES.S)
    @SuppressLint("MissingPermission")
    private fun requestCurrentLocation(
        provider: String,
        callback: (PositionOutcome) -> Unit,
    ): Cancellable {
        val request = LocationRequest.Builder(0L)
            .setQuality(LocationRequest.QUALITY_HIGH_ACCURACY)
            .setDurationMillis(POSITION_TIMEOUT_MILLIS)
            .build()
        val cancellation = CancellationSignal()
        manager.getCurrentLocation(provider, request, cancellation, context.mainExecutor) {
            callback(it?.let { location -> PositionOutcome.Available(location.toPosition()) }
                ?: PositionOutcome.Unavailable)
        }
        return Cancellable { cancellation.cancel() }
    }

    // Requests that set their own quality and duration require Android 12, so earlier versions
    // listen for the first update and rely on the timeout of the caller.
    @SuppressLint("MissingPermission")
    private fun requestSingleUpdate(
        provider: String,
        callback: (PositionOutcome) -> Unit,
    ): Cancellable {
        val listener = SingleUpdateListener(callback)
        manager.requestLocationUpdates(provider, 0L, 0f, listener, Looper.getMainLooper())
        return Cancellable { manager.removeUpdates(listener) }
    }

    override fun requestMslAltitude(
        latitude: Double,
        longitude: Double,
        ellipsoidalAltitude: Double,
        callback: (Double?) -> Unit,
    ): Cancellable {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            callback(null)
            return Cancellable {}
        }
        var isCancelled = false
        MslAltitudes.executor.execute {
            val altitude = MslAltitudes.derive(context, latitude, longitude, ellipsoidalAltitude)
            context.mainExecutor.execute {
                if (!isCancelled) {
                    callback(altitude)
                }
            }
        }
        return Cancellable { isCancelled = true }
    }

    private fun Location.toPosition() = Position(
        latitude = latitude,
        longitude = longitude,
        timestampMillis = time,
        isPrecise = isPreciseAccessGranted,
        horizontalAccuracy = if (hasAccuracy()) accuracy.toDouble() else null,
        altitude = if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE && hasMslAltitude() &&
            mslAltitudeMeters.isFinite()
        ) {
            mslAltitudeMeters
        } else {
            null
        },
        // On Android 14 and later, the altitude above mean sea level can be derived from this one.
        ellipsoidalAltitude = if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE && !hasMslAltitude() &&
            hasAltitude() && altitude.isFinite()
        ) {
            altitude
        } else {
            null
        },
    )

    /**
     * Reports the first update of a provider.
     *
     * Before Android 11, [LocationListener] has no default methods, so all of them are implemented.
     */
    private inner class SingleUpdateListener(
        private val callback: (PositionOutcome) -> Unit,
    ) : LocationListener {
        private var hasAnswered = false

        override fun onLocationChanged(location: Location) {
            answer(PositionOutcome.Available(location.toPosition()))
        }

        override fun onProviderDisabled(provider: String) {
            answer(PositionOutcome.Unavailable)
        }

        override fun onProviderEnabled(provider: String) = Unit

        @Suppress("OVERRIDE_DEPRECATION")
        override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) = Unit

        private fun answer(outcome: PositionOutcome) {
            if (!hasAnswered) {
                hasAnswered = true
                manager.removeUpdates(this)
                callback(outcome)
            }
        }
    }
}

/** Derives altitudes above mean sea level on one background thread for the whole process. */
@RequiresApi(Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
private object MslAltitudes {
    /** Runs the derivations in order on a thread that ends when it has been idle for a while. */
    val executor: Executor = ThreadPoolExecutor(
        1,
        1,
        30L,
        TimeUnit.SECONDS,
        LinkedBlockingQueue(),
        ThreadFactory { runnable -> Thread(runnable, "one_tap_location altitude") },
    ).apply { allowCoreThreadTimeOut(true) }

    // Keeps the geoid data that it loads, and is used only on the thread of the executor.
    private val converter = AltitudeConverter()

    @WorkerThread
    fun derive(
        context: Context,
        latitude: Double,
        longitude: Double,
        ellipsoidalAltitude: Double,
    ): Double? {
        val location = Location("").apply {
            this.latitude = latitude
            this.longitude = longitude
            altitude = ellipsoidalAltitude
        }
        // The altitude is optional, so geoid data that is missing or damaged only leaves it out.
        return try {
            converter.addMslAltitudeToLocation(context, location)
            location.mslAltitudeMeters
        } catch (exception: IOException) {
            null
        } catch (exception: RuntimeException) {
            null
        }
    }
}
