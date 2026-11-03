package com.rememberem.rememberem

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.provider.ContactsContract
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Links people to phone contacts through the phone's own contact picker,
 * which grants read access to just the contact Fred chooses. Rememberem
 * reads only that contact's lookup key, never the contact list, and never
 * writes to the contacts, so it needs no contacts permission.
 */
class ContactsChannel(private val activity: Activity) : MethodChannel.MethodCallHandler {
    private var pendingPick: MethodChannel.Result? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pick" -> pick(result)
            "open" -> result.success(open(call.argument<String>("key") ?: ""))
            else -> result.notImplemented()
        }
    }

    private fun pick(result: MethodChannel.Result) {
        if (pendingPick != null) {
            result.error("busy", "A contact is already being chosen", null)
            return
        }
        pendingPick = result
        try {
            activity.startActivityForResult(
                Intent(Intent.ACTION_PICK, ContactsContract.Contacts.CONTENT_URI),
                PICK_REQUEST,
            )
        } catch (e: ActivityNotFoundException) {
            pendingPick = null
            result.success(null)
        }
    }

    /** From the activity; true if the result was this channel's. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != PICK_REQUEST) return false
        val result = pendingPick ?: return true
        pendingPick = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return true
        }
        try {
            // The picker grants read access to just this one contact.
            val key = activity.contentResolver.query(
                uri,
                arrayOf(ContactsContract.Contacts.LOOKUP_KEY),
                null,
                null,
                null,
            )?.use { cursor -> if (cursor.moveToFirst()) cursor.getString(0) else null }
            result.success(key)
        } catch (e: Exception) {
            result.success(null)
        }
        return true
    }

    /**
     * "opened" or "noApp". Without the contacts permission a deleted contact
     * can't be told apart, so the contacts app shows its own "not found".
     */
    private fun open(key: String): String {
        if (key.isBlank()) return "notFound"
        val lookup = Uri.withAppendedPath(ContactsContract.Contacts.CONTENT_LOOKUP_URI, key)
        return try {
            activity.startActivity(Intent(Intent.ACTION_VIEW, lookup))
            "opened"
        } catch (e: ActivityNotFoundException) {
            "noApp"
        }
    }

    companion object {
        const val CHANNEL = "com.rememberem.rememberem/contacts"
        private const val PICK_REQUEST = 4811
    }
}
