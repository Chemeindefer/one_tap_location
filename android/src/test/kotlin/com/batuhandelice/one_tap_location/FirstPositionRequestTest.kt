// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package com.batuhandelice.one_tap_location

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FirstPositionRequestTest {
    private val position = Position(
        latitude = 41.0082,
        longitude = 28.9784,
        timestampMillis = 1_757_800_000_000,
        isPrecise = true,
        horizontalAccuracy = 5.0,
        altitude = null,
    )
    private val scheduler = FakeScheduler()
    private val outcomes = mutableListOf<PositionOutcome>()

    private fun request(vararg sources: FakeSource): Cancellable =
        requestFirstPosition(sources.toList(), scheduler, TIMEOUT_MILLIS) { outcomes += it }

    @Test
    fun reportsTheFirstPositionAndCancelsTheOtherRequests() {
        val gps = FakeSource()
        val network = FakeSource()
        request(gps, network)

        network.answer(PositionOutcome.Available(position))
        gps.answer(PositionOutcome.Available(position.copy(latitude = 0.0)))

        assertEquals(listOf(PositionOutcome.Available(position)), outcomes)
        assertTrue(gps.isCancelled)
        assertTrue(scheduler.tasks.single().isCancelled)
    }

    @Test
    fun waitsForTheOtherSourcesWhenOneHasNoPosition() {
        val gps = FakeSource()
        val network = FakeSource()
        request(gps, network)

        gps.answer(PositionOutcome.Unavailable)
        assertTrue(outcomes.isEmpty())

        network.answer(PositionOutcome.Available(position))
        assertEquals(listOf(PositionOutcome.Available(position)), outcomes)
    }

    @Test
    fun reportsAnUnavailablePositionWhenNoSourceHasOne() {
        val gps = FakeSource()
        val network = FakeSource()
        request(gps, network)

        gps.answer(PositionOutcome.Unavailable)
        network.answer(PositionOutcome.Unavailable)

        assertEquals(listOf(PositionOutcome.Unavailable), outcomes)
        assertTrue(scheduler.tasks.single().isCancelled)
    }

    @Test
    fun reportsTheFirstErrorWhenNoSourceHasAPosition() {
        val revoked = PositionOutcome.Error(SecurityException())
        val gps = FakeSource()
        val network = FakeSource()
        request(gps, network)

        gps.answer(revoked)
        network.answer(PositionOutcome.Error(IllegalStateException()))

        assertEquals(listOf(revoked), outcomes)
    }

    @Test
    fun reportsAnUnavailablePositionAfterTheTimeout() {
        val gps = FakeSource()
        request(gps)

        val timeout = scheduler.tasks.single()
        assertEquals(TIMEOUT_MILLIS, timeout.delayMillis)
        timeout.run()
        gps.answer(PositionOutcome.Available(position))

        assertEquals(listOf(PositionOutcome.Unavailable), outcomes)
        assertTrue(gps.isCancelled)
    }

    @Test
    fun reportsAnUnavailablePositionWithoutSources() {
        request()

        assertEquals(listOf(PositionOutcome.Unavailable), outcomes)
        assertTrue(scheduler.tasks.isEmpty())
    }

    @Test
    fun stopsAtAPositionThatIsReportedSynchronously() {
        val immediate = FakeSource(synchronousOutcome = PositionOutcome.Available(position))
        val later = FakeSource()
        request(immediate, later)

        assertEquals(listOf(PositionOutcome.Available(position)), outcomes)
        assertFalse(later.isRequested)
        assertTrue(scheduler.tasks.single().isCancelled)
    }

    @Test
    fun reportsNothingOnceCancelled() {
        val gps = FakeSource()
        val request = request(gps)

        request.cancel()
        gps.answer(PositionOutcome.Available(position))

        assertTrue(outcomes.isEmpty())
        assertTrue(gps.isCancelled)
        assertTrue(scheduler.tasks.single().isCancelled)
    }

    private class FakeSource(
        private val synchronousOutcome: PositionOutcome? = null,
    ) : PositionSource {
        private var callback: ((PositionOutcome) -> Unit)? = null

        val isRequested: Boolean
            get() = callback != null

        var isCancelled = false
            private set

        override fun requestPosition(callback: (PositionOutcome) -> Unit): Cancellable {
            this.callback = callback
            synchronousOutcome?.let(callback)
            return Cancellable { isCancelled = true }
        }

        fun answer(outcome: PositionOutcome) {
            checkNotNull(callback)(outcome)
        }
    }

    private class FakeScheduler : Scheduler {
        val tasks = mutableListOf<ScheduledTask>()

        override fun schedule(delayMillis: Long, action: () -> Unit): Cancellable =
            ScheduledTask(delayMillis, action).also { tasks += it }
    }

    private class ScheduledTask(
        val delayMillis: Long,
        private val action: () -> Unit,
    ) : Cancellable {
        var isCancelled = false
            private set

        override fun cancel() {
            isCancelled = true
        }

        fun run() {
            if (!isCancelled) {
                action()
            }
        }
    }

    private companion object {
        const val TIMEOUT_MILLIS = 30_000L
    }
}
