// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package com.batuhandelice.one_tap_location

/**
 * Keeps one session of the system location button open for a platform view.
 *
 * Opening a session takes up to a few seconds. Changes to the size, the configuration or the style
 * that happen in the meantime are applied once the session opens, and callbacks of sessions that
 * were replaced are ignored. An open session keeps the font scale that it was opened with, so a
 * change of the font scale opens a new session.
 */
internal class SessionController(
    private val host: Host,
    style: LocationButtonStyle,
    private val scheduler: Scheduler,
) {
    interface Host {
        val width: Int

        val height: Int

        /** The number of pixels per logical pixel. */
        val density: Float

        /** The font scale of the configuration that sessions are opened with. */
        val fontScale: Float

        /**
         * Opens a session of [width] by [height] pixels. Returns false when the view cannot host a
         * session yet, and throws when no session can be opened at all.
         */
        fun openSession(
            width: Int,
            height: Int,
            appearance: SystemButtonAppearance,
            client: SystemButtonClient,
        ): Boolean

        fun attachSurface(session: SystemButtonSession)

        fun detachSurface()

        fun setSurfaceVisible(isVisible: Boolean)

        fun updateConfiguration(session: SystemButtonSession)

        fun onPermissionResult(isGranted: Boolean)

        fun onUnavailable(message: String)
    }

    private var style = style
    private var session: SystemButtonSession? = null
    private var generation = 0
    private var isOpening = false
    private var openingWidth = 0
    private var openingHeight = 0
    private var openingDensity = 0f
    private var openingFontScale = 0f
    private var openingStyle = style
    private var appliedDensity = 0f
    private var sessionFontScale = 0f
    private var hasConfigurationChangedWhileOpening = false
    private var isVisibleInFlutter = false
    private var recoveryCount = 0
    private var recoveryReset: Cancellable? = null
    private var isUnavailable = false
    private var isDisposed = false

    /** Whether the system button is on screen and accepts taps. */
    val isButtonShown: Boolean
        get() = session != null && isVisibleInFlutter

    fun openIfReady() {
        if (isDisposed || isUnavailable || session != null || isOpening) {
            return
        }
        val width = host.width
        val height = host.height
        if (width == 0 || height == 0) {
            return
        }
        val openGeneration = ++generation
        isOpening = true
        openingWidth = width
        openingHeight = height
        openingDensity = host.density
        openingFontScale = host.fontScale
        openingStyle = style
        hasConfigurationChangedWhileOpening = false
        val isOpened = try {
            host.openSession(
                width,
                height,
                style.toAppearance(openingDensity),
                Client(openGeneration),
            )
        } catch (exception: Exception) {
            isOpening = false
            reportUnavailable(exception)
            return
        }
        if (!isOpened) {
            isOpening = false
        }
    }

    fun close() {
        generation++
        isOpening = false
        val current = session ?: return
        session = null
        host.detachSurface()
        updateSurfaceVisibility()
        closeQuietly(current)
    }

    fun dispose() {
        isDisposed = true
        recoveryReset?.cancel()
        close()
    }

    fun setVisibleInFlutter(isVisible: Boolean) {
        isVisibleInFlutter = isVisible
        updateSurfaceVisibility()
    }

    fun onSizeChanged() {
        if (session == null) {
            openIfReady()
            return
        }
        withSession { it.resize(host.width, host.height) }
    }

    fun onConfigurationChanged() {
        if (session == null) {
            if (isOpening) {
                hasConfigurationChangedWhileOpening = true
            }
            return
        }
        if (host.fontScale != sessionFontScale) {
            close()
            openIfReady()
            return
        }
        withSession {
            host.updateConfiguration(it)
            val density = host.density
            if (density != appliedDensity) {
                it.applyAppearance(style.toAppearance(density))
                appliedDensity = density
            }
        }
    }

    fun updateStyle(newStyle: LocationButtonStyle) {
        if (newStyle == style) {
            return
        }
        val previousStyle = style
        style = newStyle
        if (session == null) {
            return
        }
        if (newStyle.resetsAnyPropertyOf(previousStyle)) {
            close()
            openIfReady()
        } else {
            withSession { it.applyAppearance(newStyle.toAppearance(host.density)) }
        }
    }

    private fun updateSurfaceVisibility() {
        host.setSurfaceVisible(isButtonShown)
    }

    private fun reportUnavailable(error: Throwable) {
        isUnavailable = true
        host.onUnavailable(error.message ?: error.toString())
    }

    // A call on a session whose render service stopped fails before the system reports the error,
    // so a failed call is handled like that error.
    private inline fun withSession(action: (SystemButtonSession) -> Unit) {
        val current = session ?: return
        try {
            action(current)
        } catch (exception: Exception) {
            onSessionFailed(exception)
        }
    }

    private fun onSessionFailed(error: Throwable) {
        val wasOpen = session != null
        generation++
        isOpening = false
        if (wasOpen) {
            val failedSession = session!!
            session = null
            host.detachSurface()
            updateSurfaceVisibility()
            closeQuietly(failedSession)
        }
        // An open session fails when the render service stops, which the system recovers from; a
        // session that never opened will not open later either.
        if (wasOpen && recoveryCount < MAX_RECOVERY_COUNT) {
            recoveryCount++
            openIfReady()
        } else {
            reportUnavailable(error)
        }
    }

    // Recoveries are counted to give up on a service that fails right after every reopen, not on
    // one that stops now and then.
    private fun scheduleRecoveryReset() {
        recoveryReset?.cancel()
        val openGeneration = generation
        recoveryReset = scheduler.schedule(RECOVERY_RESET_DELAY_MILLIS) {
            if (generation == openGeneration && session != null) {
                recoveryCount = 0
            }
        }
    }

    private fun closeQuietly(session: SystemButtonSession) {
        try {
            session.close()
        } catch (exception: Exception) {
            // A session whose render service stopped is already closed.
        }
    }

    private inner class Client(private val openGeneration: Int) : SystemButtonClient {
        override fun onSessionOpened(session: SystemButtonSession) {
            if (isDisposed || openGeneration != generation) {
                closeQuietly(session)
                return
            }
            isOpening = false
            this@SessionController.session = session
            if (style.resetsAnyPropertyOf(openingStyle) || host.fontScale != openingFontScale) {
                close()
                openIfReady()
                return
            }
            sessionFontScale = openingFontScale
            withSession {
                host.attachSurface(it)
                if (host.width != openingWidth || host.height != openingHeight) {
                    it.resize(host.width, host.height)
                }
                if (hasConfigurationChangedWhileOpening) {
                    host.updateConfiguration(it)
                }
                val density = host.density
                if (style != openingStyle || density != openingDensity) {
                    it.applyAppearance(style.toAppearance(density))
                }
                appliedDensity = density
            }
            updateSurfaceVisibility()
            if (recoveryCount > 0) {
                scheduleRecoveryReset()
            }
        }

        override fun onPermissionResult(isGranted: Boolean) {
            // An answer stays valid after the session that asked for it was replaced.
            if (!isDisposed) {
                host.onPermissionResult(isGranted)
            }
        }

        override fun onSessionError(error: Throwable) {
            if (!isDisposed && openGeneration == generation) {
                onSessionFailed(error)
            }
        }
    }

    private companion object {
        const val MAX_RECOVERY_COUNT = 3

        /** How long a reopened session stays open before its recovery no longer counts. */
        const val RECOVERY_RESET_DELAY_MILLIS = 30_000L
    }
}
