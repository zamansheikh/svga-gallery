package com.silifton.svga_gallery

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasAccess" -> result.success(hasAccess())
                    "requestAccess" -> requestAccess(result)
                    "roots" -> result.success(storageRoots())
                    else -> result.notImplemented()
                }
            }
    }

    // .svga is not a media type, so on Android 11+ only "All files access"
    // can see files created by other apps. Android 10 and below use the
    // classic storage permission (with requestLegacyExternalStorage on 10).
    private fun hasAccess(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Environment.isExternalStorageManager()
        } else {
            LEGACY_PERMISSIONS.all {
                checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED
            }
        }

    private fun requestAccess(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            // Granted on a system settings screen; Dart re-checks on resume.
            try {
                startActivity(
                    Intent(
                        Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                        Uri.parse("package:$packageName"),
                    ),
                )
            } catch (e: Exception) {
                startActivity(Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION))
            }
            result.success(false)
        } else {
            pendingResult?.success(false)
            pendingResult = result
            requestPermissions(LEGACY_PERMISSIONS, REQUEST_CODE)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_CODE) return
        pendingResult?.success(hasAccess())
        pendingResult = null
    }

    /** Internal shared storage plus any SD card / USB volumes. */
    private fun storageRoots(): List<String> {
        val roots = linkedSetOf(Environment.getExternalStorageDirectory().absolutePath)
        for (dir in getExternalFilesDirs(null)) {
            val path = dir?.absolutePath ?: continue
            val index = path.indexOf("/Android/")
            if (index > 0) roots.add(path.substring(0, index))
        }
        return roots.toList()
    }

    private companion object {
        const val CHANNEL = "svga_gallery/storage"
        const val REQUEST_CODE = 4107
        val LEGACY_PERMISSIONS = arrayOf(
            Manifest.permission.READ_EXTERNAL_STORAGE,
            Manifest.permission.WRITE_EXTERNAL_STORAGE,
        )
    }
}
