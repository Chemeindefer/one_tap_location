// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package com.batuhandelice.one_tap_location

import android.Manifest
import android.content.pm.PackageManager
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class LocationPermissionRequesterTest {
    private val host = FakeHost()
    private val requester = LocationPermissionRequester()
    private val answers = mutableListOf<PermissionAnswer>()

    private fun request() {
        requester.request(host) { answers += it }
    }

    private fun answerDialog(vararg grantResults: Int): Boolean =
        requester.onRequestPermissionsResult(
            host.requests.last().requestCode,
            if (grantResults.isEmpty()) emptyArray() else LOCATION_PERMISSIONS.toTypedArray(),
            grantResults,
        )

    @Test
    fun grantsWithoutADialogWhenPreciseAccessIsGranted() {
        host.grantedPermissions += Manifest.permission.ACCESS_FINE_LOCATION

        request()

        assertEquals(listOf(PermissionAnswer.GRANTED), answers)
        assertTrue(host.requests.isEmpty())
    }

    @Test
    fun asksForPreciseAccessWhenApproximateAccessIsGranted() {
        host.grantedPermissions += Manifest.permission.ACCESS_COARSE_LOCATION

        request()

        assertEquals(LOCATION_PERMISSIONS, host.requests.single().permissions)
        assertTrue(answers.isEmpty())
    }

    @Test
    fun grantsWithoutADialogWhenApproximateAccessIsAllTheDialogCanGrant() {
        host.restrictsPreciseLocationToSystemButton = true
        host.grantedPermissions += Manifest.permission.ACCESS_COARSE_LOCATION

        request()

        assertEquals(listOf(PermissionAnswer.GRANTED), answers)
        assertTrue(host.requests.isEmpty())
    }

    @Test
    fun asksForAccessWhenPreciseAccessIsRestrictedAndNothingIsGranted() {
        host.restrictsPreciseLocationToSystemButton = true

        request()

        assertEquals(LOCATION_PERMISSIONS, host.requests.single().permissions)
        assertTrue(answers.isEmpty())
    }

    @Test
    fun reportsPreciseAccess() {
        request()

        assertTrue(answerDialog(GRANTED, GRANTED))
        assertEquals(listOf(PermissionAnswer.GRANTED), answers)
    }

    @Test
    fun reportsApproximateAccessAsGranted() {
        request()

        answerDialog(DENIED, GRANTED)

        assertEquals(listOf(PermissionAnswer.GRANTED), answers)
    }

    @Test
    fun reportsADeniedRequest() {
        request()

        answerDialog(DENIED, DENIED)

        assertEquals(listOf(PermissionAnswer.DENIED), answers)
    }

    @Test
    fun reportsAnInterruptedRequestAsCancelled() {
        request()

        answerDialog()

        assertEquals(listOf(PermissionAnswer.CANCELLED), answers)
    }

    @Test
    fun answersAllRequestsThatWaitForTheDialog() {
        request()
        request()

        answerDialog(GRANTED, GRANTED)

        assertEquals(1, host.requests.size)
        assertEquals(listOf(PermissionAnswer.GRANTED, PermissionAnswer.GRANTED), answers)
    }

    @Test
    fun leavesTheResultsOfOtherRequestsToOtherListeners() {
        request()

        val isHandled = requester.onRequestPermissionsResult(
            host.requests.single().requestCode + 1,
            LOCATION_PERMISSIONS.toTypedArray(),
            intArrayOf(GRANTED, GRANTED),
        )

        assertFalse(isHandled)
        assertTrue(answers.isEmpty())
    }

    @Test
    fun cancelsTheWaitingRequests() {
        request()

        requester.cancel()
        answerDialog(GRANTED, GRANTED)

        assertEquals(listOf(PermissionAnswer.CANCELLED), answers)
    }

    @Test
    fun showsANewDialogAfterAnAnswerDeliveredDuringTheRequest() {
        host.onRequest = { requestCode ->
            requester.onRequestPermissionsResult(requestCode, emptyArray(), intArrayOf())
        }

        request()
        request()

        assertEquals(2, host.requests.size)
        assertEquals(listOf(PermissionAnswer.CANCELLED, PermissionAnswer.CANCELLED), answers)
    }

    private class PermissionRequest(val permissions: List<String>, val requestCode: Int)

    private class FakeHost : PermissionHost {
        override var restrictsPreciseLocationToSystemButton = false
        val grantedPermissions = mutableSetOf<String>()
        val requests = mutableListOf<PermissionRequest>()
        var onRequest: ((Int) -> Unit)? = null

        override fun isGranted(permission: String): Boolean = permission in grantedPermissions

        override fun requestPermissions(permissions: Array<String>, requestCode: Int) {
            requests += PermissionRequest(permissions.toList(), requestCode)
            onRequest?.invoke(requestCode)
        }
    }

    private companion object {
        const val GRANTED = PackageManager.PERMISSION_GRANTED
        const val DENIED = PackageManager.PERMISSION_DENIED
    }
}
