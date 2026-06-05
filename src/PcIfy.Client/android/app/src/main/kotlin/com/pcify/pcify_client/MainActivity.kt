package com.pcify.pcify_client

import android.content.ActivityNotFoundException
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.util.Rational
import android.webkit.MimeTypeMap
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.pcify.pcify_client/downloads"
        private const val PIP_CHANNEL = "com.pcify.pcify_client/pip"
        private const val REQUEST_WRITE_PERMISSION = 1001
    }

    private var pendingResult: MethodChannel.Result? = null
    private var pendingTempPath: String? = null
    private var pendingFileName: String? = null
    private var pipChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Picture-in-Picture channel
        pipChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PIP_CHANNEL)
        pipChannel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "isAvailable" -> result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                "enterPipMode" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val num = call.argument<Int>("ratioNum") ?: 16
                        val den = call.argument<Int>("ratioDen") ?: 9
                        val params = android.app.PictureInPictureParams.Builder()
                            .setAspectRatio(Rational(num, den))
                            .build()
                        enterPictureInPictureMode(params)
                        result.success(null)
                    } else {
                        result.error("NOT_SUPPORTED", "PiP requires Android 8+", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveToSystemDownloads" -> {
                    val tempPath = call.argument<String>("tempPath")
                    val fileName = call.argument<String>("fileName")
                    if (tempPath == null || fileName == null) {
                        result.error("INVALID_ARGS", "tempPath and fileName are required", null)
                    } else {
                        saveToSystemDownloads(tempPath, fileName, result)
                    }
                }
                "openFileFromUri" -> {
                    val uriStr = call.argument<String>("uri") ?: ""
                    val ext = call.argument<String>("ext") ?: ""
                    val mime = MimeTypeMap.getSingleton()
                        .getMimeTypeFromExtension(ext.lowercase()) ?: "*/*"
                    try {
                        val uri = Uri.parse(uriStr)
                        val intent = Intent(Intent.ACTION_VIEW)
                        intent.setDataAndType(uri, mime)
                        intent.addFlags(
                            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                            Intent.FLAG_ACTIVITY_NEW_TASK
                        )
                        startActivity(intent)
                        result.success(null)
                    } catch (e: ActivityNotFoundException) {
                        result.error("NO_APP", "No app found to open this file type", null)
                    } catch (e: Exception) {
                        result.error("OPEN_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun saveToSystemDownloads(tempPath: String, fileName: String, result: MethodChannel.Result) {
        val ext = fileName.substringAfterLast('.', "").lowercase()
        val mimeType = MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext)
            ?: "application/octet-stream"

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // API 29+: MediaStore.Downloads — no storage permissions needed
            Thread {
                try {
                    val values = ContentValues().apply {
                        put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                        put(MediaStore.Downloads.MIME_TYPE, mimeType)
                        put(MediaStore.Downloads.IS_PENDING, 1)
                    }
                    val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
                    val uri = contentResolver.insert(collection, values)
                        ?: throw Exception("Failed to create MediaStore entry")
                    contentResolver.openOutputStream(uri)!!.use { out ->
                        File(tempPath).inputStream().use { it.copyTo(out) }
                    }
                    values.clear()
                    values.put(MediaStore.Downloads.IS_PENDING, 0)
                    contentResolver.update(uri, values, null, null)
                    runOnUiThread { result.success(uri.toString()) }
                } catch (e: Exception) {
                    runOnUiThread { result.error("SAVE_ERROR", e.message, null) }
                }
            }.start()
        } else {
            // API < 29: direct copy, requires WRITE_EXTERNAL_STORAGE at runtime
            if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.WRITE_EXTERNAL_STORAGE)
                == PackageManager.PERMISSION_GRANTED) {
                doLegacyCopy(tempPath, fileName, result)
            } else {
                pendingResult = result
                pendingTempPath = tempPath
                pendingFileName = fileName
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(android.Manifest.permission.WRITE_EXTERNAL_STORAGE),
                    REQUEST_WRITE_PERMISSION,
                )
            }
        }
    }

    private fun doLegacyCopy(tempPath: String, fileName: String, result: MethodChannel.Result) {
        Thread {
            try {
                val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                downloadsDir.mkdirs()
                val dest = File(downloadsDir, fileName)
                File(tempPath).copyTo(dest, overwrite = true)
                runOnUiThread { result.success(dest.absolutePath) }
            } catch (e: Exception) {
                runOnUiThread { result.error("SAVE_ERROR", e.message, null) }
            }
        }.start()
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration,
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        pipChannel?.invokeMethod("onPipChanged", isInPictureInPictureMode)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_WRITE_PERMISSION) {
            val res = pendingResult ?: return
            val path = pendingTempPath ?: return
            val name = pendingFileName ?: return
            pendingResult = null
            pendingTempPath = null
            pendingFileName = null
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                doLegacyCopy(path, name, res)
            } else {
                res.error("PERMISSION_DENIED", "Storage permission denied", null)
            }
        }
    }
}
