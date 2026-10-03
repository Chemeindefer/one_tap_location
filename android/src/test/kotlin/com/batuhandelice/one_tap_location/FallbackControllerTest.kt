// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package com.batuhandelice.one_tap_location

import android.Manifest
import android.content.pm.PackageManager
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class FallbackControllerTest {
    private val position = Position(
        latitude = 41.0082,
        longitude = 28.9784,
        timestampMillis = 1_757_800_000_000,
        isPrecise = true,
        horizontalAccuracy = 5.0,
        altitude = null,
    )
    private val sourceRequests = mutableListOf<SourceRequest>()
    private val controller = FallbackController(
        permissionRequester = LocationPermissionRequester(),
        positionRequests = PositionRequests { callback ->
            SourceRequest(callback).also { sourceRequests += it }
        },
    )
    private val host = FakeHost()

    private fun answerDialog(host: FakeHost, vararg grantResults: Int): Boolean =
        controller.onRequestPermissionsResult(
            host.requestCodes.last(),
            LOCATION_PERMISSIONS.toTypedArray(),
            grantResults,
        )

    @Test
    fun reportsAMissingActivity() {
        val reply = RecordingReply()

        controller.requestPermission(reply)

        assertEquals(listOf(Reply.Error("noActivity")), reply.replies)
    }

    @Test
    fun reportsAnUndeclaredPermissionWithoutAsking() {
        host.declaredPermissions = setOf(Manifest.permission.ACCESS_FINE_LOCATION)
        controller.onHostAttached(host)
        val reply = RecordingReply()

        controller.requestPermission(reply)

        assertEquals(listOf(Reply.Error("missingPermission")), reply.replies)
        assertTrue(reply.messages.single().contains(Manifest.permission.ACCESS_COARSE_LOCATION))
        assertTrue(host.requestCodes.isEmpty())
    }

    @Test
    fun repliesWithTheAnswerOfTheDialog() {
        controller.onHostAttached(host)
        val reply = RecordingReply()

        controller.requestPermission(reply)
        answerDialog(host, GRANTED, GRANTED)

        assertEquals(listOf(Reply.Success("granted")), reply.replies)
    }

    @Test
    fun keepsTheRequestWhileTheActivityIsRecreated() {
        controller.onHostAttached(host)
        val reply = RecordingReply()
        controller.requestPermission(reply)

        controller.onHostDetached(isRecreating = true)
        val recreatedHost = FakeHost()
        controller.onHostAttached(recreatedHost)
        answerDialog(host, GRANTED, GRANTED)

        assertEquals(listOf(Reply.Success("granted")), reply.replies)
    }

    @Test
    fun cancelsTheRequestWhenTheActivityGoesAway() {
        controller.onHostAttached(host)
        val reply = RecordingReply()
        controller.requestPermission(reply)

        controller.onHostDetached(isRecreating = false)
        val isHandled = answerDialog(host, GRANTED, GRANTED)
        val laterReply = RecordingReply()
        controller.requestPermission(laterReply)

        assertTrue(isHandled)
        assertEquals(listOf(Reply.Success("cancelled")), reply.replies)
        assertEquals(listOf(Reply.Error("noActivity")), laterReply.replies)
    }

    @Test
    fun repliesWithThePosition() {
        val reply = RecordingReply()

        controller.requestPosition(7, reply)
        sourceRequests.single().callback(PositionOutcome.Available(position))

        assertEquals(
            listOf(Reply.Success(LocationCodec.result(LocationRequestEvent.Granted(position)))),
            reply.replies,
        )
    }

    @Test
    fun repliesToACancelledPositionRequest() {
        val positionReply = RecordingReply()
        val cancelReply = RecordingReply()
        controller.requestPosition(7, positionReply)

        controller.cancelPosition(7, cancelReply)
        sourceRequests.single().callback(PositionOutcome.Available(position))

        assertEquals(listOf(Reply.Success(null)), positionReply.replies)
        assertEquals(listOf(Reply.Success(null)), cancelReply.replies)
        assertTrue(sourceRequests.single().isCancelled)
    }

    @Test
    fun answersPendingCallsWhenDisposed() {
        controller.onHostAttached(host)
        val permissionReply = RecordingReply()
        val positionReply = RecordingReply()
        controller.requestPermission(permissionReply)
        controller.requestPosition(7, positionReply)

        controller.dispose()

        assertEquals(listOf(Reply.Success("cancelled")), permissionReply.replies)
        assertEquals(listOf(Reply.Success(null)), positionReply.replies)
        assertTrue(sourceRequests.single().isCancelled)
    }

    private sealed interface Reply {
        data class Success(val value: Any?) : Reply

        data class Error(val code: String) : Reply
    }

    private class RecordingReply : CallReply {
        val replies = mutableListOf<Reply>()
        val messages = mutableListOf<String>()

        override fun success(value: Any?) {
            replies += Reply.Success(value)
        }

        override fun error(code: String, message: String) {
            replies += Reply.Error(code)
            messages += message
        }
    }

    private class SourceRequest(val callback: (PositionOutcome) -> Unit) : Cancellable {
        var isCancelled = false
            private set

        override fun cancel() {
            isCancelled = true
        }
    }

    private class FakeHost : FallbackHost {
        override var declaredPermissions: Set<String> = LOCATION_PERMISSIONS.toSet()
        override val restrictsPreciseLocationToSystemButton = false
        val requestCodes = mutableListOf<Int>()

        override fun isGranted(permission: String): Boolean = false

        override fun requestPermissions(permissions: Array<String>, requestCode: Int) {
            requestCodes += requestCode
        }
    }

    private companion object {
        const val GRANTED = PackageManager.PERMISSION_GRANTED
    }
}
