package com.rememberem.rememberem

import android.Manifest
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.ContactsContract
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Links people to phone contacts. Reads only each contact's lookup key and
 * display name, only for the list Fred is choosing from, and never writes
 * to the contacts. Without READ_CONTACTS the system contact picker still
 * works, and opening a contact needs no permission at all.
 */
class ContactsChannel(private val activity: Activity) : MethodChannel.MethodCallHandler {
    private var pendingAccess: MethodChannel.Result? = null
    private var pendingPick: MethodChannel.Result? = null
    private val main = Handler(Looper.getMainLooper())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "ensureAccess" -> ensureAccess(result)
            "list" -> list(result)
            "pick" -> pick(result)
            "open" -> result.success(open(call.argument<String>("key") ?: ""))
            else -> result.notImplemented()
        }
    }

    private fun hasAccess() =
        activity.checkSelfPermission(Manifest.permission.READ_CONTACTS) ==
            PackageManager.PERMISSION_GRANTED

    private fun ensureAccess(result: MethodChannel.Result) {
        if (hasAccess()) {
            result.success(true)
            return
        }
        if (pendingAccess != null) {
            result.error("busy", "Already asking", null)
            return
        }
        pendingAccess = result
        activity.requestPermissions(
            arrayOf(Manifest.permission.READ_CONTACTS),
            PERMISSION_REQUEST,
        )
    }

    /** From the activity; true if the request was this channel's. */
    fun onRequestPermissionsResult(requestCode: Int): Boolean {
        if (requestCode != PERMISSION_REQUEST) return false
        val result = pendingAccess ?: return true
        pendingAccess = null
        result.success(hasAccess())
        return true
    }

    /** Every contact's lookup key and name, A to Z, read off the main thread. */
    private fun list(result: MethodChannel.Result) {
        if (!hasAccess()) {
            result.error("denied", "No contacts permission", null)
            return
        }
        Thread {
            try {
                val entries = mutableListOf<Map<String, String>>()
                activity.contentResolver.query(
                    ContactsContract.Contacts.CONTENT_URI,
                    arrayOf(
                        ContactsContract.Contacts.LOOKUP_KEY,
                        ContactsContract.Contacts.DISPLAY_NAME_PRIMARY,
                    ),
                    null,
                    null,
                    ContactsContract.Contacts.DISPLAY_NAME_PRIMARY + " COLLATE LOCALIZED ASC",
                )?.use { cursor ->
                    while (cursor.moveToNext()) {
                        val key = cursor.getString(0) ?: continue
                        val name = cursor.getString(1) ?: continue
                        entries.add(mapOf("key" to key, "name" to name))
                    }
                }
                main.post { result.success(entries) }
            } catch (e: Exception) {
                main.post { result.error("unreadable", "Contacts could not be read", null) }
            }
        }.start()
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

    /** "opened", "notFound" or "noApp". */
    private fun open(key: String): String {
        if (key.isBlank()) return "notFound"
        val lookup = Uri.withAppendedPath(ContactsContract.Contacts.CONTENT_LOOKUP_URI, key)
        // Only with permission can a deleted contact be told apart; without
        // it the contacts app shows its own "not found".
        if (hasAccess()) {
            val found = try {
                ContactsContract.Contacts.lookupContact(activity.contentResolver, lookup)
            } catch (e: Exception) {
                null
            }
            if (found == null) return "notFound"
        }
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
        private const val PERMISSION_REQUEST = 4812
    }
}
