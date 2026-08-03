package com.projectstride.stride_health

import android.app.Activity
import android.content.Intent
import androidx.health.connect.client.PermissionController
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.PluginRegistry
import kotlin.coroutines.resume
import kotlinx.coroutines.suspendCancellableCoroutine

/**
 * Project Stride — Android step integration.
 *
 * Registration, the Pigeon boundary, and the foreground activity the permission
 * sheet needs. Nothing else, and deliberately nothing else: there is no
 * background registration, no worker, no service, and no passive-monitoring
 * subscription anywhere in this plugin. S-01A is foreground synchronization;
 * S-01B is blocked on a real persistence coordinator (DECISIONS/0013,
 * DECISIONS/0014).
 *
 * See DECISIONS/0010_CROSS_PLATFORM_STACK.md.
 */
class StrideHealthPlugin : FlutterPlugin, ActivityAware, PluginRegistry.ActivityResultListener {

    private var adapter: HealthConnectAdapter? = null
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null

    /** The in-flight permission request, if the sheet is open. */
    private var pendingPermission: ((Set<String>?) -> Unit)? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val created = HealthConnectAdapter(
            HealthConnectStepSource(binding.applicationContext, requester)
        )
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
        adapter?.dispose()
        adapter = null
    }

    // -----------------------------------------------------------------------
    // ActivityAware -- the permission sheet, and nothing else
    // -----------------------------------------------------------------------

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onDetachedFromActivity() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
        activity = null
        // A sheet whose activity went away has no answer. Resolved as "could
        // not ask" rather than as a denial: the game never records a question
        // it failed to put as a no.
        pendingPermission?.invoke(null)
        pendingPermission = null
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != PERMISSION_REQUEST_CODE) return false
        val resume = pendingPermission ?: return false
        pendingPermission = null
        val granted = try {
            PermissionController.createRequestPermissionResultContract()
                .parseResult(resultCode, data)
        } catch (_: Throwable) {
            null
        }
        resume(granted)
        return true
    }

    private val requester = object : PermissionRequester {
        override suspend fun request(permissions: Set<String>): Set<String>? {
            val host = activity ?: return null
            if (pendingPermission != null) return null
            return suspendCancellableCoroutine { continuation ->
                pendingPermission = { granted -> continuation.resume(granted) }
                try {
                    val intent = PermissionController
                        .createRequestPermissionResultContract()
                        .createIntent(host, permissions)
                    host.startActivityForResult(intent, PERMISSION_REQUEST_CODE)
                } catch (_: Throwable) {
                    pendingPermission = null
                    continuation.resume(null)
                }
                continuation.invokeOnCancellation { pendingPermission = null }
            }
        }
    }

    private companion object {
        /** Arbitrary, and namespaced only by being this plugin's own. */
        const val PERMISSION_REQUEST_CODE = 0x53_48_01
    }
}
