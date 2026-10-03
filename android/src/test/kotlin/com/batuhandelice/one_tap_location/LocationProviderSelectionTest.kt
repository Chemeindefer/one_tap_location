// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package com.batuhandelice.one_tap_location

import android.location.LocationManager
import org.junit.Assert.assertEquals
import org.junit.Test

class LocationProviderSelectionTest {
    private val allProviders = listOf(
        LocationManager.PASSIVE_PROVIDER,
        LocationManager.NETWORK_PROVIDER,
        LocationManager.GPS_PROVIDER,
    )

    @Test
    fun usesTheFusedProviderWhenTheDeviceHasOne() {
        assertEquals(
            listOf(LocationManager.FUSED_PROVIDER),
            selectLocationProviders(
                hasFusedProvider = true,
                isPreciseAccessGranted = false,
                enabledProviders = allProviders,
            ),
        )
    }

    @Test
    fun asksTheGpsAndNetworkProvidersWithPreciseAccess() {
        assertEquals(
            listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER),
            selectLocationProviders(
                hasFusedProvider = false,
                isPreciseAccessGranted = true,
                enabledProviders = allProviders,
            ),
        )
    }

    @Test
    fun asksTheNetworkProviderWithApproximateAccess() {
        assertEquals(
            listOf(LocationManager.NETWORK_PROVIDER),
            selectLocationProviders(
                hasFusedProvider = false,
                isPreciseAccessGranted = false,
                enabledProviders = allProviders,
            ),
        )
    }

    @Test
    fun skipsProvidersThatAreTurnedOff() {
        assertEquals(
            listOf(LocationManager.GPS_PROVIDER),
            selectLocationProviders(
                hasFusedProvider = false,
                isPreciseAccessGranted = true,
                enabledProviders = listOf(LocationManager.GPS_PROVIDER),
            ),
        )
        assertEquals(
            emptyList<String>(),
            selectLocationProviders(
                hasFusedProvider = false,
                isPreciseAccessGranted = false,
                enabledProviders = listOf(LocationManager.PASSIVE_PROVIDER),
            ),
        )
    }
}
