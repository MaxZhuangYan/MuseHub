package com.example.musehub

import android.Manifest
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Bundle
import android.os.Environment
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

// Extends AudioServiceActivity (instead of FlutterActivity) so
// audio_service can drive the media-session notification and
// lock-screen / headset controls.
class MainActivity : AudioServiceActivity() {

    private var pendingStorageResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestNotificationPermissionIfNeeded()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "musehub/system",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                // Shared Music/MuseHub — visible to file managers and to other
                // music apps (once scanned), unlike app-private storage.
                "sharedMusicDirectory" -> {
                    @Suppress("DEPRECATION")
                    val music = Environment.getExternalStoragePublicDirectory(
                        Environment.DIRECTORY_MUSIC,
                    )
                    result.success(File(music, "MuseHub").absolutePath)
                }
                "ensureSharedStorageWrite" -> ensureSharedStorageWrite(result)
                // Without a scan, files written to shared storage don't appear
                // in the phone's music app until the next full media rescan.
                "scanFile" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrEmpty()) {
                        result.success(false)
                    } else {
                        MediaScannerConnection.scanFile(this, arrayOf(path), null, null)
                        result.success(true)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    // Writing into shared Music: Android 10 and below need
    // WRITE_EXTERNAL_STORAGE (plus requestLegacyExternalStorage on 10).
    // Android 11+ lets an app create its own audio files there without any
    // permission, so there is nothing to ask for.
    private fun ensureSharedStorageWrite(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            result.success(true)
            return
        }
        val granted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.WRITE_EXTERNAL_STORAGE,
        ) == PackageManager.PERMISSION_GRANTED
        if (granted) {
            result.success(true)
            return
        }
        pendingStorageResult?.success(false)
        pendingStorageResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
            STORAGE_PERMISSION_REQUEST_CODE,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == STORAGE_PERMISSION_REQUEST_CODE) {
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingStorageResult?.success(granted)
            pendingStorageResult = null
        }
    }

    // From Android 13 (API 33) on, POST_NOTIFICATIONS is a runtime
    // permission — declaring it in the manifest is not enough. Without it
    // granted, the media notification never posts.
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
        const val STORAGE_PERMISSION_REQUEST_CODE = 1002
    }
}
