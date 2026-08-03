package com.projectstride.stride_health

/**
 * Origin pseudonymization, and the one function in this plugin that has to be
 * byte-for-byte identical to another language's.
 *
 * FNV-1a, 64-bit, over `salt || 0x1F || utf8(identifier)`, rendered big-endian
 * into exactly eight bytes. The reference implementation is
 * `packages/stride_health/lib/src/origin_pseudonymizer.dart`; the canonical
 * vectors are `packages/stride_health/test_fixtures/origin_key_vectors.json`,
 * and `OriginKeyingTest` reads that file rather than restating its values.
 *
 * ## Why this is keyed rather than a bare digest
 *
 * An unkeyed hash of a package name is trivially reversible by anyone holding a
 * list of package names, which is everyone. The salt is the device-bound
 * identity the app already owns; this class is a consumer of it and never mints
 * one. The `0x1F` separator is what stops `salt || identifier` from colliding
 * with `salt' || identifier'` when the salt length varies.
 *
 * ## The signed-shift trap
 *
 * Kotlin's `Long` is signed and `shr` is arithmetic: it sign-extends, so for
 * half of all hash values a `shr`-based render produces a stable,
 * self-consistent, and completely wrong key -- which looks exactly like a new
 * device, and re-grants the whole retention window with nothing to detect it.
 *
 * The arithmetic here is done in `ULong` throughout, so there is no signed
 * value to shift and no place for the defect to live. `ULong.shr` is logical by
 * construction.
 *
 * ## Empty is zero bytes, not eight zero bytes
 *
 * An empty identifier means "the platform reported no source", which the wire
 * carries as a zero-length key and the core reads as `StepOriginKey.unknown`.
 * Eight zero bytes would be a legal, ordinary key that the hash could in
 * principle produce, so the two must not share a representation.
 */
internal class OriginKeying(salt: ByteArray) {

    /**
     * A private copy.
     *
     * In memory only, for the lifetime of the engine attachment. Copied so the
     * caller cannot mutate the salt underneath a read in flight, and zeroed by
     * [forget] on detach.
     */
    private val salt: ByteArray = salt.copyOf()

    /**
     * The pseudonymous key for one raw platform source identifier.
     *
     * [rawIdentifier] is `metadata.dataOrigin.packageName` and nothing else.
     * Never a device label: a player may have called their phone anything at
     * all, and a display name hashed into an origin key is worse than useless
     * because it looks correct.
     *
     * The raw value lives inside this call and is gone when it returns. It is
     * not stored in a field, not logged, and there is no field on the Pigeon
     * contract that could carry it.
     */
    fun keyBytes(rawIdentifier: String): ByteArray {
        if (rawIdentifier.isEmpty()) return ByteArray(0)

        val identifier: ByteArray = rawIdentifier.toByteArray(Charsets.UTF_8)

        var hash: ULong = FNV_OFFSET_BASIS
        for (byte in salt) {
            hash = hash xor byte.toUByte().toULong()
            hash *= FNV_PRIME
        }
        hash = hash xor SEPARATOR
        hash *= FNV_PRIME
        for (byte in identifier) {
            hash = hash xor byte.toUByte().toULong()
            hash *= FNV_PRIME
        }

        val bytes = ByteArray(KEY_LENGTH_BYTES)
        for (i in 0 until KEY_LENGTH_BYTES) {
            // ULong.shr is logical. There is deliberately no Long in this
            // expression for an arithmetic shift to sign-extend.
            bytes[i] = ((hash shr (56 - i * 8)) and 0xFFuL).toByte()
        }
        return bytes
    }

    /** Zeroes and drops the salt. Called when the engine detaches. */
    fun forget() {
        salt.fill(0)
    }

    companion object {
        /**
         * The keying scheme this adapter implements.
         *
         * Must match `originKeyingAlgorithmVersion` in
         * `lib/src/origin_pseudonymizer.dart` and `algorithmVersion` in the
         * canonical fixture. A mismatch is a typed refusal, never a fallback.
         */
        const val ALGORITHM_VERSION = 1L

        /** The only non-empty length a key may have. */
        const val KEY_LENGTH_BYTES = 8

        private const val FNV_OFFSET_BASIS: ULong = 0xcbf29ce484222325uL
        private const val FNV_PRIME: ULong = 0x100000001b3uL

        /** ASCII unit separator, between the salt and the identifier. */
        private const val SEPARATOR: ULong = 0x1FuL

        /**
         * The sixteen lowercase hexadecimal characters `StepOriginKey` accepts.
         *
         * The bridge derives this from the bytes on the Dart side; it exists
         * here so the Kotlin suite can assert that these eight bytes render to
         * the form the core will actually store, rather than asserting bytes
         * and hoping.
         */
        fun toCoreHex(key: ByteArray): String {
            val out = StringBuilder(key.size * 2)
            for (byte in key) {
                val value = byte.toInt() and 0xFF
                out.append(HEX_DIGITS[value ushr 4])
                out.append(HEX_DIGITS[value and 0x0F])
            }
            return out.toString()
        }

        private const val HEX_DIGITS = "0123456789abcdef"
    }
}
