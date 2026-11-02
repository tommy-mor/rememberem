package com.rememberem.rememberem

import android.Manifest
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Lets Fred choose a photo with the phone's own gallery picker and returns
 * its bytes, EXIF location included where allowed: with
 * ACCESS_MEDIA_LOCATION, MediaStore gives the unredacted original. The
 * result says whether it did, so the app can tell Fred when a location was
 * held back. Nothing is copied: the bytes go straight to Dart.
 */
class OriginalPhotoPicker(private val activity: Activity) : MethodChannel.MethodCallHandler {
    private var pending: MethodChannel.Result? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pick" -> pick(result)
            "openSettings" -> {
                // Only this app's own page; nothing is passed along.
                activity.startActivity(
                    Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                        .setData(Uri.fromParts("package", activity.packageName, null)),
                )
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun pick(result: MethodChannel.Result) {
        if (pending != null) {
            result.error("busy", "A photo is already being chosen", null)
            return
        }
        pending = result
        if (needsLocationPermission()) {
            // Asked when Fred taps the gallery button, until he allows it or
            // Android stops asking; a refusal just means no location.
            activity.requestPermissions(
                arrayOf(Manifest.permission.ACCESS_MEDIA_LOCATION),
                PERMISSION_REQUEST,
            )
        } else {
            openPicker()
        }
    }

    /** From the activity; true if the request was this picker's. */
    fun onRequestPermissionsResult(requestCode: Int): Boolean {
        if (requestCode != PERMISSION_REQUEST) return false
        openPicker()
        return true
    }

    /** From the activity; true if the result was this picker's. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != PICK_REQUEST) return false
        val result = pending ?: return true
        pending = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return true
        }
        try {
            result.success(read(uri))
        } catch (e: Exception) {
            result.error("unreadable", e.message, null)
        }
        return true
    }

    private fun needsLocationPermission() =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && !hasLocationPermission()

    private fun hasLocationPermission() =
        activity.checkSelfPermission(Manifest.permission.ACCESS_MEDIA_LOCATION) ==
            PackageManager.PERMISSION_GRANTED

    private fun openPicker() {
        val gallery = Intent(Intent.ACTION_PICK)
            .setDataAndType(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, "image/jpeg")
        try {
            activity.startActivityForResult(gallery, PICK_REQUEST)
        } catch (_: ActivityNotFoundException) {
            // No gallery app: the system's document picker always exists.
            val documents = Intent(Intent.ACTION_OPEN_DOCUMENT)
                .addCategory(Intent.CATEGORY_OPENABLE)
                .setType("image/jpeg")
            activity.startActivityForResult(documents, PICK_REQUEST)
        }
    }

    /**
     * The photo's bytes and whether they are the unredacted original.
     * Before Android 10 nothing is redacted.
     */
    private fun read(uri: Uri): Map<String, Any> {
        val resolver = activity.contentResolver
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return mapOf("bytes" to readAll(uri), "original" to true)
        }
        if (hasLocationPermission()) {
            try {
                val media = if (uri.authority == MediaStore.AUTHORITY) {
                    uri
                } else {
                    MediaStore.getMediaUri(activity, uri)
                }
                if (media != null) {
                    resolver.openInputStream(MediaStore.setRequireOriginal(media))?.use {
                        return mapOf("bytes" to it.readBytes(), "original" to true)
                    }
                }
            } catch (_: Exception) {
                // Not a MediaStore photo (e.g. a cloud app's own copy), or
                // only limited photo access: fall back, saying so.
            }
        }
        return mapOf("bytes" to readAll(uri), "original" to false)
    }

    private fun readAll(uri: Uri): ByteArray =
        activity.contentResolver.openInputStream(uri)?.use { it.readBytes() }
            ?: throw IllegalStateException("Photo could not be opened")

    companion object {
        const val CHANNEL = "com.rememberem.rememberem/original_photo"
        private const val PICK_REQUEST = 4801
        private const val PERMISSION_REQUEST = 4802
    }
}
