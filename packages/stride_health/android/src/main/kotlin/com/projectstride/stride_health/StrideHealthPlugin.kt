package com.projectstride.stride_health

import io.flutter.embedding.engine.plugins.FlutterPlugin

/**
 * Project Stride — Android step integration.
 *
 * M-2 scope: registration and the Pigeon boundary only. The Health Connect
 * implementation is task S-01.
 *
 * See DECISIONS/0010_CROSS_PLATFORM_STACK.md.
 */
class StrideHealthPlugin : FlutterPlugin {

    private var adapter: HealthConnectAdapter? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val created = HealthConnectAdapter(binding.applicationContext)
        adapter = created
        HealthHostApi.setUp(binding.binaryMessenger, created)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        HealthHostApi.setUp(binding.binaryMessenger, null)
        // The keying salt is the app's device-bound identity, held here only
        // for the lifetime of the attachment. Dropping it on detach is what
        // makes "in memory only" true rather than merely intended -- and it
        // means the next attachment must install it again, which is the
        // fail-closed path.
        adapter?.forgetOriginKeying()
        adapter = null
    }
}
