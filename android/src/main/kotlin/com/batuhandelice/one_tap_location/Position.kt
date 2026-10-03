// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package com.batuhandelice.one_tap_location

/**
 * A geographic position, independent of the Android location classes.
 *
 * [altitude] is above mean sea level. [ellipsoidalAltitude] is above the WGS84 ellipsoid; it is set
 * only on Android 14 and later, when Android reports no altitude above mean sea level, and it is
 * not sent to the Dart side.
 */
internal data class Position(
    val latitude: Double,
    val longitude: Double,
    val timestampMillis: Long,
    val isPrecise: Boolean,
    val horizontalAccuracy: Double?,
    val altitude: Double?,
    val ellipsoidalAltitude: Double? = null,
)

internal sealed interface PositionOutcome {
    data class Available(val position: Position) : PositionOutcome

    data object Unavailable : PositionOutcome

    data object ServicesDisabled : PositionOutcome

    data class Error(val error: Throwable) : PositionOutcome
}

/** Requests a single position. The callback is called at most once, and not after cancellation. */
internal fun interface PositionSource {
    fun requestPosition(callback: (PositionOutcome) -> Unit): Cancellable
}
