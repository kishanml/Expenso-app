package com.example.expenso

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// local_auth needs a FragmentActivity to host the biometric prompt.
// FlutterActivity is not one, so the app lock would fail at runtime with it.
class MainActivity : FlutterFragmentActivity() {

    private var smsReader: SmsReader? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val reader = SmsReader(this)
        smsReader = reader
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SmsReader.CHANNEL)
            .setMethodCallHandler(reader)
    }

    // The SMS permission dialog's answer arrives here, not through a plugin
    // binding, because the reader is part of the app rather than a plugin.
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        smsReader?.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }
}
