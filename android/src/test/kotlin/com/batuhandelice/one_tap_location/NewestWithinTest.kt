// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package com.batuhandelice.one_tap_location

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class NewestWithinTest {
    private data class Candidate(val name: String, val ageMillis: Long)

    private fun newest(vararg candidates: Candidate): Candidate? =
        newestWithin(candidates.toList(), MAX_AGE_MILLIS, Candidate::ageMillis)

    @Test
    fun picksTheNewestCandidate() {
        assertEquals(
            Candidate("network", 2_000),
            newest(Candidate("fused", 90_000), Candidate("network", 2_000)),
        )
    }

    @Test
    fun acceptsACandidateAtTheMaximumAge() {
        assertEquals(Candidate("fused", MAX_AGE_MILLIS), newest(Candidate("fused", MAX_AGE_MILLIS)))
    }

    @Test
    fun skipsCandidatesThatAreTooOld() {
        assertNull(newest(Candidate("fused", MAX_AGE_MILLIS + 1)))
    }

    @Test
    fun skipsCandidatesFromTheFuture() {
        assertNull(newest(Candidate("fused", -1)))
    }

    @Test
    fun findsNothingWithoutCandidates() {
        assertNull(newest())
    }

    private companion object {
        const val MAX_AGE_MILLIS = 600_000L
    }
}
