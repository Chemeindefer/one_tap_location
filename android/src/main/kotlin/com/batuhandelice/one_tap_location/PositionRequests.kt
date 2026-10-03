// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package com.batuhandelice.one_tap_location

/**
 * Tracks the position requests of fallback buttons by the identifier that the Dart side assigns, so
 * that a button that is removed can cancel its request.
 */
internal class PositionRequests(private val source: PositionSource) {
    private class Request(val callback: (PositionOutcome?) -> Unit) {
        var cancellable: Cancellable? = null
    }

    private val requests = HashMap<Int, Request>()

    /** Requests a position and calls [callback] with the outcome, or with null once cancelled. */
    fun start(id: Int, callback: (PositionOutcome?) -> Unit) {
        cancel(id)
        val request = Request(callback)
        requests[id] = request
        request.cancellable = source.requestPosition { outcome ->
            if (requests[id] === request) {
                requests.remove(id)
                callback(outcome)
            }
        }
    }

    fun cancel(id: Int) {
        val request = requests.remove(id) ?: return
        request.cancellable?.cancel()
        request.callback(null)
    }

    fun cancelAll() {
        requests.keys.toList().forEach(::cancel)
    }
}
