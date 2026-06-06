package com.pcify.pcify_server

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioManager
import android.os.BatteryManager
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import android.net.Uri

class MainActivity : FlutterActivity() {
    private val permissionsChannel = "com.pcify.pcify_server/permissions"
    private val sysControlChannel = "com.pcify.pcify_server/system_control"

    // CPU measurement state
    private var cachedCpuUsage: Double = 0.0
    private val cpuScope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, permissionsChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasManageStoragePermission" -> {
                        result.success(
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R)
                                android.os.Environment.isExternalStorageManager()
                            else true
                        )
                    }
                    "requestManageStoragePermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                                Uri.parse("package:$packageName")
                            )
                            startActivity(intent)
                        }
                        result.success(null)
                    }
                    "openAppSettings" -> {
                        // Deep-link to this app's system settings page so the user can
                        // reach OEM "Autostart" / "Battery" / "Notifications" screens.
                        // There is no standard API for the per-OEM autostart toggles.
                        val intent = Intent(
                            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            Uri.parse("package:$packageName")
                        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        startCpuSampling()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, sysControlChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getStatus" -> result.success(getStatus())
                    "setVolume" -> {
                        val level = call.argument<Int>("level") ?: 50
                        setVolume(level)
                        result.success(null)
                    }
                    "setMute" -> {
                        val muted = call.argument<Boolean>("muted") ?: false
                        setMute(muted)
                        result.success(null)
                    }
                    "lockScreen" -> result.error("unavailable", "Screen lock not supported on Android", null)
                    "wakeScreen" -> {
                        wakeScreen()
                        result.success(null)
                    }
                    "getVideoDurationMs" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.success(0L)
                        } else {
                            val mmr = android.media.MediaMetadataRetriever()
                            try {
                                mmr.setDataSource(path)
                                val ms = mmr.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L
                                result.success(ms)
                            } catch (e: Exception) {
                                result.success(0L)
                            } finally {
                                mmr.release()
                            }
                        }
                    }
                    "getVideoThumbnail" -> {
                        val path = call.argument<String>("path")
                        val quality = call.argument<Int>("quality") ?: 75
                        val atSeconds = call.argument<Double>("atSeconds") ?: 2.0
                        if (path == null) {
                            result.success(null)
                        } else {
                            val mmr = android.media.MediaMetadataRetriever()
                            try {
                                mmr.setDataSource(path)
                                val atMicros = (atSeconds * 1_000_000).toLong()
                                val bitmap = mmr.getFrameAtTime(atMicros, android.media.MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                                if (bitmap != null) {
                                    val bos = java.io.ByteArrayOutputStream()
                                    bitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG, quality.coerceIn(1, 100), bos)
                                    result.success(bos.toByteArray())
                                } else {
                                    result.success(null)
                                }
                            } catch (e: Exception) {
                                result.success(null)
                            } finally {
                                mmr.release()
                            }
                        }
                    }
                    "getDeviceName" -> {
                        val manufacturer = Build.MANUFACTURER
                            .replaceFirstChar { if (it.isLowerCase()) it.titlecase() else it.toString() }
                        val model = Build.MODEL
                        val name = if (model.startsWith(manufacturer, ignoreCase = true)) model
                                   else "$manufacturer $model"
                        result.success(name)
                    }
                    "getOsDisplayName" -> {
                        result.success("Android ${Build.VERSION.RELEASE}")
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        cpuScope.cancel()
        super.onDestroy()
    }

    private fun getStatus(): Map<String, Any> {
        // Battery
        val batteryIntent = applicationContext.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val level = batteryIntent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = batteryIntent?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
        val status = batteryIntent?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
        val batteryPct = if (level >= 0 && scale > 0) (level * 100 / scale) else 0
        val charging = status == BatteryManager.BATTERY_STATUS_CHARGING || status == BatteryManager.BATTERY_STATUS_FULL

        // Volume
        val audioMgr = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val maxVol = audioMgr.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        val curVol = audioMgr.getStreamVolume(AudioManager.STREAM_MUSIC)
        val volPct = if (maxVol > 0) (curVol * 100 / maxVol) else 0
        val muted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
            audioMgr.isStreamMute(AudioManager.STREAM_MUSIC)
        else curVol == 0

        // RAM
        val actMgr = getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
        val memInfo = android.app.ActivityManager.MemoryInfo()
        actMgr.getMemoryInfo(memInfo)
        val totalMb = (memInfo.totalMem / (1024 * 1024)).toInt()
        val usedMb = ((memInfo.totalMem - memInfo.availMem) / (1024 * 1024)).toInt()

        return mapOf(
            "battery" to mapOf("level" to batteryPct, "charging" to charging, "available" to true),
            "volume" to mapOf("level" to volPct, "muted" to muted, "available" to true),
            "cpu" to mapOf("usage" to cachedCpuUsage, "available" to true),
            "ram" to mapOf("usedMb" to usedMb, "totalMb" to totalMb, "available" to true),
            "screen" to mapOf("locked" to false, "available" to false)
        )
    }

    private fun setVolume(percent: Int) {
        val audioMgr = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val maxVol = audioMgr.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        val target = (percent.coerceIn(0, 100) * maxVol / 100)
        audioMgr.setStreamVolume(AudioManager.STREAM_MUSIC, target, 0)
    }

    private fun setMute(muted: Boolean) {
        val audioMgr = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            audioMgr.adjustStreamVolume(
                AudioManager.STREAM_MUSIC,
                if (muted) AudioManager.ADJUST_MUTE else AudioManager.ADJUST_UNMUTE,
                0
            )
        }
    }

    private fun wakeScreen() {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        @Suppress("DEPRECATION")
        val wl = pm.newWakeLock(
            PowerManager.FULL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP or PowerManager.ON_AFTER_RELEASE,
            "pcify:wakelock"
        )
        wl.acquire(500)
        wl.release()
    }

    private fun startCpuSampling() {
        cpuScope.launch {
            while (isActive) {
                cachedCpuUsage = measureCpuUsage()
                delay(2000)
            }
        }
    }

    private suspend fun measureCpuUsage(): Double {
        try {
            val line1 = java.io.File("/proc/stat").bufferedReader().use { it.readLine() }
            val parts1 = line1.trim().split("\\s+".toRegex()).drop(1).mapNotNull { it.toLongOrNull() }
            if (parts1.isNotEmpty()) {
                val total1 = parts1.sum()
                val idle1 = parts1.getOrElse(3) { 0L }
                delay(500)
                val line2 = java.io.File("/proc/stat").bufferedReader().use { it.readLine() }
                val parts2 = line2.trim().split("\\s+".toRegex()).drop(1).mapNotNull { it.toLongOrNull() }
                val total2 = parts2.sum()
                val idle2 = parts2.getOrElse(3) { 0L }
                val dt = total2 - total1
                val di = idle2 - idle1
                if (dt > 0 && di in 0..dt) {
                    return (dt - di).toDouble() / dt * 100.0
                }
            }
        } catch (_: Exception) {}
        return readCpuFromFrequency()
    }

    private fun readCpuFromFrequency(): Double {
        var totalPct = 0.0
        var count = 0
        for (i in 0 until Runtime.getRuntime().availableProcessors()) {
            try {
                val cur = java.io.File("/sys/devices/system/cpu/cpu$i/cpufreq/scaling_cur_freq")
                    .readText().trim().toLong()
                val max = java.io.File("/sys/devices/system/cpu/cpu$i/cpufreq/scaling_max_freq")
                    .readText().trim().toLong()
                if (max > 0) {
                    totalPct += cur.toDouble() / max * 100.0
                    count++
                }
            } catch (_: Exception) {}
        }
        return if (count > 0) totalPct / count else 0.0
    }
}
