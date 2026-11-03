package com.rememberem.rememberem

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var photoPicker: OriginalPhotoPicker? = null
    private var contacts: ContactsChannel? = null
    private var placeFences: PlaceFences? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        val picker = OriginalPhotoPicker(this)
        photoPicker = picker
        MethodChannel(messenger, OriginalPhotoPicker.CHANNEL).setMethodCallHandler(picker)
        val contactsChannel = ContactsChannel(this)
        contacts = contactsChannel
        MethodChannel(messenger, ContactsChannel.CHANNEL).setMethodCallHandler(contactsChannel)
        MethodChannel(messenger, Haptics.CHANNEL).setMethodCallHandler(Haptics(this))
        val placeChannel = MethodChannel(messenger, PlaceFences.CHANNEL)
        val places = PlaceFences(this, placeChannel)
        places.onLaunch(intent)
        placeFences = places
        placeChannel.setMethodCallHandler(places)
    }

    override fun onNewIntent(intent: Intent) {
        // super first: the shortcut plugin reads its own intents there.
        super.onNewIntent(intent)
        placeFences?.onNewIntent(intent)
    }

    @Deprecated("Needed for the pickers' results")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        val handled = photoPicker?.onActivityResult(requestCode, resultCode, data) == true ||
            contacts?.onActivityResult(requestCode, resultCode, data) == true
        if (!handled) super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        val handled = photoPicker?.onRequestPermissionsResult(requestCode) == true ||
            placeFences?.onRequestPermissionsResult(requestCode) == true
        if (!handled) super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }
}
