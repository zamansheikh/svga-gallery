package com.silifton.svga_gallery

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.OpenableColumns
import android.provider.Settings
import android.widget.Toast
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private var pendingResult: MethodChannel.Result? = null

    // Files other apps asked us to open, copied into the cache. They wait in
    // [openedQueue] until Dart asks for them ("takePending"), then go out as
    // they arrive. Touched on the main thread only.
    private val openedQueue = mutableListOf<String>()
    private var openChannel: MethodChannel? = null
    private var dartListening = false
    private val copier = Executors.newSingleThreadExecutor()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // A re-created activity gets its launch intent again; it was handled.
        if (savedInstanceState == null) receive(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        receive(intent)
    }

    override fun onDestroy() {
        copier.shutdown()
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        MethodChannel(messenger, STORAGE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasAccess" -> result.success(hasAccess())
                    "requestAccess" -> requestAccess(result)
                    "roots" -> result.success(storageRoots())
                    else -> result.notImplemented()
                }
            }
        openChannel = MethodChannel(messenger, OPEN_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                if (call.method == "takePending") {
                    dartListening = true
                    result.success(ArrayList(openedQueue))
                    openedQueue.clear()
                } else {
                    result.notImplemented()
                }
            }
        }
    }

    // --- Opening files ("Open with", share sheet) ---

    private fun receive(intent: Intent?) {
        if (intent == null) return
        // Relaunched from Recents: the original file was handled already, and
        // the read grant for it is usually gone.
        if (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return
        val uris = urisOf(intent)
        if (uris.isEmpty()) return
        copier.execute {
            val copied = uris.mapNotNull { copyToCache(it) }
            val failed = uris.size - copied.size
            runOnUiThread { deliver(copied, failed) }
        }
    }

    @Suppress("DEPRECATION")
    private fun urisOf(intent: Intent): List<Uri> {
        val uris = when (intent.action) {
            Intent.ACTION_VIEW -> listOfNotNull(intent.data)
            Intent.ACTION_SEND -> listOfNotNull(
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    intent.getParcelableExtra(Intent.EXTRA_STREAM)
                },
            )
            Intent.ACTION_SEND_MULTIPLE ->
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM)
                }?.filterNotNull().orEmpty()
            else -> return emptyList()
        }
        if (uris.isNotEmpty()) return uris
        val clip = intent.clipData ?: return emptyList()
        return (0 until clip.itemCount).mapNotNull { clip.getItemAt(it).uri }
    }

    /**
     * Copies [uri] to `<cache>/opened/<n>/<display name>` and returns the path.
     * The grant to read it ends with the intent, so Dart gets a copy it can
     * read whenever it is ready; Dart deletes the copy after importing it.
     */
    private fun copyToCache(uri: Uri): String? {
        val dir = File(cacheDir, "opened/${System.nanoTime()}")
        return try {
            dir.mkdirs()
            val file = File(dir, displayName(uri))
            val input = contentResolver.openInputStream(uri) ?: throw IOException("no stream")
            input.use { source ->
                file.outputStream().use { sink ->
                    val buffer = ByteArray(64 * 1024)
                    var total = 0L
                    while (true) {
                        val read = source.read(buffer)
                        if (read < 0) break
                        total += read
                        if (total > MAX_OPEN_BYTES) throw IOException("too large")
                        sink.write(buffer, 0, read)
                    }
                }
            }
            file.absolutePath
        } catch (e: Exception) {
            dir.deleteRecursively()
            null
        }
    }

    private fun displayName(uri: Uri): String {
        var name: String? = null
        if (uri.scheme == "content") {
            try {
                contentResolver.query(
                    uri,
                    arrayOf(OpenableColumns.DISPLAY_NAME),
                    null,
                    null,
                    null,
                )?.use { cursor ->
                    if (cursor.moveToFirst() && !cursor.isNull(0)) {
                        name = cursor.getString(0)
                    }
                }
            } catch (e: Exception) {
                // Some providers reject queries; fall back to the URI path.
            }
        }
        if (name.isNullOrBlank()) name = uri.lastPathSegment?.substringAfterLast('/')
        return name?.replace('/', '_')?.takeIf { it.isNotBlank() } ?: "animation.svga"
    }

    private fun deliver(paths: List<String>, failed: Int) {
        if (failed > 0) {
            Toast.makeText(
                this,
                if (failed == 1) "Could not read this file" else "Could not read $failed files",
                Toast.LENGTH_SHORT,
            ).show()
        }
        if (paths.isEmpty()) return
        val channel = openChannel
        if (dartListening && channel != null) {
            channel.invokeMethod("open", paths)
        } else {
            openedQueue.addAll(paths)
        }
    }

    // --- Device scan permissions ---

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
        const val STORAGE_CHANNEL = "svga_gallery/storage"
        const val OPEN_CHANNEL = "svga_gallery/open"
        const val REQUEST_CODE = 4107

        // The app accepts any binary from "Open with"; refuse to copy
        // something far bigger than an SVGA animation ever is.
        const val MAX_OPEN_BYTES = 100L * 1024 * 1024
        val LEGACY_PERMISSIONS = arrayOf(
            Manifest.permission.READ_EXTERNAL_STORAGE,
            Manifest.permission.WRITE_EXTERNAL_STORAGE,
        )
    }
}
