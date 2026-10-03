// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package com.batuhandelice.one_tap_location

import android.app.Activity
import android.app.ActivityManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ActivityInfo
import android.content.pm.PackageManager
import android.os.Build
import androidx.annotation.RequiresApi

/**
 * The action that opens the system confirmation of the location button. PermissionController
 * declares it, but the SDK does not publish it.
 */
private const val ACTION_REQUEST_LOCATION_BUTTON_PERMISSIONS =
    "android.app.permissionui.action.REQUEST_LOCATION_BUTTON_PERMISSIONS"

/**
 * Identifies the screen that paused an activity by the top activity of the activity's task.
 *
 * The framework starts the system confirmation from the activity that hosts the tapped button, so
 * the confirmation opens in the task of that activity, and it is the top activity of the task by
 * the time the host is paused. A single-instance activity starts every activity in another task,
 * which the app cannot inspect. A screen that cannot be identified may be the confirmation.
 */
internal object TaskTopActivity : PausingScreen {
    private var confirmationActivities: Set<ComponentName>? = null

    override fun canBeConfirmation(host: Any): Boolean {
        if (host !is Activity ||
            Build.VERSION.SDK_INT < SYSTEM_BUTTON_API_LEVEL ||
            host.isSingleInstance()
        ) {
            return true
        }
        val confirmations = confirmationActivities(host)
        if (confirmations.isEmpty()) {
            return true
        }
        val topActivity = topActivity(host) ?: return true
        return topActivity in confirmations
    }

    @RequiresApi(SYSTEM_BUTTON_API_LEVEL)
    private fun confirmationActivities(context: Context): Set<ComponentName> =
        confirmationActivities ?: context.packageManager
            .queryIntentActivities(
                Intent(ACTION_REQUEST_LOCATION_BUTTON_PERMISSIONS),
                PackageManager.ResolveInfoFlags.of(PackageManager.MATCH_SYSTEM_ONLY.toLong()),
            )
            .mapTo(HashSet()) { ComponentName(it.activityInfo.packageName, it.activityInfo.name) }
            .also { confirmationActivities = it }

    @RequiresApi(SYSTEM_BUTTON_API_LEVEL)
    private fun Activity.isSingleInstance(): Boolean =
        try {
            packageManager
                .getActivityInfo(componentName, PackageManager.ComponentInfoFlags.of(0))
                .launchMode == ActivityInfo.LAUNCH_SINGLE_INSTANCE
        } catch (exception: PackageManager.NameNotFoundException) {
            true
        }

    @RequiresApi(SYSTEM_BUTTON_API_LEVEL)
    private fun topActivity(activity: Activity): ComponentName? =
        try {
            activity.getSystemService(ActivityManager::class.java)
                .appTasks
                .firstNotNullOfOrNull { task ->
                    task.taskInfo?.takeIf { it.taskId == activity.taskId }
                }
                ?.topActivity
        } catch (exception: RuntimeException) {
            // The task can be gone by the time the system answers.
            null
        }
}
