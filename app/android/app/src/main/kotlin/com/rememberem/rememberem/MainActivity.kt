package com.rememberem.rememberem

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var photoPicker: OriginalPhotoPicker? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val picker = OriginalPhotoPicker(this)
        photoPicker = picker
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OriginalPhotoPicker.CHANNEL)
            .setMethodCallHandler(picker)
    }

    @Deprecated("Needed for the document picker's result")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (photoPicker?.onActivityResult(requestCode, resultCode, data) != true) {
            super.onActivityResult(requestCode, resultCode, data)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        if (photoPicker?.onRequestPermissionsResult(requestCode) != true) {
            super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        }
    }
}
