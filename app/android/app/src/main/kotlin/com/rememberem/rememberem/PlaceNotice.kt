package com.rememberem.rememberem

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * The notice for arriving at a place. It names the place, never a person,
 * and shows only a generic line on a locked screen. It stays on the phone:
 * not bridged to watches.
 */
class PlaceNotice(private val context: Context) {
    companion object {
        const val CHANNEL = "places"

        /** The extra on MainActivity's intent naming the tapped place. */
        const val EXTRA_PLACE = "com.rememberem.rememberem.place"

        /** With the place as the tag, a place has at most one notice. */
        private const val NOTICE_ID = 21
    }

    fun post(place: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            !PlaceFenceRegistrar.granted(context, Manifest.permission.POST_NOTIFICATIONS)
        ) {
            return
        }
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Created here: the app may not have run since the phone started.
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL,
                    "Place notifications",
                    NotificationManager.IMPORTANCE_DEFAULT,
                ).apply {
                    description = "When you arrive at a place where you met people"
                    lockscreenVisibility = Notification.VISIBILITY_PRIVATE
                },
            )
        }
        val public = builder()
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Rememberem")
            .setContentText("You're at a place you know")
            .build()
        val notice = builder()
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("You're at $place")
            .setContentText("See who you've met here")
            .setContentIntent(open(place))
            .setAutoCancel(true)
            .setLocalOnly(true)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setPublicVersion(public)
            .build()
        manager.notify(place, NOTICE_ID, notice)
    }

    @Suppress("DEPRECATION") // Builder(Context) is the only one before API 26
    private fun builder(): Notification.Builder =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL)
        } else {
            Notification.Builder(context)
        }

    /**
     * Brings the app's own task forward (or starts it) with the place. The
     * same launch intent the reminder plugin uses, so a warm tap arrives
     * through onNewIntent (MainActivity is singleTop).
     */
    private fun open(place: String): PendingIntent {
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        launch.setPackage(context.packageName).putExtra(EXTRA_PLACE, place)
        return PendingIntent.getActivity(
            context,
            place.hashCode(),
            launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
