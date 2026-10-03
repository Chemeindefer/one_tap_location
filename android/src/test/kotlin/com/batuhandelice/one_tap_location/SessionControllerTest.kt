// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package com.batuhandelice.one_tap_location

import android.content.res.Configuration
import android.view.SurfaceControlViewHost
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class SessionControllerTest {
    private val defaultStyle = LocationButtonStyle(textType = 1)
    private val coloredStyle = defaultStyle.copy(backgroundColor = 0xFF102040.toInt())

    private lateinit var host: FakeHost
    private lateinit var scheduler: FakeScheduler
    private lateinit var controller: SessionController

    @Before
    fun setUp() {
        host = FakeHost()
        scheduler = FakeScheduler()
        controller = SessionController(host, style = defaultStyle, scheduler = scheduler)
    }

    private fun openSession(session: FakeSession = FakeSession()): FakeSession {
        controller.openIfReady()
        host.openRequests.last().client.onSessionOpened(session)
        return session
    }

    @Test
    fun opensASessionOnceTheViewIsReady() {
        host.isReady = false
        controller.openIfReady()
        assertTrue(host.openRequests.isEmpty())

        host.isReady = true
        controller.openIfReady()
        val request = host.openRequests.single()
        val session = FakeSession()
        request.client.onSessionOpened(session)

        assertEquals(300 to 100, request.width to request.height)
        assertEquals(defaultStyle.toAppearance(2f), request.appearance)
        assertSame(session, host.attachedSession)
    }

    @Test
    fun showsTheSurfaceOnlyWhileTheButtonIsVisibleInFlutter() {
        openSession()
        assertFalse(controller.isButtonShown)
        assertEquals(false, host.surfaceVisibility.last())

        controller.setVisibleInFlutter(true)
        assertTrue(controller.isButtonShown)
        assertEquals(true, host.surfaceVisibility.last())

        controller.close()
        assertFalse(controller.isButtonShown)
        assertEquals(false, host.surfaceVisibility.last())
    }

    @Test
    fun opensOneSessionAtATime() {
        controller.openIfReady()
        controller.openIfReady()

        assertEquals(1, host.openRequests.size)
    }

    @Test
    fun resizesASessionThatOpensAfterTheViewChangedSize() {
        controller.openIfReady()
        host.width = 400
        controller.onSizeChanged()
        val session = FakeSession()
        host.openRequests.single().client.onSessionOpened(session)

        assertEquals(listOf(400 to 100), session.resizes)
    }

    @Test
    fun resizesAnOpenSession() {
        val session = openSession()
        host.height = 120

        controller.onSizeChanged()

        assertEquals(listOf(300 to 120), session.resizes)
    }

    @Test
    fun appliesAConfigurationChangeThatHappenedWhileOpening() {
        controller.openIfReady()
        controller.onConfigurationChanged()
        val session = FakeSession()
        host.openRequests.single().client.onSessionOpened(session)

        assertEquals(listOf(session), host.configurationUpdates)
    }

    @Test
    fun appliesTheNewDensityToTheOpenSession() {
        controller = SessionController(
            host,
            style = defaultStyle.copy(cornerRadius = 24.0),
            scheduler = scheduler,
        )
        val session = openSession()
        host.density = 3f

        controller.onConfigurationChanged()

        assertEquals(listOf(session), host.configurationUpdates)
        assertEquals(72f, session.appearances.single().cornerRadius)
    }

    @Test
    fun reopensTheSessionWhenTheFontScaleChanges() {
        val session = openSession()
        controller.setVisibleInFlutter(true)
        host.fontScale = 1.3f

        controller.onConfigurationChanged()

        assertTrue(session.isClosed)
        assertTrue(host.configurationUpdates.isEmpty())
        assertFalse(controller.isButtonShown)
        assertEquals(2, host.openRequests.size)

        host.openRequests.last().client.onSessionOpened(FakeSession())

        assertTrue(controller.isButtonShown)
    }

    @Test
    fun reopensWhenTheFontScaleChangedWhileOpening() {
        controller.openIfReady()
        host.fontScale = 1.3f
        controller.onConfigurationChanged()
        val session = FakeSession()

        host.openRequests.single().client.onSessionOpened(session)

        assertTrue(session.isClosed)
        assertNull(host.attachedSession)
        assertEquals(2, host.openRequests.size)

        val reopenedSession = FakeSession()
        host.openRequests.last().client.onSessionOpened(reopenedSession)
        controller.onConfigurationChanged()

        assertSame(reopenedSession, host.attachedSession)
        assertFalse(reopenedSession.isClosed)
        assertEquals(listOf<SystemButtonSession>(reopenedSession), host.configurationUpdates)
    }

    @Test
    fun closesASessionThatOpensAfterItWasReplaced() {
        controller.openIfReady()
        val replacedRequest = host.openRequests.single()
        controller.close()
        controller.openIfReady()
        val replacedSession = FakeSession(failingCall = "close")

        replacedRequest.client.onSessionOpened(replacedSession)

        assertTrue(replacedSession.isClosed)
        assertNull(host.attachedSession)
        assertEquals(2, host.openRequests.size)
    }

    @Test
    fun closesTheSessionWhenDisposed() {
        val session = openSession()

        controller.dispose()
        controller.openIfReady()

        assertTrue(session.isClosed)
        assertNull(host.attachedSession)
        assertEquals(1, host.openRequests.size)
    }

    @Test
    fun appliesAStyleChangeToTheOpenSession() {
        val session = openSession()

        controller.updateStyle(coloredStyle)

        assertEquals(listOf(coloredStyle.toAppearance(2f)), session.appearances)
        assertFalse(session.isClosed)
        assertEquals(1, host.openRequests.size)
    }

    @Test
    fun reopensTheSessionWhenAPropertyReturnsToItsDefault() {
        controller = SessionController(host, style = coloredStyle, scheduler = scheduler)
        val session = openSession()

        controller.updateStyle(defaultStyle)

        assertTrue(session.isClosed)
        assertEquals(defaultStyle.toAppearance(2f), host.openRequests.last().appearance)
        assertEquals(2, host.openRequests.size)
    }

    @Test
    fun appliesAStyleChangeThatHappenedWhileOpening() {
        controller.openIfReady()
        controller.updateStyle(coloredStyle)
        val session = FakeSession()
        host.openRequests.single().client.onSessionOpened(session)

        assertEquals(listOf(coloredStyle.toAppearance(2f)), session.appearances)
        assertEquals(1, host.openRequests.size)
    }

    @Test
    fun reopensWhenAPropertyReturnedToItsDefaultWhileOpening() {
        controller = SessionController(host, style = coloredStyle, scheduler = scheduler)
        controller.openIfReady()
        controller.updateStyle(defaultStyle)
        controller.setVisibleInFlutter(true)
        val session = FakeSession()

        host.openRequests.single().client.onSessionOpened(session)

        assertTrue(session.isClosed)
        assertNull(host.attachedSession)
        assertFalse(controller.isButtonShown)
        assertEquals(defaultStyle.toAppearance(2f), host.openRequests.last().appearance)
        assertEquals(2, host.openRequests.size)

        host.openRequests.last().client.onSessionOpened(FakeSession())

        assertTrue(controller.isButtonShown)
        assertEquals(true, host.surfaceVisibility.last())
    }

    @Test
    fun reportsASessionThatCannotBeOpened() {
        host.openError = IllegalStateException("The app must declare ACCESS_FINE_LOCATION.")

        controller.openIfReady()
        controller.openIfReady()

        assertEquals(listOf("The app must declare ACCESS_FINE_LOCATION."), host.unavailableMessages)
    }

    @Test
    fun reportsASessionThatFailsBeforeOpening() {
        controller.openIfReady()

        host.openRequests.single().client.onSessionError(SecurityException("Unable to bind."))
        controller.openIfReady()

        assertEquals(listOf("Unable to bind."), host.unavailableMessages)
        assertEquals(1, host.openRequests.size)
    }

    @Test
    fun reopensASessionThatFailsAfterOpening() {
        openSession()
        controller.setVisibleInFlutter(true)

        host.openRequests.single().client.onSessionError(IllegalStateException("Service died."))

        assertNull(host.attachedSession)
        assertEquals(false, host.surfaceVisibility.last())
        assertEquals(2, host.openRequests.size)
        assertTrue(host.unavailableMessages.isEmpty())

        host.openRequests.last().client.onSessionOpened(FakeSession())

        assertTrue(controller.isButtonShown)
        assertEquals(true, host.surfaceVisibility.last())
    }

    @Test
    fun showsTheSurfaceOfASessionThatOpensAfterTheButtonBecameVisible() {
        controller.setVisibleInFlutter(true)
        assertFalse(controller.isButtonShown)

        openSession()

        assertTrue(controller.isButtonShown)
        assertEquals(true, host.surfaceVisibility.last())
    }

    @Test
    fun reopensASessionWhoseCallFails() {
        val session = openSession(FakeSession(failingCall = "resize"))
        val failedClient = host.openRequests.single().client
        host.width = 400

        controller.onSizeChanged()
        failedClient.onSessionError(IllegalStateException("Service died."))

        assertTrue(session.isClosed)
        assertNull(host.attachedSession)
        assertEquals(2, host.openRequests.size)
        assertTrue(host.unavailableMessages.isEmpty())
    }

    @Test
    fun reportsASessionThatKeepsFailing() {
        controller.openIfReady()
        repeat(4) {
            val request = host.openRequests.last()
            request.client.onSessionOpened(FakeSession())
            request.client.onSessionError(IllegalStateException("Service died."))
        }

        assertEquals(4, host.openRequests.size)
        assertEquals(listOf("Service died."), host.unavailableMessages)
    }

    @Test
    fun recoversAgainOnceAReopenedSessionStayedOpen() {
        controller.openIfReady()
        repeat(6) {
            val request = host.openRequests.last()
            request.client.onSessionOpened(FakeSession())
            scheduler.runPendingActions()
            request.client.onSessionError(IllegalStateException("Service died."))
        }

        assertEquals(7, host.openRequests.size)
        assertTrue(host.unavailableMessages.isEmpty())
    }

    @Test
    fun ignoresTheErrorOfAReplacedSession() {
        controller.openIfReady()
        val replacedRequest = host.openRequests.single()
        controller.close()
        controller.openIfReady()

        replacedRequest.client.onSessionError(IllegalStateException("Service died."))

        assertTrue(host.unavailableMessages.isEmpty())
    }

    @Test
    fun forwardsAnswersUntilDisposed() {
        controller.openIfReady()
        val client = host.openRequests.single().client

        client.onPermissionResult(true)
        controller.dispose()
        client.onPermissionResult(false)

        assertEquals(listOf(true), host.answers)
    }

    private class OpenRequest(
        val width: Int,
        val height: Int,
        val appearance: SystemButtonAppearance,
        val client: SystemButtonClient,
    )

    private class FakeHost : SessionController.Host {
        var isReady = true
        var openError: Exception? = null
        override var width = 300
        override var height = 100
        override var density = 2f
        override var fontScale = 1f
        val openRequests = mutableListOf<OpenRequest>()
        var attachedSession: SystemButtonSession? = null
            private set
        val surfaceVisibility = mutableListOf<Boolean>()
        val configurationUpdates = mutableListOf<SystemButtonSession>()
        val answers = mutableListOf<Boolean>()
        val unavailableMessages = mutableListOf<String>()

        override fun openSession(
            width: Int,
            height: Int,
            appearance: SystemButtonAppearance,
            client: SystemButtonClient,
        ): Boolean {
            openError?.let { throw it }
            if (!isReady) {
                return false
            }
            openRequests += OpenRequest(width, height, appearance, client)
            return true
        }

        override fun attachSurface(session: SystemButtonSession) {
            attachedSession = session
        }

        override fun detachSurface() {
            attachedSession = null
        }

        override fun setSurfaceVisible(isVisible: Boolean) {
            surfaceVisibility += isVisible
        }

        override fun updateConfiguration(session: SystemButtonSession) {
            configurationUpdates += session
        }

        override fun onPermissionResult(isGranted: Boolean) {
            answers += isGranted
        }

        override fun onUnavailable(message: String) {
            unavailableMessages += message
        }
    }

    private class FakeScheduler : Scheduler {
        private val actions = mutableListOf<() -> Unit>()
        private val cancelledActions = mutableSetOf<() -> Unit>()

        override fun schedule(delayMillis: Long, action: () -> Unit): Cancellable {
            actions += action
            return Cancellable { cancelledActions += action }
        }

        fun runPendingActions() {
            val pending = actions.filterNot { it in cancelledActions }
            actions.clear()
            pending.forEach { it() }
        }
    }

    private class FakeSession(private val failingCall: String? = null) : SystemButtonSession {
        val resizes = mutableListOf<Pair<Int, Int>>()
        val appearances = mutableListOf<SystemButtonAppearance>()
        var isClosed = false
            private set

        override val surfacePackage: SurfaceControlViewHost.SurfacePackage
            get() = throw UnsupportedOperationException()

        override fun resize(width: Int, height: Int) {
            failIfRequested("resize")
            resizes += width to height
        }

        override fun changeConfiguration(configuration: Configuration) = Unit

        override fun applyAppearance(appearance: SystemButtonAppearance) {
            failIfRequested("applyAppearance")
            appearances += appearance
        }

        override fun close() {
            isClosed = true
            failIfRequested("close")
        }

        private fun failIfRequested(call: String) {
            if (call == failingCall) {
                throw IllegalStateException("The render service stopped.")
            }
        }
    }
}
