package com.example.comic_vault

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity is required by the local_auth plugin so that
// Android's BiometricPrompt can attach to the correct fragment host.
class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Prevent the app from appearing in the Recents thumbnail and block
        // screen capture / screen recording / mirroring.
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }
}
