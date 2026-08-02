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
        adapter = null
    }
}
