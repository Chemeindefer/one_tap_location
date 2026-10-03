// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package com.batuhandelice.one_tap_location

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class ConfirmationTrackerTest {
    private val host = Any()
    private val otherHost = Any()

    private lateinit var scheduledTasks: MutableList<ScheduledTask>
    private lateinit var tracker: ConfirmationTracker
    private var canPauseBeConfirmation = true

    @Before
    fun setUp() {
        scheduledTasks = mutableListOf()
        canPauseBeConfirmation = true
        tracker = ConfirmationTracker(
            scheduler = { delayMillis, action ->
                ScheduledTask(delayMillis, action).also { scheduledTasks += it }
            },
            pausingScreen = { canPauseBeConfirmation },
        )
    }

    private fun button(host: Any = this.host, isShown: Boolean = true): FakeButton {
        return FakeButton(host, isShown).also(tracker::register)
    }

    private fun runScheduledTasks() {
        val tasks = scheduledTasks.toList()
        scheduledTasks.clear()
        tasks.filterNot { it.isCancelled }.forEach { it.action() }
    }

    @Test
    fun reportsADismissedConfirmationToTheShownButton() {
        val shownButton = button()
        val hiddenButton = button(isShown = false)

        tracker.onHostPaused(host)
        tracker.onHostResumed(host)
        assertEquals(ConfirmationTracker.ANSWER_TIMEOUT_MILLIS, scheduledTasks.single().delayMillis)
        runScheduledTasks()

        assertEquals(1, shownButton.dismissals)
        assertEquals(0, hiddenButton.dismissals)
    }

    @Test
    fun ignoresAnAnsweredConfirmation() {
        val shownButton = button()

        tracker.onHostPaused(host)
        tracker.onAnswer(host)
        tracker.onHostResumed(host)

        assertTrue(scheduledTasks.isEmpty())
        assertEquals(0, shownButton.dismissals)
    }

    @Test
    fun ignoresAnAnswerThatArrivesAfterTheHostResumes() {
        val shownButton = button()

        tracker.onHostPaused(host)
        tracker.onHostResumed(host)
        tracker.onAnswer(host)
        runScheduledTasks()

        assertEquals(0, shownButton.dismissals)
    }

    @Test
    fun ignoresAPauseForAnotherScreen() {
        val shownButton = button()
        canPauseBeConfirmation = false

        tracker.onHostPaused(host)
        tracker.onHostResumed(host)
        assertTrue(scheduledTasks.isEmpty())
        runScheduledTasks()

        assertEquals(0, shownButton.dismissals)
    }

    @Test
    fun keepsWaitingWhenAnotherScreenPausesTheHostAgain() {
        val shownButton = button()

        tracker.onHostPaused(host)
        tracker.onHostResumed(host)
        canPauseBeConfirmation = false
        tracker.onHostPaused(host)
        tracker.onHostResumed(host)
        runScheduledTasks()

        assertEquals(1, shownButton.dismissals)
    }

    @Test
    fun ignoresPausesWhileNoButtonIsShown() {
        button(isShown = false)

        tracker.onHostPaused(host)
        tracker.onHostResumed(host)

        assertTrue(scheduledTasks.isEmpty())
    }

    @Test
    fun reportsNothingWhenSeveralButtonsWereShown() {
        val firstButton = button()
        val secondButton = button()

        tracker.onHostPaused(host)
        tracker.onHostResumed(host)
        runScheduledTasks()

        assertEquals(0, firstButton.dismissals)
        assertEquals(0, secondButton.dismissals)
    }

    @Test
    fun clearsTheWaitOfEveryButtonOfTheHostWhenOneIsAnswered() {
        val firstButton = button()
        val secondButton = button()

        tracker.onHostPaused(host)
        tracker.onHostPaused(host)
        tracker.onAnswer(host)
        tracker.onHostResumed(host)
        tracker.onHostResumed(host)

        assertTrue(scheduledTasks.isEmpty())
        assertEquals(0, firstButton.dismissals)
        assertEquals(0, secondButton.dismissals)
    }

    @Test
    fun reportsOnceWhenTheSameEventsArriveTwice() {
        val shownButton = button()

        tracker.onHostPaused(host)
        tracker.onHostPaused(host)
        tracker.onHostResumed(host)
        tracker.onHostResumed(host)
        runScheduledTasks()

        assertEquals(1, shownButton.dismissals)
    }

    @Test
    fun keepsTheButtonsOfDifferentHostsApart() {
        val shownButton = button()
        val otherButton = button(host = otherHost)

        tracker.onHostPaused(host)
        tracker.onHostResumed(host)
        tracker.onHostStopped(otherHost)
        runScheduledTasks()

        assertEquals(1, shownButton.dismissals)
        assertEquals(0, otherButton.dismissals)
    }

    @Test
    fun ignoresAHostThatWasStopped() {
        val shownButton = button()

        tracker.onHostPaused(host)
        tracker.onHostStopped(host)
        tracker.onHostResumed(host)
        runScheduledTasks()

        assertEquals(0, shownButton.dismissals)
    }

    @Test
    fun restartsTheWaitWhenTheHostIsPausedAgain() {
        val shownButton = button()

        tracker.onHostPaused(host)
        tracker.onHostResumed(host)
        tracker.onHostPaused(host)
        runScheduledTasks()
        assertEquals(0, shownButton.dismissals)

        tracker.onHostResumed(host)
        runScheduledTasks()

        assertEquals(1, shownButton.dismissals)
    }

    @Test
    fun forgetsAButtonThatIsUnregistered() {
        val shownButton = button()

        tracker.onHostPaused(host)
        tracker.unregister(shownButton)
        tracker.onHostResumed(host)
        runScheduledTasks()

        assertEquals(0, shownButton.dismissals)
    }

    private class FakeButton(
        override val host: Any,
        override val isShown: Boolean,
    ) : ConfirmationTracker.Button {
        var dismissals = 0
            private set

        override fun onConfirmationDismissed() {
            dismissals++
        }
    }

    private class ScheduledTask(val delayMillis: Long, val action: () -> Unit) : Cancellable {
        var isCancelled = false
            private set

        override fun cancel() {
            isCancelled = true
        }
    }
}
