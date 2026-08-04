package com.projectstride.stride_health

import androidx.health.connect.client.HealthConnectClient
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * The supported API bands.
 *
 * The project's minimum is 26. It was 24 with a `tools:overrideLibrary` on the
 * Health Connect client, which asserted in a manifest that the SDK supports
 * Android 7. It does not, and an override does not add support — it moves the
 * failure from a build on a developer's machine to a phone belonging to
 * someone who cannot report it usefully.
 */
class HealthConnectAvailabilityTest {

    /** Records whether Health Connect was reached at all. */
    private class Probe(private val status: Int) {
        var calls: Int = 0
        fun status(): Int {
            calls += 1
            return status
        }
    }

    // -- 24-25: unsupported -------------------------------------------------

    @Test
    fun `the supported floor is API 26`() {
        // Asserted rather than assumed: the Gradle files are what actually
        // enforce this, and a constant that silently disagreed with them would
        // make every band below meaningless.
        assertEquals(26, HealthConnectAvailability.MIN_SUPPORTED_SDK)
        assertTrue(
            HealthConnectAvailability.MIN_SUPPORTED_SDK >= 26,
            "Health Connect's client library declares minSdk 26. Anything " +
                "lower requires claiming support the SDK does not have.",
        )
    }

    // -- 26-27: installs, reports unavailable, touches nothing ---------------

    @Test
    fun `API 26 and 27 report unavailable`() {
        for (sdk in 26..27) {
            val probe = Probe(HealthConnectClient.SDK_AVAILABLE)
            val result = HealthConnectAvailability.forSdk(sdk, probe::status)
            assertEquals(
                SourceAvailability.SERVICE_MISSING,
                result,
                "API $sdk must report unavailable: the Health Connect " +
                    "platform cannot exist below API 28",
            )
        }
    }

    @Test
    fun `API 26 and 27 never touch Health Connect`() {
        // The property that matters more than the answer. A version check that
        // returns the right value but still calls into the client has loaded
        // Health Connect classes on an OS that has no Health Connect, which is
        // one class-load away from a crash on a device nobody here owns.
        //
        // The probe returns SDK_AVAILABLE deliberately: if it were consulted,
        // the result would be AVAILABLE and this test would fail on the value
        // as well as on the call count.
        for (sdk in 26..27) {
            val probe = Probe(HealthConnectClient.SDK_AVAILABLE)
            HealthConnectAvailability.forSdk(sdk, probe::status)
            assertEquals(
                0,
                probe.calls,
                "API $sdk consulted Health Connect; it must not be reached",
            )
        }
    }

    @Test
    fun `an unavailable band asks for no permission and raises nothing`() {
        // `availability()` is the gate every other operation sits behind, and
        // it must answer rather than throw. A thrown exception here would reach
        // the player as a crash on launch, on a device where the correct
        // outcome is a fully playable game with no health integration.
        for (sdk in intArrayOf(26, 27)) {
            val result = HealthConnectAvailability.forSdk(sdk) {
                throw AssertionError("Health Connect was consulted on API $sdk")
            }
            assertEquals(SourceAvailability.SERVICE_MISSING, result)
        }
    }

    // -- 28+: normal checking ------------------------------------------------

    @Test
    fun `API 28 and above delegate to the platform status`() {
        assertEquals(28, HealthConnectAvailability.MIN_PLATFORM_SDK)

        for (sdk in intArrayOf(28, 29, 33, 34, 35, 36)) {
            val available = Probe(HealthConnectClient.SDK_AVAILABLE)
            assertEquals(
                SourceAvailability.AVAILABLE,
                HealthConnectAvailability.forSdk(sdk, available::status),
            )
            assertEquals(1, available.calls, "API $sdk must consult the platform")
        }
    }

    @Test
    fun `a provider needing an update is distinct from one being absent`() {
        val update = Probe(HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED)
        assertEquals(
            SourceAvailability.PROVIDER_UPDATE_REQUIRED,
            HealthConnectAvailability.forSdk(34, update::status),
        )

        val missing = Probe(HealthConnectClient.SDK_UNAVAILABLE)
        assertEquals(
            SourceAvailability.SERVICE_MISSING,
            HealthConnectAvailability.forSdk(34, missing::status),
        )
    }

    @Test
    fun `an unrecognised status is treated as absent, not as available`() {
        // Fail closed. A status this build does not know about must never be
        // optimistically read as "the platform is fine".
        val strange = Probe(Int.MAX_VALUE)
        assertEquals(
            SourceAvailability.SERVICE_MISSING,
            HealthConnectAvailability.forSdk(34, strange::status),
        )
    }
}
