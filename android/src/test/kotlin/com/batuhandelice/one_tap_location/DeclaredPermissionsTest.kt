// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package com.batuhandelice.one_tap_location

import android.Manifest
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class DeclaredPermissionsTest {
    private val permissions = arrayOf(
        Manifest.permission.ACCESS_COARSE_LOCATION,
        Manifest.permission.ACCESS_FINE_LOCATION,
    )

    private fun isRestricted(permissions: Array<String>?, flags: IntArray?): Boolean =
        isDeclaredOnlyForLocationButton(
            Manifest.permission.ACCESS_FINE_LOCATION,
            permissions,
            flags,
        )

    @Test
    fun findsTheFlagOnPreciseLocation() {
        assertTrue(isRestricted(permissions, intArrayOf(0, ONLY_FOR_LOCATION_BUTTON)))
    }

    @Test
    fun findsTheFlagAmongOtherFlags() {
        val flags = ONLY_FOR_LOCATION_BUTTON or REQUIRED or GRANTED

        assertTrue(isRestricted(permissions, intArrayOf(0, flags)))
    }

    @Test
    fun ignoresTheFlagOnAnotherPermission() {
        assertFalse(isRestricted(permissions, intArrayOf(ONLY_FOR_LOCATION_BUTTON, REQUIRED)))
    }

    @Test
    fun ignoresOtherFlagsOnPreciseLocation() {
        assertFalse(isRestricted(permissions, intArrayOf(0, NEVER_FOR_LOCATION or REQUIRED)))
    }

    @Test
    fun reportsNoFlagWhenPreciseLocationIsNotDeclared() {
        val permissions = arrayOf(Manifest.permission.ACCESS_COARSE_LOCATION)

        assertFalse(isRestricted(permissions, intArrayOf(ONLY_FOR_LOCATION_BUTTON)))
    }

    @Test
    fun reportsNoFlagWithoutPermissionsOrFlags() {
        assertFalse(isRestricted(null, null))
        assertFalse(isRestricted(permissions, null))
        assertFalse(isRestricted(permissions, intArrayOf(0)))
    }

    private companion object {
        const val REQUIRED = 0x00000001
        const val GRANTED = 0x00000002
        const val NEVER_FOR_LOCATION = 0x00010000
        const val ONLY_FOR_LOCATION_BUTTON = 0x00020000
    }
}
