// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package com.batuhandelice.one_tap_location

/**
 * Requests a position from all [sources] at once and reports the first position found.
 *
 * The other requests are cancelled once a position is found or [timeoutMillis] have passed. When
 * every source finishes without a position, the first error is reported, or an unavailable position
 * if no source failed.
 */
internal fun requestFirstPosition(
    sources: List<PositionSource>,
    scheduler: Scheduler,
    timeoutMillis: Long,
    callback: (PositionOutcome) -> Unit,
): Cancellable = FirstPositionRequest(callback).apply { start(sources, scheduler, timeoutMillis) }

private class FirstPositionRequest(private val callback: (PositionOutcome) -> Unit) : Cancellable {
    private val requests = ArrayList<Cancellable>()
    private var timeout: Cancellable? = null
    private var pendingSources = 0
    private var error: PositionOutcome.Error? = null
    private var isFinished = false

    fun start(sources: List<PositionSource>, scheduler: Scheduler, timeoutMillis: Long) {
        if (sources.isEmpty()) {
            finish(PositionOutcome.Unavailable)
            return
        }
        pendingSources = sources.size
        timeout = scheduler.schedule(timeoutMillis) { finish(PositionOutcome.Unavailable) }
        for (source in sources) {
            val request = source.requestPosition(::onOutcome)
            // The source may have answered before returning its request.
            if (isFinished) {
                request.cancel()
                return
            }
            requests += request
        }
    }

    override fun cancel() {
        if (isFinished) {
            return
        }
        isFinished = true
        timeout?.cancel()
        requests.forEach(Cancellable::cancel)
        requests.clear()
    }

    private fun onOutcome(outcome: PositionOutcome) {
        if (isFinished) {
            return
        }
        if (outcome is PositionOutcome.Available) {
            finish(outcome)
            return
        }
        if (outcome is PositionOutcome.Error && error == null) {
            error = outcome
        }
        pendingSources -= 1
        if (pendingSources == 0) {
            finish(error ?: PositionOutcome.Unavailable)
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
