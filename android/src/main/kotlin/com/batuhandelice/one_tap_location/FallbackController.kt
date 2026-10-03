// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package com.batuhandelice.one_tap_location

/** The reply to a method call from the Dart side. */
internal interface CallReply {
    fun success(value: Any?)

    fun error(code: String, message: String)
}

/** The activity that hosts the fallback buttons. */
internal interface FallbackHost : PermissionHost {
    /** The permissions that the app declares, including those merged from its libraries. */
    val declaredPermissions: Set<String>
}

/**
 * Handles the method calls of the fallback buttons and ties their requests to the activity and the
 * engine.
 *
 * A permission dialog survives an activity that is recreated for a configuration change, so waiting
 * requests are answered only when the activity goes away for good. Every call is replied to once.
 */
internal class FallbackController(
    private val permissionRequester: LocationPermissionRequester,
    private val positionRequests: PositionRequests,
) {
    private var host: FallbackHost? = null

    fun onHostAttached(host: FallbackHost) {
        this.host = host
    }

    fun onHostDetached(isRecreating: Boolean) {
        host = null
        if (!isRecreating) {
            permissionRequester.cancel()
        }
    }

    fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean =
        permissionRequester.onRequestPermissionsResult(requestCode, permissions, grantResults)

    fun requestPermission(reply: CallReply) {
        val host = host
        if (host == null) {
            reply.error(
                "noActivity",
                "Location access can be requested only while the app is attached to an activity.",
            )
            return
        }
        val undeclaredPermissions = LOCATION_PERMISSIONS - host.declaredPermissions
        if (undeclaredPermissions.isNotEmpty()) {
            reply.error(
                "missingPermission",
                "The app must declare ${undeclaredPermissions.joinToString(" and ")} in its " +
                    "AndroidManifest.xml.",
            )
            return
        }
        permissionRequester.request(host) { answer -> reply.success(answer.wireName) }
    }

    fun requestPosition(requestId: Int, reply: CallReply) {
        positionRequests.start(requestId) { outcome ->
            reply.success(outcome?.let { LocationCodec.result(it.toResult()) })
        }
    }

    fun cancelPosition(requestId: Int, reply: CallReply) {
        positionRequests.cancel(requestId)
        reply.success(null)
    }

    /** Answers every pending call when the engine detaches. */
    fun dispose() {
        host = null
        permissionRequester.cancel()
        positionRequests.cancelAll()
    }
}
