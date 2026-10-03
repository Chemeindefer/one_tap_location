// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package com.batuhandelice.one_tap_location

import android.Manifest
import android.content.pm.PackageManager

/** The permissions that the fallback button requests. */
internal val LOCATION_PERMISSIONS = listOf(
    Manifest.permission.ACCESS_FINE_LOCATION,
    Manifest.permission.ACCESS_COARSE_LOCATION,
)

/**
 * Identifies the answers to the requests of this plugin. Stays below 0x10000 because the
 * ActivityResultRegistry of an androidx activity gives its launchers request codes from 0x10000 up,
 * so the answer never reaches a launcher of the host app.
 */
private const val REQUEST_CODE = 0x4F54

internal enum class PermissionAnswer(val wireName: String) {
    GRANTED("granted"),

    /**
     * Access was denied, including a dialog that the user closed without answering while the app
     * had no location access, which Android 11 and later report as a denial. Before Android 11,
     * Back does not close the dialog.
     */
    DENIED("denied"),

    /** The request was interrupted before the user answered. */
    CANCELLED("cancelled"),
}

/** The activity that shows the permission dialog. */
internal interface PermissionHost {
    /** Whether the app can obtain precise access only through the system location button. */
    val restrictsPreciseLocationToSystemButton: Boolean

    fun isGranted(permission: String): Boolean

    fun requestPermissions(permissions: Array<String>, requestCode: Int)
}

/**
 * Requests location access through the permission dialog of the system, for devices without the
 * system location button.
 *
 * Requests made while the dialog is shown receive its answer. Precise access is requested even when
 * approximate access was granted before, so that the user can change to precise access, unless the
 * app restricts precise access to the system location button, which the dialog cannot grant.
 */
internal class LocationPermissionRequester {
    private val waitingCallbacks = ArrayList<(PermissionAnswer) -> Unit>()

    fun request(host: PermissionHost, callback: (PermissionAnswer) -> Unit) {
        if (host.isGranted(Manifest.permission.ACCESS_FINE_LOCATION) ||
            (
                host.isGranted(Manifest.permission.ACCESS_COARSE_LOCATION) &&
                    host.restrictsPreciseLocationToSystemButton
            )
        ) {
            callback(PermissionAnswer.GRANTED)
            return
        }
        waitingCallbacks += callback
        if (waitingCallbacks.size == 1) {
            host.requestPermissions(LOCATION_PERMISSIONS.toTypedArray(), REQUEST_CODE)
        }
    }

    /** Answers the waiting requests when the activity that shows the dialog goes away. */
    fun cancel() {
        answer(PermissionAnswer.CANCELLED)
    }

    fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != REQUEST_CODE) {
            return false
        }
        answer(permissionAnswer(permissions, grantResults))
        return true
    }

    private fun answer(answer: PermissionAnswer) {
        val callbacks = waitingCallbacks.toList()
        waitingCallbacks.clear()
        callbacks.forEach { it(answer) }
    }
}

/** Maps the results of a permission request. An interrupted request has no results. */
internal fun permissionAnswer(
    permissions: Array<out String>,
    grantResults: IntArray,
): PermissionAnswer =
    when {
        grantResults.isEmpty() -> PermissionAnswer.CANCELLED
        permissions.zip(grantResults.asList()).any { (permission, result) ->
            permission in LOCATION_PERMISSIONS && result == PackageManager.PERMISSION_GRANTED
        } -> PermissionAnswer.GRANTED
        else -> PermissionAnswer.DENIED
    }
