// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package com.batuhandelice.one_tap_location

import org.junit.Assert.assertEquals
import org.junit.Test

class LocationCodecTest {
    @Test
    fun encodesProgress() {
        assertEquals(
            ChannelMessage("onLocating", null),
            LocationCodec.message(LocationRequestEvent.Locating),
        )
    }

    @Test
    fun encodesAGrantedResult() {
        val position = Position(
            latitude = 41.0082,
            longitude = 28.9784,
            timestampMillis = 1_757_800_000_000,
            isPrecise = true,
            horizontalAccuracy = 5.0,
            altitude = 39.5,
        )

        assertEquals(
            ChannelMessage(
                "onResult",
                mapOf(
                    "status" to "granted",
                    "position" to mapOf(
                        "latitude" to 41.0082,
                        "longitude" to 28.9784,
                        "timestamp" to 1_757_800_000_000,
                        "isPrecise" to true,
                        "horizontalAccuracy" to 5.0,
                        "altitude" to 39.5,
                    ),
                ),
            ),
            LocationCodec.message(LocationRequestEvent.Granted(position)),
        )
    }

    @Test
    fun omitsUnavailablePositionDetails() {
        val position = Position(
            latitude = 41.0,
            longitude = 29.0,
            timestampMillis = 0,
            isPrecise = true,
            horizontalAccuracy = null,
            altitude = null,
            ellipsoidalAltitude = 250.0,
        )

        assertEquals(
            mapOf("latitude" to 41.0, "longitude" to 29.0, "timestamp" to 0L, "isPrecise" to true),
            LocationCodec.position(position),
        )
    }

    @Test
    fun omitsTheAltitudeOfAnApproximatePosition() {
        val position = Position(
            latitude = 41.009009,
            longitude = 28.983955,
            timestampMillis = 0,
            isPrecise = false,
            horizontalAccuracy = 2_000.0,
            altitude = 212.67,
        )

        assertEquals(
            mapOf(
                "latitude" to 41.009009,
                "longitude" to 28.983955,
                "timestamp" to 0L,
                "isPrecise" to false,
                "horizontalAccuracy" to 2_000.0,
            ),
            LocationCodec.position(position),
        )
    }

    @Test
    fun encodesADeniedResult() {
        assertEquals(
            ChannelMessage("onResult", mapOf("status" to "denied")),
            LocationCodec.message(LocationRequestEvent.Denied),
        )
    }

    @Test
    fun encodesAFailedResult() {
        assertEquals(
            ChannelMessage(
                "onResult",
                mapOf("status" to "failed", "code" to "unknown", "message" to "Broken"),
            ),
            LocationCodec.message(LocationRequestEvent.Failed(LocationErrorCode.UNKNOWN, "Broken")),
        )
        assertEquals(
            ChannelMessage(
                "onResult",
                mapOf("status" to "failed", "code" to "locationUnavailable"),
            ),
            LocationCodec.message(
                LocationRequestEvent.Failed(LocationErrorCode.LOCATION_UNAVAILABLE, null),
            ),
        )
        assertEquals(
            mapOf("status" to "failed", "code" to "locationServicesDisabled"),
            LocationCodec.result(
                LocationRequestEvent.Failed(LocationErrorCode.LOCATION_SERVICES_DISABLED, null),
            ),
        )
    }

    @Test
    fun encodesADiagnostic() {
        assertEquals(
            ChannelMessage("onDiagnostic", mapOf("diagnostic" to "tapWithoutAuthorization")),
            LocationCodec.message(LocationRequestEvent.TapWithoutAuthorization),
        )
    }

    @Test
    fun encodesTheAvailability() {
        assertEquals(
            mapOf(
                "isSystemButtonAvailable" to true,
                "isPreciseLocationRestrictedToSystemButton" to false,
            ),
            LocationCodec.availability(
                isSystemButtonAvailable = true,
                isPreciseLocationRestrictedToSystemButton = false,
            ),
        )
    }
}
