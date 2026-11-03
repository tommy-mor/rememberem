package com.rememberem.rememberem

import android.Manifest
import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices
import org.json.JSONArray
import org.json.JSONObject

/**
 * Keeps the list of watched places in app-private preferences (left out of
 * backup, see backup_rules.xml) and hands it to Android's geofencing. The
 * channel and the boot receiver share it. Nothing is logged: the list
 * holds place names and where they are.
 */
class PlaceFenceRegistrar(context: Context) {
    private val context = context.applicationContext
    private val prefs = this.context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    companion object {
        const val PREFS = "place_fences"
        private const val KEY_FENCES = "fences"
        private const val NOTIFIED = "notified:"

        /** Arriving at the same place again this soon sends no second notice. */
        const val COOLDOWN_MILLIS = 12L * 60 * 60 * 1000

        /** About five minutes inside counts as arriving; driving past does not. */
        const val LOITERING_MILLIS = 5 * 60 * 1000

        fun granted(context: Context, permission: String) =
            context.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED

        /** Precise location, and on Android 10+ "all the time". */
        fun hasLocation(context: Context): Boolean =
            granted(context, Manifest.permission.ACCESS_FINE_LOCATION) &&
                (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
                    granted(context, Manifest.permission.ACCESS_BACKGROUND_LOCATION))

        /** Reads the list the app sent; anything malformed is skipped. */
        fun parse(list: List<*>?): List<SavedFence> = list.orEmpty().mapNotNull { item ->
            val map = item as? Map<*, *> ?: return@mapNotNull null
            val name = map["name"] as? String ?: return@mapNotNull null
            val latitude = (map["latitude"] as? Number)?.toDouble() ?: return@mapNotNull null
            val longitude = (map["longitude"] as? Number)?.toDouble() ?: return@mapNotNull null
            val radius = (map["radius"] as? Number)?.toDouble() ?: return@mapNotNull null
            // One bad entry must not stop every other place being watched.
            if (name.isBlank() || !(latitude in -90.0..90.0) ||
                !(longitude in -180.0..180.0) || !(radius > 0)
            ) {
                return@mapNotNull null
            }
            SavedFence(name, latitude, longitude, radius)
        }
    }

    /** The saved list; empty if there is none or it can't be read. */
    fun saved(): List<SavedFence> = try {
        val array = JSONArray(prefs.getString(KEY_FENCES, "[]"))
        (0 until array.length()).mapNotNull { i ->
            val o = array.optJSONObject(i) ?: return@mapNotNull null
            SavedFence(
                o.getString("name"),
                o.getDouble("latitude"),
                o.getDouble("longitude"),
                o.getDouble("radius"),
            )
        }
    } catch (_: Exception) {
        emptyList()
    }

    /** Saves [fences], forgetting when places no longer watched last notified. */
    fun save(fences: List<SavedFence>) {
        val array = JSONArray()
        for (fence in fences) {
            array.put(
                JSONObject()
                    .put("name", fence.name)
                    .put("latitude", fence.latitude)
                    .put("longitude", fence.longitude)
                    .put("radius", fence.radius),
            )
        }
        val names = fences.map { it.name }.toSet()
        val edit = prefs.edit().putString(KEY_FENCES, array.toString())
        for (key in prefs.all.keys) {
            if (key.startsWith(NOTIFIED) && key.removePrefix(NOTIFIED) !in names) {
                edit.remove(key)
            }
        }
        edit.apply()
    }

    /** The place a fence id (its index in the saved list) stands for. */
    fun nameOf(requestId: String): String? =
        requestId.toIntOrNull()?.let { saved().getOrNull(it)?.name }

    fun recentlyNotified(place: String, now: Long = System.currentTimeMillis()): Boolean {
        val last = prefs.getLong(NOTIFIED + place, 0L)
        return last in (now - COOLDOWN_MILLIS + 1)..now
    }

    fun markNotified(place: String, now: Long = System.currentTimeMillis()) {
        prefs.edit().putLong(NOTIFIED + place, now).apply()
    }

    /**
     * Watches exactly [fences] (none: stops watching), saving them as the
     * list if [save]. [done] gets false if Android could not, such as with
     * location off or no Play services.
     */
    fun register(fences: List<SavedFence>, save: Boolean = false, done: (Boolean) -> Unit) {
        try {
            val client = LocationServices.getGeofencingClient(context)
            val intent = pendingIntent()
            client.removeGeofences(intent).addOnCompleteListener {
                // Saved only once the old fences are gone, so an old fence's
                // id can never be read against the new list.
                if (save) save(fences)
                when {
                    fences.isEmpty() -> done(true)
                    !hasLocation(context) -> done(false)
                    else -> add(client, intent, fences, retries = 1, done)
                }
            }
        } catch (_: Exception) {
            if (save) save(fences)
            done(fences.isEmpty())
        }
    }

    @SuppressLint("MissingPermission") // checked by hasLocation
    private fun add(
        client: com.google.android.gms.location.GeofencingClient,
        intent: PendingIntent,
        fences: List<SavedFence>,
        retries: Int,
        done: (Boolean) -> Unit,
    ) {
        try {
            client.addGeofences(request(fences), intent)
                .addOnSuccessListener { done(true) }
                .addOnFailureListener {
                    // Once more, for a passing hiccup; otherwise the next
                    // app open tries again.
                    if (retries > 0) add(client, intent, fences, retries - 1, done) else done(false)
                }
        } catch (_: Exception) {
            done(false)
        }
    }

    private fun request(fences: List<SavedFence>): GeofencingRequest =
        GeofencingRequest.Builder()
            // No notice for a place Fred is already at when the list changes.
            .setInitialTrigger(0)
            .addGeofences(
                fences.mapIndexed { i, fence ->
                    Geofence.Builder()
                        .setRequestId(i.toString())
                        .setCircularRegion(
                            fence.latitude,
                            fence.longitude,
                            fence.radius.toFloat(),
                        )
                        .setExpirationDuration(Geofence.NEVER_EXPIRE)
                        .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_DWELL)
                        .setLoiteringDelay(LOITERING_MILLIS)
                        .build()
                },
            )
            .build()

    /** Explicit, so only PlaceFenceReceiver can get it; mutable so Play
     * services can add the event. */
    private fun pendingIntent(): PendingIntent {
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0)
        return PendingIntent.getBroadcast(
            context,
            0,
            Intent(context, PlaceFenceReceiver::class.java),
            flags,
        )
    }
}
