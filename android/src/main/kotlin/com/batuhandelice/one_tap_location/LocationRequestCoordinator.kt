// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package com.batuhandelice.one_tap_location

/** Turns the answers of the system location button into a single location request. */
internal class LocationRequestCoordinator(
    private val positionSource: PositionSource,
    private val onEvent: (LocationRequestEvent) -> Unit,
) {
    private var isLocating = false
    private var requestGeneration = 0
    private var positionRequest: Cancellable? = null

    fun onPermissionResult(isGranted: Boolean) {
        if (isLocating) {
            return
        }
        if (isGranted) {
            startLocating()
        } else {
            onEvent(LocationRequestEvent.Denied)
        }
    }

    fun onConfirmationDismissed() {
        if (!isLocating) {
            onEvent(LocationRequestEvent.TapWithoutAuthorization)
        }
    }

    fun dispose() {
        requestGeneration++
        positionRequest?.cancel()
        positionRequest = null
        isLocating = false
    }

    private fun startLocating() {
        isLocating = true
        onEvent(LocationRequestEvent.Locating)
        val generation = ++requestGeneration
        val request = positionSource.requestPosition { outcome ->
            if (generation == requestGeneration && isLocating) {
                positionRequest = null
                isLocating = false
                onEvent(outcome.toResult())
            }
        }
        // The source may answer synchronously, before the request is returned.
        if (generation == requestGeneration && isLocating) {
            positionRequest = request
        }
    }
}
