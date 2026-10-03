// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package com.batuhandelice.one_tap_location

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class LocationButtonStyleTest {
    @Test
    fun usesThePreciseLocationTextByDefault() {
        assertEquals(LocationButtonStyle(textType = 1), LocationButtonStyle.decode(null))
        assertEquals(
            LocationButtonStyle(textType = 1),
            LocationButtonStyle.decode(emptyMap<String, Any>()),
        )
    }

    @Test
    fun decodesEveryProperty() {
        val style = LocationButtonStyle.decode(
            mapOf(
                "androidLabel" to "sharePreciseLocation",
                "backgroundColor" to 0xFF3366FFL,
                "foregroundColor" to 0xFFFFFFFFL,
                "cornerRadius" to 12.0,
                "androidStrokeColor" to 0xFF102040L,
                "androidStrokeWidth" to 2.0,
                "androidPressedCornerRadius" to 16.0,
            ),
        )

        assertEquals(
            LocationButtonStyle(
                textType = 3,
                backgroundColor = 0xFF3366FF.toInt(),
                foregroundColor = 0xFFFFFFFF.toInt(),
                cornerRadius = 12.0,
                strokeColor = 0xFF102040.toInt(),
                strokeWidth = 2.0,
                pressedCornerRadius = 16.0,
            ),
            style,
        )
    }

    @Test
    fun mapsEveryLabelToItsTextType() {
        val labels = listOf(
            "none",
            "preciseLocation",
            "usePreciseLocation",
            "sharePreciseLocation",
            "nearMyPreciseLocation",
            "nearYourPreciseLocation",
        )

        labels.forEachIndexed { textType, label ->
            val style = LocationButtonStyle.decode(mapOf("androidLabel" to label))
            assertEquals(textType, style.textType)
        }
    }

    @Test
    fun convertsLogicalDimensionsToPixels() {
        val style = LocationButtonStyle(
            textType = 0,
            backgroundColor = 0xFF000000.toInt(),
            cornerRadius = 12.0,
            strokeWidth = 1.5,
            pressedCornerRadius = 16.0,
        )

        assertEquals(
            SystemButtonAppearance(
                textType = 0,
                backgroundColor = 0xFF000000.toInt(),
                strokeWidth = 4,
                cornerRadius = 31.5f,
                pressedCornerRadius = 42.0f,
            ),
            style.toAppearance(density = 2.625f),
        )
    }

    @Test
    fun detectsAPropertyThatReturnsToItsDefault() {
        val style = LocationButtonStyle(backgroundColor = 0xFF102040.toInt(), cornerRadius = 12.0)

        assertTrue(LocationButtonStyle(cornerRadius = 12.0).resetsAnyPropertyOf(style))
        assertFalse(style.copy(cornerRadius = 16.0).resetsAnyPropertyOf(style))
        assertFalse(style.resetsAnyPropertyOf(LocationButtonStyle()))
    }
}
