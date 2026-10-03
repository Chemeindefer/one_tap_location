// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package com.batuhandelice.one_tap_location

internal fun interface Scheduler {
    fun schedule(delayMillis: Long, action: () -> Unit): Cancellable
}

internal fun interface Cancellable {
    fun cancel()
}
