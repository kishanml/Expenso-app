package com.example.expenso

import io.flutter.embedding.android.FlutterFragmentActivity

// local_auth needs a FragmentActivity to host the biometric prompt.
// FlutterActivity is not one, so the app lock would fail at runtime with it.
class MainActivity : FlutterFragmentActivity()
