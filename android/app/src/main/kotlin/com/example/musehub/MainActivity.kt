package com.example.musehub

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.ryanheise.audioservice.AudioServiceActivity

// Extends AudioServiceActivity (instead of FlutterActivity) so
// audio_service can drive the media-session notification and
// lock-screen / headset controls.
class MainActivity : AudioServiceActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestNotificationPermissionIfNeeded()
    }

    // From Android 13 (API 33) on, POST_NOTIFICATIONS is a runtime
    // permission — declaring it in the manifest is not enough. Without it
    // granted, the media notification never posts, so the phone's control
    // centre shows no transport controls at all (macOS was unaffected
    // because it needs no such grant, which is why media keys worked there
    // while the phone stayed empty).
    //
    // Done natively rather than via a Dart permission plugin so this adds
    // no new dependency or compileSdk requirement to the build.
    private fun requestNotificationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        val granted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED
        if (granted) return
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_PERMISSION_REQUEST_CODE,
        )
    }

    private companion object {
        const val NOTIFICATION_PERMISSION_REQUEST_CODE = 1001
    }
}
