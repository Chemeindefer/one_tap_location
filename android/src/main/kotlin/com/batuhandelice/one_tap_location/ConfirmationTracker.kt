// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package com.batuhandelice.one_tap_location

/** Tells which screen paused the activity that hosts a button. */
internal fun interface PausingScreen {
    /**
     * Whether the screen that paused [host] can be the system confirmation. True when the screen
     * cannot be identified.
     */
    fun canBeConfirmation(host: Any): Boolean
}

/**
 * Detects system confirmations that were closed without an answer.
 *
 * The system confirmation pauses the activity that hosts the tapped button without stopping it, and
 * an answered confirmation delivers its answer before the activity resumes. A resume that is not
 * followed by an answer within [ANSWER_TIMEOUT_MILLIS] means that the confirmation was dismissed.
 * Other screens pause the host in the same way, for example a permission dialog of the app, so a
 * pause counts only when [pausingScreen] does not rule out the confirmation.
 *
 * One tracker serves every button of the process: only the session whose button was tapped receives
 * the answer, and buttons of several Flutter engines can share an activity. Hosts are identified by
 * the activity object, and repeated lifecycle events for the same host have no further effect.
 */
internal class ConfirmationTracker(
    private val scheduler: Scheduler,
    private val pausingScreen: PausingScreen,
) {
    interface Button {
        /** The activity that hosts the button, or null while it has none. */
        val host: Any?

        val isShown: Boolean

        fun onConfirmationDismissed()
    }

    private class Wait(var dismissedButton: Button?) {
        var answerCheck: Cancellable? = null
    }

    private val buttons = LinkedHashSet<Button>()
    private val waits = HashMap<Any, Wait>()

    fun register(button: Button) {
        buttons.add(button)
    }

    fun unregister(button: Button) {
        buttons.remove(button)
        for (wait in waits.values) {
            if (wait.dismissedButton === button) {
                wait.dismissedButton = null
            }
        }
    }

    /** Called when a session of a button hosted by [host] receives an answer. */
    fun onAnswer(host: Any) {
        reset(host)
    }

    fun onHostPaused(host: Any) {
        val wait = waits[host]
        if (wait != null) {
            wait.answerCheck?.cancel()
            wait.answerCheck = null
            return
        }
        val shownButtons = buttons.filter { it.host === host && it.isShown }
        if (shownButtons.isNotEmpty() && pausingScreen.canBeConfirmation(host)) {
            // When several buttons are shown, the one that was tapped is unknown.
            waits[host] = Wait(shownButtons.singleOrNull())
        }
    }

    fun onHostStopped(host: Any) {
        // The confirmation never stops the host, so the user left the app instead.
        reset(host)
    }

    fun onHostResumed(host: Any) {
        val wait = waits[host] ?: return
        wait.answerCheck?.cancel()
        wait.answerCheck = scheduler.schedule(ANSWER_TIMEOUT_MILLIS) {
            if (waits[host] === wait) {
                waits.remove(host)
                wait.dismissedButton?.onConfirmationDismissed()
            }
        }
    }

    private fun reset(host: Any) {
        waits.remove(host)?.answerCheck?.cancel()
    }

    companion object {
        /**
         * How long to wait for an answer after the host resumes. Answers arrive before the host
         * resumes, so the delay only absorbs scheduling jitter.
         */
        const val ANSWER_TIMEOUT_MILLIS = 1_000L
    }
}
