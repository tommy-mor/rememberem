package com.rememberem.rememberem

import android.content.Context
import android.media.AudioAttributes
import android.os.Build
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * One short buzz for a right answer. Takes no arguments and returns
 * nothing, so it carries no data. Flutter's own haptics follow the
 * "touch interactions" setting, which many phones ship turned off.
 */
class Haptics(private val context: Context) : MethodChannel.MethodCallHandler {
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "tap") {
            result.notImplemented()
            return
        }
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.getSystemService(VibratorManager::class.java)?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
        if (vibrator?.hasVibrator() == true) {
            val tap = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                VibrationEffect.createOneShot(TAP_MS, VibrationEffect.DEFAULT_AMPLITUDE)
            } else {
                null
            }
            // Filed as media, not touch: touch vibration follows the
            // "touch interactions" setting that silenced Flutter's haptics.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                vibrator.vibrate(tap!!, VibrationAttributes.createForUsage(VibrationAttributes.USAGE_MEDIA))
            } else if (tap != null) {
                @Suppress("DEPRECATION")
                vibrator.vibrate(
                    tap,
                    AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_GAME).build(),
                )
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(TAP_MS)
            }
        }
        result.success(null)
    }

    companion object {
        const val CHANNEL = "com.rememberem.rememberem/haptics"
        private const val TAP_MS = 30L
    }
}
