// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package com.batuhandelice.one_tap_location

import android.content.Context
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

internal class LocationButtonFactory(
    private val messenger: BinaryMessenger,
    private val hostActivity: HostActivity,
    private val confirmationTracker: ConfirmationTracker,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        if (Build.VERSION.SDK_INT < SYSTEM_BUTTON_API_LEVEL) {
            throw IllegalStateException("The system location button requires Android 17 or later.")
        }
        return LocationButtonPlatformView(
            context,
            viewId,
            messenger,
            hostActivity,
            confirmationTracker,
            LocationButtonStyle.decode(args),
        )
    }
}
