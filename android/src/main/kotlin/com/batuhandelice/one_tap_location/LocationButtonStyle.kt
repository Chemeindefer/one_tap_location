// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package com.batuhandelice.one_tap_location

import kotlin.math.roundToInt

/** The style of a location button, as sent by the Dart side in logical pixels. */
internal data class LocationButtonStyle(
    val textType: Int = TEXT_TYPE_PRECISE_LOCATION,
    val backgroundColor: Int? = null,
    val foregroundColor: Int? = null,
    val cornerRadius: Double? = null,
    val strokeColor: Int? = null,
    val strokeWidth: Double? = null,
    val pressedCornerRadius: Double? = null,
) {
    /**
     * Whether this style returns a property of [previous] to its system default, which an open
     * session cannot do.
     */
    fun resetsAnyPropertyOf(previous: LocationButtonStyle): Boolean =
        (previous.backgroundColor != null && backgroundColor == null) ||
            (previous.foregroundColor != null && foregroundColor == null) ||
            (previous.cornerRadius != null && cornerRadius == null) ||
            (previous.strokeColor != null && strokeColor == null) ||
            (previous.strokeWidth != null && strokeWidth == null) ||
            (previous.pressedCornerRadius != null && pressedCornerRadius == null)

    fun toAppearance(density: Float) = SystemButtonAppearance(
        textType = textType,
        backgroundColor = backgroundColor,
        foregroundColor = foregroundColor,
        strokeColor = strokeColor,
        strokeWidth = strokeWidth?.let { (it * density).roundToInt() },
        cornerRadius = cornerRadius?.let { (it * density).toFloat() },
        pressedCornerRadius = pressedCornerRadius?.let { (it * density).toFloat() },
    )

    companion object {
        // The values of the LocationButtonSession.TEXT_TYPE_* constants.
        private const val TEXT_TYPE_NONE = 0
        private const val TEXT_TYPE_PRECISE_LOCATION = 1
        private const val TEXT_TYPE_USE_PRECISE_LOCATION = 2
        private const val TEXT_TYPE_SHARE_PRECISE_LOCATION = 3
        private const val TEXT_TYPE_NEAR_MY_PRECISE_LOCATION = 4
        private const val TEXT_TYPE_NEAR_YOUR_PRECISE_LOCATION = 5

        private val textTypes = mapOf(
            "none" to TEXT_TYPE_NONE,
            "preciseLocation" to TEXT_TYPE_PRECISE_LOCATION,
            "usePreciseLocation" to TEXT_TYPE_USE_PRECISE_LOCATION,
            "sharePreciseLocation" to TEXT_TYPE_SHARE_PRECISE_LOCATION,
            "nearMyPreciseLocation" to TEXT_TYPE_NEAR_MY_PRECISE_LOCATION,
            "nearYourPreciseLocation" to TEXT_TYPE_NEAR_YOUR_PRECISE_LOCATION,
        )

        fun decode(arguments: Any?): LocationButtonStyle {
            val values = arguments as? Map<*, *> ?: return LocationButtonStyle()
            return LocationButtonStyle(
                textType = textTypes[values["androidLabel"]] ?: TEXT_TYPE_PRECISE_LOCATION,
                backgroundColor = values.color("backgroundColor"),
                foregroundColor = values.color("foregroundColor"),
                cornerRadius = values.dimension("cornerRadius"),
                strokeColor = values.color("androidStrokeColor"),
                strokeWidth = values.dimension("androidStrokeWidth"),
                pressedCornerRadius = values.dimension("androidPressedCornerRadius"),
            )
        }

        // Opaque ARGB colors exceed Int.MAX_VALUE, so the codec delivers them as Long.
        private fun Map<*, *>.color(key: String): Int? = (this[key] as? Number)?.toInt()

        private fun Map<*, *>.dimension(key: String): Double? = (this[key] as? Number)?.toDouble()
    }
}
