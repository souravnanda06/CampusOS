package com.example.flutter_application_1

import android.os.Build
import android.os.Bundle
import android.view.Display
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "campusos/performance"
    private val MESH_CHANNEL = "campusos/ble_gatt_mesh"
    private val MESH_EVENT_CHANNEL = "campusos/ble_gatt_mesh/packets"

    private var meshManager: CampusGattMeshManager? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableHighRefreshRate()
    }

    override fun onResume() {
        super.onResume()
        enableHighRefreshRate()
    }

    override fun onDestroy() {
        super.onDestroy()
        meshManager?.stop()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val manager = CampusGattMeshManager(applicationContext)
        meshManager = manager

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MESH_CHANNEL)
            .setMethodCallHandler(manager)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, MESH_EVENT_CHANNEL)
            .setStreamHandler(manager)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getDisplayCapabilities" -> {
                    try {
                        val caps = queryDisplayCapabilities()
                        result.success(caps)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "forceHighRefreshRate" -> {
                    try {
                        val rate = enableHighRefreshRate()
                        result.success(mapOf("success" to true, "targetRefreshRate" to rate))
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun queryDisplayCapabilities(): Map<String, Any> {
        var maxRate = 60.0
        var currentRate = 60.0
        val supportedRates = mutableListOf<Double>()

        try {
            val d = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                display
            } else {
                @Suppress("DEPRECATION")
                windowManager?.defaultDisplay
            }

            if (d != null) {
                currentRate = d.refreshRate.toDouble()
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    val modes = d.supportedModes
                    for (mode in modes) {
                        val r = mode.refreshRate.toDouble()
                        if (!supportedRates.contains(r)) {
                            supportedRates.add(r)
                        }
                        if (r > maxRate) {
                            maxRate = r
                        }
                    }
                }
            }
        } catch (_: Exception) {}

        if (supportedRates.isEmpty()) {
            supportedRates.add(maxRate)
        }

        return mapOf(
            "maxRefreshRate" to maxRate,
            "currentRefreshRate" to currentRate,
            "supportedRates" to supportedRates
        )
    }

    private fun enableHighRefreshRate(): Double {
        var maxRate = 60.0f
        try {
            val d = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                display
            } else {
                @Suppress("DEPRECATION")
                windowManager?.defaultDisplay
            }

            if (d != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val modes = d.supportedModes
                var maxMode: Display.Mode? = null
                for (mode in modes) {
                    if (mode.refreshRate > maxRate) {
                        maxRate = mode.refreshRate
                        maxMode = mode
                    }
                }
                if (maxMode != null) {
                    val params = window.attributes
                    params.preferredDisplayModeId = maxMode.modeId
                    @Suppress("DEPRECATION")
                    params.preferredRefreshRate = maxRate

                    // Use reflection for Android 12+ (API 31+) display refresh rate bounds
                    // to avoid compilation errors across varied compileSdk levels
                    if (Build.VERSION.SDK_INT >= 31) {
                        try {
                            params.javaClass.getField("preferredMinDisplayRefreshRate").setFloat(params, maxRate)
                            params.javaClass.getField("preferredMaxDisplayRefreshRate").setFloat(params, maxRate)
                        } catch (_: Throwable) {}
                    }
                    window.attributes = params
                }
            }
        } catch (_: Throwable) {
            // Safe fallback if device vendor locks display mode
        }
        return maxRate.toDouble()
    }
}
