package com.rememberem.rememberem

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Android forgets geofences on a restart or app update: watch the last
 * list again, if there is one and location is still allowed. */
class PlaceFenceBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED &&
            intent.action != Intent.ACTION_MY_PACKAGE_REPLACED
        ) {
            return
        }
        val registrar = PlaceFenceRegistrar(context)
        val fences = registrar.saved()
        if (fences.isEmpty() || !PlaceFenceRegistrar.hasLocation(context)) return
        val pending = goAsync()
        registrar.register(fences) { pending.finish() }
    }
}
