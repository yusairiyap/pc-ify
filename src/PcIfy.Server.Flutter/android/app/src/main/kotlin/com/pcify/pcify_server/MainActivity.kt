package com.pcify.pcify_server

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioManager
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.os.Environment
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*

class MainActivity : FlutterActivity() {
    private val permissionsChannel = "com.pcify.pcify_server/permissions"
    private val sysControlChannel = "com.pcify.pcify_server/system_control"

    // CPU measurement state
    private var lastCpuIdle: Long = 0
    private var lastCpuTotal: Long = 0
    private var cachedCpuUsage: Double = 0.0
    private val cpuScope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Existing permissions channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, permissionsChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasManageStoragePermission" -> {
                        result.success(
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R)
                                Environment.isExternalStorageManager()
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
                    else -> result.notImplemented()
                }
            }

        // Start background CPU sampling
        startCpuSampling()

        // System control channel
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
                    "lockScreen" -> {
                        val lockResult = lockScreen()
                        if (lockResult == null) result.success(null)
                        else result.error(lockResult, "Device admin not active", null)
                    }
                    "wakeScreen" -> {
                        wakeScreen()
                        result.success(null)
                    }
                    "getNotifications" -> result.success(getNotifications())
                    "clearNotifications" -> {
                        clearNotifications()
                        result.success(null)
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
            "screen" to mapOf("locked" to false, "available" to isAccessibilityServiceEnabled())
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

    private fun isAccessibilityServiceEnabled(): Boolean {
        val service = "$packageName/${PcIfyAccessibilityService::class.java.name}"
        val enabled = Settings.Secure.getString(
            contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        return enabled.split(':').any { it.equals(service, ignoreCase = true) }
    }

    // Returns null on success, or an error code string
    private fun lockScreen(): String? {
        if (!isAccessibilityServiceEnabled()) return "needs_accessibility_service"
        return if (PcIfyAccessibilityService.lockScreen()) null else "lock_failed"
    }

    private fun wakeScreen() {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        val wl = pm.newWakeLock(
            PowerManager.FULL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP or PowerManager.ON_AFTER_RELEASE,
            "pcify:wakelock"
        )
        wl.acquire(500)
        wl.release()
    }

    private fun getNotifications(): Map<String, Any> {
        val store = NotificationCollectorService.NotificationStore
        if (!store.isConnected) return mapOf("available" to false, "items" to emptyList<Any>())
        val items = store.notifications.map { n ->
            mapOf(
                "id" to n.key,
                "title" to (n.notification.extras?.getString(android.app.Notification.EXTRA_TITLE) ?: ""),
                "text" to (n.notification.extras?.getString(android.app.Notification.EXTRA_TEXT) ?: ""),
                "appName" to getAppName(n.packageName),
                "timestamp" to n.notification.`when`
            )
        }
        return mapOf("available" to true, "items" to items)
    }

    private fun clearNotifications() {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.cancelAll()
        NotificationCollectorService.NotificationStore.clearAll()
    }

    private fun getAppName(packageName: String): String {
        return try {
            val info = packageManager.getApplicationInfo(packageName, 0)
            packageManager.getApplicationLabel(info).toString()
        } catch (_: Exception) { packageName }
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
        // Try /proc/stat (may be restricted on Android 9+)
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
                // Validate: dt must be positive and idle delta in range
                if (dt > 0 && di in 0..dt) {
                    return (dt - di).toDouble() / dt * 100.0
                }
            }
        } catch (_: Exception) {}
        // Fallback: use CPU frequency as a proxy for load
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
