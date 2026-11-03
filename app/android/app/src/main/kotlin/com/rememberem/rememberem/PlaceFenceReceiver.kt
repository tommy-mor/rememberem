package com.rememberem.rememberem

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent

/** Android says Fred has been at a watched place a while: notify, unless
 * that place already did recently. Runs without the app open. */
class PlaceFenceReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val event = GeofencingEvent.fromIntent(intent) ?: return
        if (event.hasError() || event.geofenceTransition != Geofence.GEOFENCE_TRANSITION_DWELL) {
            return
        }
        val registrar = PlaceFenceRegistrar(context)
        val notice = PlaceNotice(context)
        for (fence in event.triggeringGeofences.orEmpty()) {
            val place = registrar.nameOf(fence.requestId) ?: continue
            if (registrar.recentlyNotified(place)) continue
            notice.post(place)
            registrar.markNotified(place)
        }
    }
}
