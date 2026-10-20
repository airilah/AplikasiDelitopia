package com.delitopia.delitopia_v2

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    companion object {
        private const val FCM_CACHE_CHANNEL = "com.delitopia.aplikasi/fcm_cache"
        private const val FCM_PREFERENCES = "com.google.android.gms.appid"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            FCM_CACHE_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getCachedFcmToken" -> result.success(readNewestCachedFcmToken())
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Migration fallback for installs created before Delitopia persisted its
     * own last-known token. No token is logged or exposed outside this app.
     */
    private fun readNewestCachedFcmToken(): String? {
        val entries = getSharedPreferences(FCM_PREFERENCES, MODE_PRIVATE).all

        return entries
            .asSequence()
            .filter { (key, value) -> key.startsWith("|T|") && value is String }
            .mapNotNull { (_, value) ->
                runCatching {
                    val json = JSONObject(value as String)
                    val token = json.optString("token").trim()
                    if (token.isEmpty()) null
                    else Pair(json.optLong("timestamp", 0L), token)
                }.getOrNull()
            }
            .maxByOrNull { it.first }
            ?.second
    }
}
