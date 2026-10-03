// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package com.batuhandelice.one_tap_location

import android.Manifest
import android.content.Context
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.os.Build

/**
 * `PackageInfo.REQUESTED_PERMISSION_ONLY_FOR_LOCATION_BUTTON`: the permission is declared with
 * `android:usesPermissionFlags="onlyForLocationButton"`. Added in API level 37, so SDK 36, which
 * the plugin compiles against, lacks the constant.
 */
private const val REQUESTED_PERMISSION_ONLY_FOR_LOCATION_BUTTON = 0x00020000

/** The permissions that the app declares, including those merged from its libraries. */
internal fun Context.declaredPermissions(): Set<String> =
    packageInfoWithPermissions().requestedPermissions?.toSet().orEmpty()

/**
 * Whether the app can obtain precise location only through the system location button.
 *
 * Android reports the flag from API level 37 on.
 */
internal fun Context.restrictsPreciseLocationToSystemButton(): Boolean {
    if (Build.VERSION.SDK_INT < SYSTEM_BUTTON_API_LEVEL) {
        return false
    }
    val info = packageInfoWithPermissions()
    return isDeclaredOnlyForLocationButton(
        Manifest.permission.ACCESS_FINE_LOCATION,
        info.requestedPermissions,
        info.requestedPermissionsFlags,
    )
}

/** Whether [permission] is declared with the onlyForLocationButton flag. */
internal fun isDeclaredOnlyForLocationButton(
    permission: String,
    requestedPermissions: Array<String>?,
    requestedPermissionsFlags: IntArray?,
): Boolean {
    val index = requestedPermissions?.indexOf(permission) ?: return false
    val flags = requestedPermissionsFlags?.getOrNull(index) ?: return false
    return (flags and REQUESTED_PERMISSION_ONLY_FOR_LOCATION_BUTTON) != 0
}

private fun Context.packageInfoWithPermissions(): PackageInfo =
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        packageManager.getPackageInfo(
            packageName,
            PackageManager.PackageInfoFlags.of(PackageManager.GET_PERMISSIONS.toLong()),
        )
    } else {
        @Suppress("DEPRECATION")
        packageManager.getPackageInfo(packageName, PackageManager.GET_PERMISSIONS)
    }
