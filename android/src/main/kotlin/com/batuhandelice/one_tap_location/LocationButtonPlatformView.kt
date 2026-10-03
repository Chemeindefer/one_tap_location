// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package com.batuhandelice.one_tap_location

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.res.Configuration
import android.graphics.PixelFormat
import android.os.IBinder
import android.view.Display
import android.view.SurfaceView
import android.view.View
import android.widget.FrameLayout
import androidx.annotation.RequiresApi
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView

/** Places the embedded surface above the host window, the only order that receives touches. */
private const val COMPOSITION_ORDER_ABOVE_HOST = 1

/**
 * Hosts the system location button in a Flutter platform view.
 *
 * The system draws the button in its own window, embedded through a [SurfaceView]. Flutter does not
 * clip, fade or cover that window, so the button stays hidden until the Dart side reports that its
 * area is fully visible.
 */
@RequiresApi(SYSTEM_BUTTON_API_LEVEL)
internal class LocationButtonPlatformView(
    private val context: Context,
    viewId: Int,
    messenger: BinaryMessenger,
    private val hostActivity: HostActivity,
    private val confirmationTracker: ConfirmationTracker,
    style: LocationButtonStyle,
) : PlatformView,
    MethodChannel.MethodCallHandler,
    HostActivity.Listener,
    ConfirmationTracker.Button {

    private val channel = MethodChannel(messenger, "one_tap_location/location_button/$viewId")
    private val surfaceView = SurfaceView(context).apply {
        holder.setFormat(PixelFormat.TRANSPARENT)
        visibility = View.INVISIBLE
    }
    private val hostView = HostView(context)
    private val sessionController = SessionController(
        host = SessionHost(),
        style = style,
        scheduler = MainThreadScheduler(),
    )
    private val coordinator = LocationRequestCoordinator(
        positionSource = LocationManagerPositionSource(
            SystemLocationManagerBackend(context.applicationContext),
            MainThreadScheduler(),
        ),
        onEvent = { event ->
            val message = LocationCodec.message(event)
            channel.invokeMethod(message.method, message.arguments)
        },
    )
    private val declaresFineLocation: Boolean by lazy {
        Manifest.permission.ACCESS_FINE_LOCATION in context.declaredPermissions()
    }
    private var provider: SystemButtonProvider? = null

    override val host: Any?
        get() = hostActivity.activity

    override val isShown: Boolean
        get() = sessionController.isButtonShown

    init {
        channel.setMethodCallHandler(this)
        hostActivity.addListener(this)
        confirmationTracker.register(this)
    }

    override fun getView(): View = hostView

    override fun dispose() {
        channel.setMethodCallHandler(null)
        hostActivity.removeListener(this)
        confirmationTracker.unregister(this)
        sessionController.dispose()
        coordinator.dispose()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setVisible" -> {
                sessionController.setVisibleInFlutter(call.arguments as Boolean)
                result.success(null)
            }
            "setStyle" -> {
                sessionController.updateStyle(LocationButtonStyle.decode(call.arguments))
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onHostAttached(activity: Activity) {
        sessionController.openIfReady()
    }

    override fun onConfirmationDismissed() {
        coordinator.onConfirmationDismissed()
    }

    private inner class SessionHost : SessionController.Host {
        override val width: Int
            get() = hostView.width

        override val height: Int
            get() = hostView.height

        override val density: Float
            get() = hostView.resources.displayMetrics.density

        override val fontScale: Float
            get() = hostView.resources.configuration.fontScale

        override fun openSession(
            width: Int,
            height: Int,
            appearance: SystemButtonAppearance,
            client: SystemButtonClient,
        ): Boolean {
            if (!hostView.isAttachedToWindow) {
                return false
            }
            val activity = hostActivity.activity ?: return false
            // The provider accepts only the host token, which has no replacement API.
            @Suppress("DEPRECATION")
            val hostToken: IBinder = surfaceView.hostToken ?: return false
            check(declaresFineLocation) {
                "The app must declare ${Manifest.permission.ACCESS_FINE_LOCATION} in its " +
                    "AndroidManifest.xml."
            }
            val provider = provider
                ?: SystemButtonProvider.create(context.applicationContext)?.also { provider = it }
                ?: error("The system location button is not available on this device.")
            provider.openSession(
                activity = activity,
                hostToken = hostToken,
                displayId = surfaceView.display?.displayId ?: Display.DEFAULT_DISPLAY,
                width = width,
                height = height,
                appearance = appearance,
                executor = context.mainExecutor,
                client = client,
            )
            return true
        }

        override fun attachSurface(session: SystemButtonSession) {
            surfaceView.setChildSurfacePackage(session.surfacePackage)
            surfaceView.setCompositionOrder(COMPOSITION_ORDER_ABOVE_HOST)
        }

        override fun detachSurface() {
            surfaceView.clearChildSurfacePackage()
        }

        override fun setSurfaceVisible(isVisible: Boolean) {
            surfaceView.visibility = if (isVisible) View.VISIBLE else View.INVISIBLE
        }

        override fun updateConfiguration(session: SystemButtonSession) {
            session.changeConfiguration(hostView.resources.configuration)
        }

        override fun onPermissionResult(isGranted: Boolean) {
            hostActivity.activity?.let(confirmationTracker::onAnswer)
            coordinator.onPermissionResult(isGranted)
        }

        override fun onUnavailable(message: String) {
            channel.invokeMethod("onUnavailable", mapOf("message" to message))
        }
    }

    private inner class HostView(context: Context) : FrameLayout(context) {
        init {
            addView(surfaceView, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
            // Flutter adds this view to the accessibility tree in place of the semantics node of
            // the platform view. Accessibility services cannot fetch a view that is not important
            // for accessibility, so the button would be reachable by touch but skipped when swiping
            // through the screen. A view with a delegate is important unless Flutter hides it.
            accessibilityDelegate = AccessibilityDelegate()
        }

        // The host token and the size are final only after the current layout pass, so sessions are
        // opened and resized from the next message.
        override fun onAttachedToWindow() {
            super.onAttachedToWindow()
            post { sessionController.openIfReady() }
        }

        override fun onSizeChanged(width: Int, height: Int, oldWidth: Int, oldHeight: Int) {
            super.onSizeChanged(width, height, oldWidth, oldHeight)
            post { sessionController.onSizeChanged() }
        }

        override fun onConfigurationChanged(newConfig: Configuration) {
            super.onConfigurationChanged(newConfig)
            sessionController.onConfigurationChanged()
        }

        override fun onDetachedFromWindow() {
            sessionController.close()
            super.onDetachedFromWindow()
        }
    }
}
