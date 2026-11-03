package com.rememberem.rememberem

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * The `rememberem/place_fences` channel: what place notifications are
 * allowed, asking for it, which places to watch, and taps on the notice.
 */
class PlaceFences(
    private val activity: Activity,
    private val channel: MethodChannel,
) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "rememberem/place_fences"
        private const val REQUEST_NOTIFICATIONS = 4811
        private const val REQUEST_LOCATION = 4812
        private const val REQUEST_BACKGROUND = 4813
    }

    private val registrar = PlaceFenceRegistrar(activity)
    private var pending: MethodChannel.Result? = null
    private var launchPlace: String? = null

    /** The intent that started the activity: keep its place for Dart. */
    fun onLaunch(intent: Intent?) {
        val place = takePlace(intent) ?: return
        // Reopened from Recents after Android closed the app: Android hands
        // back the old notice's intent, which was already seen.
        val fromRecents = intent!!.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0
        if (!fromRecents) launchPlace = place
    }

    /** A notice tapped while the app runs. True if it was one. */
    fun onNewIntent(intent: Intent): Boolean {
        val place = takePlace(intent) ?: return false
        channel.invokeMethod("tap", place)
        return true
    }

    /** Reads the place and removes it, so a recreated activity can't
     * open it again. */
    private fun takePlace(intent: Intent?): String? {
        val place = intent?.getStringExtra(PlaceNotice.EXTRA_PLACE) ?: return null
        intent.removeExtra(PlaceNotice.EXTRA_PLACE)
        return place
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "access" -> result.success(access())
            "requestAccess" -> {
                // A request left hanging (activity recreated) answers now.
                pending?.success(access())
                pending = result
                askNext()
            }
            "replace" -> {
                val fences = PlaceFenceRegistrar.parse(call.arguments as? List<*>)
                registrar.register(fences, save = true) { ok ->
                    activity.runOnUiThread { result.success(ok) }
                }
            }
            "launchPlace" -> {
                result.success(launchPlace)
                launchPlace = null
            }
            "openSettings" -> {
                activity.startActivity(
                    Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                        .setData(Uri.fromParts("package", activity.packageName, null)),
                )
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    /** The first thing missing, by the name Dart's PlaceAlertAccess uses. */
    private fun access(): String = when {
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            !PlaceFenceRegistrar.granted(activity, Manifest.permission.POST_NOTIFICATIONS) ->
            "notifications"
        !PlaceFenceRegistrar.granted(activity, Manifest.permission.ACCESS_FINE_LOCATION) ->
            "location"
        !PlaceFenceRegistrar.hasLocation(activity) -> "background"
        else -> "granted"
    }

    /** Asks for the next missing permission, or answers the request. Background
     * location is asked alone and last; on Android 11+ that opens Settings. */
    private fun askNext() {
        val result = pending ?: return
        when (access()) {
            "notifications" -> activity.requestPermissions(
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                REQUEST_NOTIFICATIONS,
            )
            "location" -> activity.requestPermissions(
                arrayOf(
                    Manifest.permission.ACCESS_FINE_LOCATION,
                    Manifest.permission.ACCESS_COARSE_LOCATION,
                ),
                REQUEST_LOCATION,
            )
            "background" -> activity.requestPermissions(
                arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION),
                REQUEST_BACKGROUND,
            )
            else -> {
                pending = null
                result.success("granted")
            }
        }
    }

    /** From the activity; true if the request was this channel's. */
    fun onRequestPermissionsResult(requestCode: Int): Boolean {
        val asked = when (requestCode) {
            REQUEST_NOTIFICATIONS -> "notifications"
            REQUEST_LOCATION -> "location"
            REQUEST_BACKGROUND -> "background"
            else -> return false
        }
        val result = pending ?: return true
        val missing = access()
        if (missing == asked) {
            // Refused: stop here and say what is missing.
            pending = null
            result.success(missing)
        } else {
            askNext()
        }
        return true
    }
}
