package com.projectstride.stride_health

import java.io.InputStream
import org.json.JSONArray
import org.json.JSONObject

/**
 * The CANONICAL origin-key vectors, read from the shared fixture.
 *
 * `packages/stride_health/test_fixtures/origin_key_vectors.json` is wired into
 * this module's test resources by `android/build.gradle.kts`. Dart, Swift and
 * Kotlin all read that one file.
 *
 * **Nothing in the Kotlin suite may restate a vector's value.** Three
 * transcriptions is three chances to drift, and a drift here is silent: keys
 * that disagree with the other platforms look exactly like a new device, so the
 * origin's recent buckets look ungranted and the whole retention window is
 * granted a second time. Nothing detects that afterwards, which is why it has
 * to be prevented before.
 *
 * The loader fails loudly when the fixture is missing rather than skipping:
 * a keying suite that quietly asserted nothing would be worse than no suite,
 * because it would report green.
 */
internal object OriginKeyVectors {

    private const val RESOURCE = "/origin_key_vectors.json"

    private val document: JSONObject by lazy {
        val stream: InputStream = OriginKeyVectors::class.java.getResourceAsStream(RESOURCE)
            ?: throw IllegalStateException(
                "the canonical origin-key fixture is not on the test classpath at " +
                    "$RESOURCE. It is wired in from packages/stride_health/test_fixtures " +
                    "by android/build.gradle.kts. Do NOT work around this by " +
                    "transcribing the vectors into Kotlin."
            )
        JSONObject(stream.bufferedReader().use { it.readText() })
    }

    /** The keying scheme the fixture was generated under. */
    val algorithmVersion: Long get() = document.getLong("algorithmVersion")

    /** The only non-empty key length the fixture permits. */
    val keyLengthBytes: Int get() = document.getInt("keyLengthBytes")

    /** The rendering `StepOriginKey` accepts, as the fixture describes it. */
    val coreKeyFormat: String get() = document.getString("coreKeyFormat")

    val vectors: List<Vector> by lazy { document.getJSONArray("vectors").map(::vector) }

    /**
     * Vectors whose identifiers are short enough, or exactly the right length,
     * to survive a naive implementation recognisably.
     *
     * `My Watch` is exactly eight bytes of UTF-8. An adapter that put the raw
     * identifier on the wire would produce a field of the correct WIDTH, and
     * every width check in the project would pass.
     */
    val negativePrivacyVectors: List<NegativeVector> by lazy {
        document.getJSONArray("negativePrivacyVectors").map(::negativeVector)
    }

    internal data class Vector(
        val salt: ByteArray,
        val identifier: String,
        val expectedKeyHex: String,
    )

    internal data class NegativeVector(
        val salt: ByteArray,
        val identifier: String,
        val expectedKeyHex: String,
        /** The identifier's own UTF-8 bytes, rendered. */
        val rawUtf8Hex: String,
        /** Its first eight bytes. */
        val rawUtf8PrefixHex: String,
        /** Its bytes, right-padded to eight. */
        val rawUtf8ZeroPaddedHex: String,
    )

    private fun vector(entry: JSONObject) = Vector(
        salt = decodeHex(entry.getString("saltHex")),
        identifier = entry.getString("identifier"),
        expectedKeyHex = entry.getString("expectedKeyHex"),
    )

    private fun negativeVector(entry: JSONObject) = NegativeVector(
        salt = decodeHex(entry.getString("saltHex")),
        identifier = entry.getString("identifier"),
        expectedKeyHex = entry.getString("expectedKeyHex"),
        rawUtf8Hex = entry.getString("rawUtf8Hex"),
        rawUtf8PrefixHex = entry.getString("rawUtf8PrefixHex"),
        rawUtf8ZeroPaddedHex = entry.getString("rawUtf8ZeroPaddedHex"),
    )

    private fun <T> JSONArray.map(transform: (JSONObject) -> T): List<T> =
        (0 until length()).map { transform(getJSONObject(it)) }

    /** Hex to bytes. The fixture's own encoding, decoded rather than assumed. */
    fun decodeHex(hex: String): ByteArray {
        require(hex.length % 2 == 0) { "a hex string has an even length" }
        val out = ByteArray(hex.length / 2)
        for (i in out.indices) {
            out[i] = hex.substring(i * 2, i * 2 + 2).toInt(16).toByte()
        }
        return out
    }
}
