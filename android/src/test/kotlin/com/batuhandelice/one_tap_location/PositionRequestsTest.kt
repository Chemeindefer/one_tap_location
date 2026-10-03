// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package com.batuhandelice.one_tap_location

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PositionRequestsTest {
    private val position = Position(
        latitude = 41.0082,
        longitude = 28.9784,
        timestampMillis = 1_757_800_000_000,
        isPrecise = true,
        horizontalAccuracy = 5.0,
        altitude = null,
    )
    private val sourceRequests = mutableListOf<SourceRequest>()
    private var requests = PositionRequests { callback ->
        SourceRequest(callback).also { sourceRequests += it }
    }

    @Test
    fun reportsTheOutcomeOfARequest() {
        val outcomes = mutableListOf<PositionOutcome?>()
        requests.start(1) { outcomes += it }

        sourceRequests.single().callback(PositionOutcome.Available(position))
        requests.cancel(1)

        assertEquals(listOf(PositionOutcome.Available(position)), outcomes)
        assertFalse(sourceRequests.single().isCancelled)
    }

    @Test
    fun reportsNullForACancelledRequest() {
        val outcomes = mutableListOf<PositionOutcome?>()
        requests.start(1) { outcomes += it }

        requests.cancel(1)
        sourceRequests.single().callback(PositionOutcome.Available(position))

        assertEquals(listOf<PositionOutcome?>(null), outcomes)
        assertTrue(sourceRequests.single().isCancelled)
    }

    @Test
    fun keepsTheRequestsOfOtherButtons() {
        val first = mutableListOf<PositionOutcome?>()
        val second = mutableListOf<PositionOutcome?>()
        requests.start(1) { first += it }
        requests.start(2) { second += it }

        requests.cancel(1)
        sourceRequests[1].callback(PositionOutcome.Unavailable)

        assertEquals(listOf<PositionOutcome?>(null), first)
        assertEquals(listOf<PositionOutcome?>(PositionOutcome.Unavailable), second)
    }

    @Test
    fun replacesARequestWithTheSameIdentifier() {
        val first = mutableListOf<PositionOutcome?>()
        val second = mutableListOf<PositionOutcome?>()
        requests.start(1) { first += it }

        requests.start(1) { second += it }
        sourceRequests[1].callback(PositionOutcome.Available(position))

        assertEquals(listOf<PositionOutcome?>(null), first)
        assertTrue(sourceRequests[0].isCancelled)
        assertEquals(listOf<PositionOutcome?>(PositionOutcome.Available(position)), second)
    }

    @Test
    fun cancelsAllRequests() {
        val outcomes = mutableListOf<PositionOutcome?>()
        requests.start(1) { outcomes += it }
        requests.start(2) { outcomes += it }

        requests.cancelAll()

        assertEquals(listOf<PositionOutcome?>(null, null), outcomes)
        assertTrue(sourceRequests.all { it.isCancelled })
    }

    @Test
    fun acceptsAnOutcomeThatIsReportedSynchronously() {
        requests = PositionRequests { callback ->
            callback(PositionOutcome.Available(position))
            Cancellable { error("A finished request must not be cancelled.") }
        }
        val outcomes = mutableListOf<PositionOutcome?>()

        requests.start(1) { outcomes += it }
        requests.cancelAll()

        assertEquals(listOf<PositionOutcome?>(PositionOutcome.Available(position)), outcomes)
    }

    private class SourceRequest(val callback: (PositionOutcome) -> Unit) : Cancellable {
        var isCancelled = false
            private set

        override fun cancel() {
            isCancelled = true
        }
    }
}
