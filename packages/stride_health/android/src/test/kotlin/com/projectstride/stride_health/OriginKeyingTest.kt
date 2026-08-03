package com.projectstride.stride_health

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotEquals
import kotlin.test.assertTrue

/**
 * The origin-keying suite, asserted against the CANONICAL fixture.
 *
 * Two native implementations are two chances to diverge, and a divergence is
 * silent: a re-keyed origin looks exactly like a new device, its recent buckets
 * look ungranted, and the retention window is granted a second time. No later
 * check can see that, so the vectors are the whole defence.
 *
 * Every expected value here comes from
 * `packages/stride_health/test_fixtures/origin_key_vectors.json` at run time.
 * None is written in this file, and none may be.
 */
internal class OriginKeyingTest {

    private fun keyHex(salt: ByteArray, identifier: String): String =
        OriginKeying.toCoreHex(OriginKeying(salt).keyBytes(identifier))

    @Test
    fun `the fixture is actually loaded`() {
        // A keying suite that silently asserted nothing would report green
        // while every origin re-keyed. The loader throws when the resource is
        // missing; this makes the absence a named failure rather than a
        // vacuous pass in eight other tests.
        assertTrue(OriginKeyVectors.vectors.isNotEmpty(), "the fixture has vectors")
        assertTrue(
            OriginKeyVectors.negativePrivacyVectors.isNotEmpty(),
            "the fixture has negative privacy vectors"
        )
    }

    @Test
    fun `every canonical vector produces exactly the expected bytes`() {
        for (vector in OriginKeyVectors.vectors) {
            assertEquals(
                vector.expectedKeyHex,
                keyHex(vector.salt, vector.identifier),
                "a canonical vector disagrees. A divergence here re-keys every " +
                    "origin and re-grants the retention window, with nothing to " +
                    "detect it afterwards."
            )
        }
    }

    @Test
    fun `the implemented algorithm version is the fixture's`() {
        // `installOriginKeying` refuses a mismatch rather than falling back.
        // That refusal is only worth anything if the version this adapter
        // claims is the version the vectors were generated under.
        assertEquals(OriginKeyVectors.algorithmVersion, OriginKeying.ALGORITHM_VERSION)
        assertEquals(
            OriginKeyVectors.algorithmVersion,
            HealthConnectAdapter.ORIGIN_KEYING_ALGORITHM_VERSION
        )
    }

    @Test
    fun `a key is exactly eight bytes, and an empty identifier is zero bytes`() {
        // The only two legal lengths on the wire. Eight zero bytes would be a
        // legal, ordinary key the hash could produce, so "no source reported"
        // cannot share a representation with it.
        for (vector in OriginKeyVectors.vectors) {
            val key = OriginKeying(vector.salt).keyBytes(vector.identifier)
            if (vector.identifier.isEmpty()) {
                assertEquals(0, key.size, "the empty identifier is ZERO bytes")
            } else {
                assertEquals(OriginKeyVectors.keyLengthBytes, key.size)
            }
        }
    }

    @Test
    fun `the rendering is sixteen lowercase hexadecimal characters`() {
        // The form `StepOriginKey` accepts. Asserting the bytes alone would
        // leave the conversion untested, and the conversion is where a signed
        // Long once produced seventeen characters with a leading minus.
        assertEquals("16 lowercase hexadecimal characters", OriginKeyVectors.coreKeyFormat)
        for (vector in OriginKeyVectors.vectors) {
            if (vector.identifier.isEmpty()) continue
            val hex = keyHex(vector.salt, vector.identifier)
            assertEquals(16, hex.length, "sixteen characters, never seventeen")
            assertTrue(
                hex.all { it in '0'..'9' || it in 'a'..'f' },
                "lowercase hexadecimal only -- no sign, no uppercase"
            )
        }
    }

    @Test
    fun `high bytes do not sign-extend on the way into the hash`() {
        // Kotlin's `Byte` is signed, so `byte.toLong()` widens 0x80 to
        // 0xFFFFFFFFFFFFFF80 and the FNV xor corrupts for every byte above
        // 0x7F. That is the signedness defect that actually survives here, and
        // it is silent: the result is stable, self-consistent, and completely
        // different from every other platform's -- which looks exactly like a
        // new device.
        //
        // (The other half of the warning, `shr` versus `ushr` when rendering
        // the digest, is neutralized by the `and 0xFF` mask on each byte and
        // cannot be falsified from outside. It is written in ULong anyway, so
        // there is no signed value to shift and no place for it to come back.)
        //
        // The fixture carries a high-byte salt for exactly this case.
        val highByteVectors = OriginKeyVectors.vectors.filter { vector ->
            vector.salt.any { (it.toInt() and 0x80) != 0 }
        }
        assertTrue(highByteVectors.isNotEmpty(), "the fixture carries a high-byte salt")
        for (vector in highByteVectors) {
            assertEquals(vector.expectedKeyHex, keyHex(vector.salt, vector.identifier))
        }
    }

    @Test
    fun `repeat calls are stable`() {
        // A device that keyed differently on every sync would look new on every
        // sync, and its whole history would be re-granted each time.
        for (vector in OriginKeyVectors.vectors) {
            val keying = OriginKeying(vector.salt)
            val first = OriginKeying.toCoreHex(keying.keyBytes(vector.identifier))
            repeat(4) {
                assertEquals(
                    first,
                    OriginKeying.toCoreHex(keying.keyBytes(vector.identifier))
                )
            }
            // And stable across instances, not merely within one.
            assertEquals(first, keyHex(vector.salt, vector.identifier))
        }
    }

    @Test
    fun `distinct fixture inputs stay distinct`() {
        // Not a hash-quality claim. It is the property the separator and the
        // salt exist to provide: two sources on one device must not collide,
        // and the same source under two salts must not agree -- otherwise the
        // salt is not mixed in and this is a bare digest of a package name.
        val seen = HashMap<String, String>()
        for (vector in OriginKeyVectors.vectors) {
            if (vector.identifier.isEmpty()) continue
            val hex = keyHex(vector.salt, vector.identifier)
            val label = OriginKeying.toCoreHex(vector.salt) + "|" + vector.identifier
            val clash = seen.put(hex, label)
            assertEquals(null, clash, "two distinct fixture inputs produced one key")
        }
    }

    @Test
    fun `a raw identifier never survives as itself, whatever its length`() {
        // Eight bytes of output is NOT evidence of hashing. `My Watch` is
        // exactly eight bytes of UTF-8, so an adapter that shipped the raw
        // identifier would produce a field of the correct width and every
        // length check in the project would pass it.
        //
        // These four assertions are the ones a width check cannot make.
        for (vector in OriginKeyVectors.negativePrivacyVectors) {
            val hex = keyHex(vector.salt, vector.identifier)

            assertEquals(
                vector.expectedKeyHex,
                hex,
                "the negative vector must still key correctly"
            )
            assertNotEquals(
                vector.rawUtf8Hex,
                hex,
                "the raw UTF-8 of the identifier crossed as the key"
            )
            assertNotEquals(
                vector.rawUtf8PrefixHex,
                hex,
                "the first eight bytes of the identifier crossed as the key"
            )
            assertNotEquals(
                vector.rawUtf8ZeroPaddedHex,
                hex,
                "the identifier, zero-padded to eight bytes, crossed as the key"
            )
        }
    }

    @Test
    fun `forgetting the salt stops it producing the same key`() {
        // "In memory only, for the lifetime of the engine attachment" is only
        // true if dropping it actually drops it. A zeroed salt is a different
        // salt, so the key changes -- which is the observable form of the
        // erasure.
        val vector = OriginKeyVectors.vectors.first { it.identifier.isNotEmpty() }
        val keying = OriginKeying(vector.salt)
        assertEquals(vector.expectedKeyHex, OriginKeying.toCoreHex(keying.keyBytes(vector.identifier)))

        keying.forget()

        assertNotEquals(
            vector.expectedKeyHex,
            OriginKeying.toCoreHex(keying.keyBytes(vector.identifier))
        )
    }

    @Test
    fun `the caller cannot mutate the salt underneath a read`() {
        // The salt is copied on construction. A caller that reused its buffer
        // would otherwise re-key every origin mid-session, which looks exactly
        // like a new device.
        val vector = OriginKeyVectors.vectors.first { it.identifier.isNotEmpty() }
        val mutable = vector.salt.copyOf()
        val keying = OriginKeying(mutable)
        mutable.fill(0x7F)

        assertEquals(
            vector.expectedKeyHex,
            OriginKeying.toCoreHex(keying.keyBytes(vector.identifier))
        )
    }
}
