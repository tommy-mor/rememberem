package com.rememberem.rememberem

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Lets Fred choose a photo and returns its original bytes, EXIF location
 * included. The system photo picker always strips GPS, so this uses the
 * document picker and, with ACCESS_MEDIA_LOCATION, asks MediaStore for the
 * unredacted original. Nothing is copied: the bytes go straight to Dart.
 */
class OriginalPhotoPicker(private val activity: Activity) : MethodChannel.MethodCallHandler {
    private var pending: MethodChannel.Result? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "pick") {
            result.notImplemented()
            return
        }
        if (pending != null) {
            result.error("busy", "A photo is already being chosen", null)
            return
        }
        pending = result
        if (needsLocationPermission()) {
            // Asked once, at the moment Fred chooses a photo; a refusal just
            // means the photo comes without its location.
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
            result.success(readOriginal(uri))
        } catch (e: Exception) {
            result.error("unreadable", e.message, null)
        }
        return true
    }

    private fun needsLocationPermission() =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            activity.checkSelfPermission(Manifest.permission.ACCESS_MEDIA_LOCATION) !=
            PackageManager.PERMISSION_GRANTED &&
            !asked.also { asked = true }

    private fun openPicker() {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT)
            .addCategory(Intent.CATEGORY_OPENABLE)
            .setType("image/jpeg")
        activity.startActivityForResult(intent, PICK_REQUEST)
    }

    /** The original bytes if MediaStore will give them, else as picked. */
    private fun readOriginal(uri: Uri): ByteArray {
        val resolver = activity.contentResolver
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            try {
                val media = MediaStore.getMediaUri(activity, uri)
                if (media != null) {
                    resolver.openInputStream(MediaStore.setRequireOriginal(media))
                        ?.use { return it.readBytes() }
                }
            } catch (_: Exception) {
                // Not a media document, or no location permission: fall back.
            }
        }
        return resolver.openInputStream(uri)?.use { it.readBytes() }
            ?: throw IllegalStateException("Photo could not be opened")
    }

    companion object {
        const val CHANNEL = "com.rememberem.rememberem/original_photo"
        private const val PICK_REQUEST = 4801
        private const val PERMISSION_REQUEST = 4802

        /** The permission is asked for at most once per run. */
        private var asked = false
    }
}
