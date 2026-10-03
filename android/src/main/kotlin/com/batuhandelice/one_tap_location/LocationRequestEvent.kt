// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package com.batuhandelice.one_tap_location

internal enum class LocationErrorCode(val wireName: String) {
    LOCATION_UNAVAILABLE("locationUnavailable"),
    LOCATION_SERVICES_DISABLED("locationServicesDisabled"),
    UNKNOWN("unknown"),
}

internal sealed interface LocationRequestEvent {
    data object Locating : LocationRequestEvent

    /** The final outcome of a request. */
    sealed interface Result : LocationRequestEvent

    data class Granted(val position: Position) : Result

    data object Denied : Result

    data class Failed(val code: LocationErrorCode, val message: String?) : Result

    data object TapWithoutAuthorization : LocationRequestEvent
}

internal fun PositionOutcome.toResult(): LocationRequestEvent.Result = when (this) {
    is PositionOutcome.Available -> LocationRequestEvent.Granted(position)
    PositionOutcome.Unavailable ->
        LocationRequestEvent.Failed(LocationErrorCode.LOCATION_UNAVAILABLE, null)
    PositionOutcome.ServicesDisabled ->
        LocationRequestEvent.Failed(LocationErrorCode.LOCATION_SERVICES_DISABLED, null)
    // Access can be revoked while the position is being determined.
    is PositionOutcome.Error ->
        if (error is SecurityException) {
            LocationRequestEvent.Denied
        } else {
            LocationRequestEvent.Failed(LocationErrorCode.UNKNOWN, error.message)
        }
}
