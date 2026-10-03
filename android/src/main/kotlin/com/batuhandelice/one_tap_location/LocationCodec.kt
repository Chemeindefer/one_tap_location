// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package com.batuhandelice.one_tap_location

internal data class ChannelMessage(val method: String, val arguments: Map<String, Any?>?)

/**
 * Encodes the button events, the fallback results and the availability that the Android side of the
 * plugin sends to the Dart side.
 */
internal object LocationCodec {
    fun message(event: LocationRequestEvent): ChannelMessage = when (event) {
        LocationRequestEvent.Locating -> ChannelMessage("onLocating", null)
        is LocationRequestEvent.Result -> ChannelMessage("onResult", result(event))
        LocationRequestEvent.TapWithoutAuthorization -> ChannelMessage(
            "onDiagnostic",
            mapOf("diagnostic" to "tapWithoutAuthorization"),
        )
    }

    fun result(result: LocationRequestEvent.Result): Map<String, Any?> = when (result) {
        is LocationRequestEvent.Granted ->
            mapOf("status" to "granted", "position" to position(result.position))
        LocationRequestEvent.Denied -> mapOf("status" to "denied")
        is LocationRequestEvent.Failed -> buildMap {
            put("status", "failed")
            put("code", result.code.wireName)
            result.message?.let { put("message", it) }
        }
    }

    fun position(position: Position): Map<String, Any?> = buildMap {
        put("latitude", position.latitude)
        put("longitude", position.longitude)
        put("timestamp", position.timestampMillis)
        put("isPrecise", position.isPrecise)
        position.horizontalAccuracy?.let { put("horizontalAccuracy", it) }
        // Android can leave the altitude of an earlier precise position on an approximate one.
        if (position.isPrecise) {
            position.altitude?.let { put("altitude", it) }
        }
    }

    fun availability(
        isSystemButtonAvailable: Boolean,
        isPreciseLocationRestrictedToSystemButton: Boolean,
    ): Map<String, Any?> = mapOf(
        "isSystemButtonAvailable" to isSystemButtonAvailable,
        "isPreciseLocationRestrictedToSystemButton" to isPreciseLocationRestrictedToSystemButton,
    )
}
