// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package com.batuhandelice.one_tap_location

import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

/** Shared by the plugin instances of all Flutter engines in the process. */
private val confirmationTracker by lazy {
    ConfirmationTracker(MainThreadScheduler(), TaskTopActivity)
}

class OneTapLocationPlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler {
    private val hostActivity = HostActivity()
    private lateinit var fallback: FallbackController
    private val permissionResultListener =
        PluginRegistry.RequestPermissionsResultListener { requestCode, permissions, grantResults ->
            fallback.onRequestPermissionsResult(requestCode, permissions, grantResults)
        }
    private lateinit var applicationContext: Context
    private var channel: MethodChannel? = null
    private var activityBinding: ActivityPluginBinding? = null

    init {
        hostActivity.addListener(
            object : HostActivity.Listener {
                override fun onHostPaused(activity: Activity) {
                    confirmationTracker.onHostPaused(activity)
                }

                override fun onHostStopped(activity: Activity) {
                    confirmationTracker.onHostStopped(activity)
                }

                override fun onHostResumed(activity: Activity) {
                    confirmationTracker.onHostResumed(activity)
                }
            },
        )
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        fallback = FallbackController(
            permissionRequester = LocationPermissionRequester(),
            positionRequests = PositionRequests(
                LocationManagerPositionSource(
                    SystemLocationManagerBackend(binding.applicationContext),
                    MainThreadScheduler(),
                ),
            ),
        )
        channel = MethodChannel(binding.binaryMessenger, "one_tap_location").also {
            it.setMethodCallHandler(this)
        }
        binding.platformViewRegistry.registerViewFactory(
            "one_tap_location/location_button",
            LocationButtonFactory(binding.binaryMessenger, hostActivity, confirmationTracker),
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        fallback.dispose()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getAvailability" -> result.success(
                LocationCodec.availability(
                    isSystemButtonAvailable = SystemButtonProvider.isAvailable(applicationContext),
                    isPreciseLocationRestrictedToSystemButton =
                        applicationContext.restrictsPreciseLocationToSystemButton(),
                ),
            )
            "requestFallbackPermission" -> fallback.requestPermission(result.asCallReply())
            "requestFallbackPosition" ->
                fallback.requestPosition(call.arguments as Int, result.asCallReply())
            "cancelFallbackPosition" ->
                fallback.cancelPosition(call.arguments as Int, result.asCallReply())
            else -> result.notImplemented()
        }
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        attachToActivity(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        detachFromActivity(isRecreating = true)
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        attachToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        detachFromActivity(isRecreating = false)
    }

    private fun attachToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addRequestPermissionsResultListener(permissionResultListener)
        hostActivity.attach(binding.activity)
        fallback.onHostAttached(ActivityFallbackHost(binding.activity))
    }

    private fun detachFromActivity(isRecreating: Boolean) {
        activityBinding?.removeRequestPermissionsResultListener(permissionResultListener)
        activityBinding = null
        hostActivity.detach()
        fallback.onHostDetached(isRecreating)
    }
}

private fun MethodChannel.Result.asCallReply(): CallReply {
    val result = this
    return object : CallReply {
        override fun success(value: Any?) {
            result.success(value)
        }

        override fun error(code: String, message: String) {
            result.error(code, message, null)
        }
    }
}

private class ActivityFallbackHost(private val activity: Activity) : FallbackHost {
    override val declaredPermissions: Set<String>
        get() = activity.declaredPermissions()

    override val restrictsPreciseLocationToSystemButton: Boolean by lazy {
        activity.restrictsPreciseLocationToSystemButton()
    }

    override fun isGranted(permission: String): Boolean =
        activity.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED

    override fun requestPermissions(permissions: Array<String>, requestCode: Int) {
        activity.requestPermissions(permissions, requestCode)
    }
}
