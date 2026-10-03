// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package com.batuhandelice.one_tap_location

import android.app.Activity
import android.app.Application
import android.os.Bundle

/** Tracks the activity that hosts the Flutter view and forwards its lifecycle. */
internal class HostActivity : Application.ActivityLifecycleCallbacks {
    interface Listener {
        fun onHostAttached(activity: Activity) = Unit

        fun onHostPaused(activity: Activity) = Unit

        fun onHostStopped(activity: Activity) = Unit

        fun onHostResumed(activity: Activity) = Unit
    }

    var activity: Activity? = null
        private set

    private val listeners = LinkedHashSet<Listener>()

    fun attach(activity: Activity) {
        detach()
        this.activity = activity
        activity.application.registerActivityLifecycleCallbacks(this)
        dispatch { it.onHostAttached(activity) }
    }

    fun detach() {
        val current = activity ?: return
        current.application.unregisterActivityLifecycleCallbacks(this)
        activity = null
    }

    fun addListener(listener: Listener) {
        listeners.add(listener)
    }

    fun removeListener(listener: Listener) {
        listeners.remove(listener)
    }

    override fun onActivityPaused(activity: Activity) {
        if (activity === this.activity) dispatch { it.onHostPaused(activity) }
    }

    override fun onActivityStopped(activity: Activity) {
        if (activity === this.activity) dispatch { it.onHostStopped(activity) }
    }

    override fun onActivityResumed(activity: Activity) {
        if (activity === this.activity) dispatch { it.onHostResumed(activity) }
    }

    override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) = Unit

    override fun onActivityStarted(activity: Activity) = Unit

    override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) = Unit

    override fun onActivityDestroyed(activity: Activity) = Unit

    // Listeners may unregister while being notified.
    private fun dispatch(action: (Listener) -> Unit) {
        listeners.toList().forEach(action)
    }
}
