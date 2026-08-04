package com.projectstride.stride_health

import androidx.health.connect.client.HealthConnectClient

/**
 * Which API levels Project Stride supports, and what Health Connect answers on
 * each.
 *
 * ## The bands
 *
 * | API   | Behaviour |
 * |-------|-----------|
 * | 24-25 | **Unsupported.** The app does not install. `minSdk = 26`. |
 * | 26-27 | Installs. Health Connect reports **unavailable**. No permission is requested, nothing crashes, the game is fully playable. |
 * | 28+   | Normal availability checking through `getSdkStatus`. |
 *
 * ## Why this is a separate object with an injected SDK level
 *
 * `Build.VERSION.SDK_INT` is a static read against `android.jar`'s stub, which
 * answers 0 in a JVM unit test. A band decision written inline in
 * [HealthConnectStepSource] is therefore untestable without an emulator, and
 * `HealthConnectStepSource` is the one file in this plugin with no coverage at
 * all. Pulling the decision out makes the part that can be wrong the part that
 * is tested.
 *
 * ## Why 28 and not 26
 *
 * The client *library* declares `minSdk 26`, so 26 is the floor at which the
 * app may link it. The Health Connect *platform* is a different thing: it is
 * not present below Android 9, so on 26-27 the honest answer is "unavailable",
 * and it is reached **without touching a Health Connect type**.
 *
 * This previously read `< Build.VERSION_CODES.O` (26), which sent API 26-27
 * into `getSdkStatus`. That is a live call on a version where the platform
 * cannot exist — it would have answered "missing" in the end, but by a route
 * that loads Health Connect classes on a device that has no Health Connect.
 */
internal object HealthConnectAvailability {

    /**
     * The application's minimum. Below this the app does not install, so
     * nothing here can run — the constant exists so a test can assert the
     * floor rather than trust a Gradle file to stay put.
     */
    const val MIN_SUPPORTED_SDK: Int = 26

    /**
     * The first API level on which the Health Connect platform can exist.
     *
     * Between [MIN_SUPPORTED_SDK] and this, the app installs and runs and the
     * health integration reports itself unavailable — the same normal state as
     * a phone that simply has not installed Health Connect.
     */
    const val MIN_PLATFORM_SDK: Int = 28

    /**
     * [statusProvider] is invoked **only** when the platform could exist.
     *
     * That is the property worth asserting: on 26-27 nothing calls into Health
     * Connect at all. A version check that answers correctly but still touches
     * the client on an unsupported OS is one class-load away from a crash on a
     * device nobody testing this owns.
     */
    fun forSdk(sdkInt: Int, statusProvider: () -> Int): SourceAvailability {
        if (sdkInt < MIN_PLATFORM_SDK) return SourceAvailability.SERVICE_MISSING

        return when (statusProvider()) {
            HealthConnectClient.SDK_AVAILABLE -> SourceAvailability.AVAILABLE
            HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED ->
                SourceAvailability.PROVIDER_UPDATE_REQUIRED
            else -> SourceAvailability.SERVICE_MISSING
        }
    }
}
