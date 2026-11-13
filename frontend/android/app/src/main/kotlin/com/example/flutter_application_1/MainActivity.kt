package com.example.flutter_application_1

import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiManager
import android.net.wifi.WifiNetworkSpecifier
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
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
    private val HOTSPOT_CHANNEL = "campusos/hotspot"
    private val EMERGENCY_SIREN_CHANNEL = "campusos/emergency_siren"

    private var meshManager: CampusGattMeshManager? = null
    private var sirenEngine: EmergencySirenEngine? = null
    private var hotspotReservation: Any? = null
    private var wifiNetworkCallback: ConnectivityManager.NetworkCallback? = null

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
        sirenEngine?.stopSiren()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            (hotspotReservation as? WifiManager.LocalOnlyHotspotReservation)?.close()
            hotspotReservation = null
        }
        try {
            val connectivityManager = applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            wifiNetworkCallback?.let {
                connectivityManager?.unregisterNetworkCallback(it)
                wifiNetworkCallback = null
            }
        } catch (_: Exception) {}
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val manager = CampusGattMeshManager(applicationContext)
        meshManager = manager

        val emergencySiren = EmergencySirenEngine(applicationContext)
        sirenEngine = emergencySiren

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MESH_CHANNEL)
            .setMethodCallHandler(manager)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, MESH_EVENT_CHANNEL)
            .setStreamHandler(manager)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, EMERGENCY_SIREN_CHANNEL)
            .setMethodCallHandler(emergencySiren)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, HOTSPOT_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startLocalOnlyHotspot" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
                        if (wifiManager == null) {
                            result.error("UNAVAILABLE", "WifiManager not available", null)
                            return@setMethodCallHandler
                        }

                        try {
                            wifiManager.startLocalOnlyHotspot(object : WifiManager.LocalOnlyHotspotCallback() {
                                override fun onStarted(reservation: WifiManager.LocalOnlyHotspotReservation) {
                                    hotspotReservation = reservation
                                    var ssid = ""
                                    var password = ""

                                    try {
                                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                                            val config = reservation.softApConfiguration
                                            ssid = config.ssid ?: ""
                                            password = config.passphrase ?: ""
                                        } else {
                                            @Suppress("DEPRECATION")
                                            val config = reservation.wifiConfiguration
                                            ssid = config?.SSID ?: ""
                                            password = config?.preSharedKey ?: ""
                                        }
                                    } catch (_: Exception) {}

                                    result.success(mapOf(
                                        "success" to true,
                                        "ssid" to ssid,
                                        "password" to password,
                                        "isLocalOnly" to true
                                    ))
                                }

                                override fun onStopped() {
                                    hotspotReservation = null
                                }

                                override fun onFailed(reason: Int) {
                                    hotspotReservation = null
                                    val msg = when (reason) {
                                        1 -> "Wi-Fi radio busy or disabled. Please enable Wi-Fi in phone settings."
                                        2 -> "Location (GPS) is OFF or device does not support auto-hotspot. Please enable Location in phone settings."
                                        3 -> "Hotspot is already in use by another app or system."
                                        4 -> "Carrier does not allow auto-hotspot tethering."
                                        else -> "Hotspot failed with code $reason"
                                    }
                                    result.error("FAILED", msg, null)
                                }
                            }, Handler(Looper.getMainLooper()))
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    } else {
                        result.error("UNSUPPORTED", "LocalOnlyHotspot requires Android 8.0+", null)
                    }
                }
                "stopLocalOnlyHotspot" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        try {
                            (hotspotReservation as? WifiManager.LocalOnlyHotspotReservation)?.close()
                            hotspotReservation = null
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    } else {
                        result.success(true)
                    }
                }
                "connectToWifi" -> {
                    val ssid = call.argument<String>("ssid") ?: ""
                    val password = call.argument<String>("password") ?: ""
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        val connectivityManager = applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
                        if (connectivityManager != null && ssid.isNotEmpty()) {
                            try {
                                val specifier = WifiNetworkSpecifier.Builder()
                                    .setSsid(ssid)
                                    .setWpa2Passphrase(password)
                                    .build()
                                val request = NetworkRequest.Builder()
                                    .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
                                    .removeCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                                    .setNetworkSpecifier(specifier)
                                    .build()

                                wifiNetworkCallback?.let {
                                    try { connectivityManager.unregisterNetworkCallback(it) } catch (_: Exception) {}
                                }

                                val callback = object : ConnectivityManager.NetworkCallback() {
                                    override fun onAvailable(network: Network) {
                                        try {
                                            connectivityManager.bindProcessToNetwork(network)
                                        } catch (_: Exception) {}
                                        result.success(true)
                                    }
                                    override fun onUnavailable() {
                                        result.success(false)
                                    }
                                }
                                wifiNetworkCallback = callback
                                connectivityManager.requestNetwork(request, callback)
                                return@setMethodCallHandler
                            } catch (e: Exception) {
                                result.error("ERROR", e.message, null)
                                return@setMethodCallHandler
                            }
                        }
                    }
                    result.success(false)
                }
                "disconnectWifi" -> {
                    try {
                        val connectivityManager = applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
                        wifiNetworkCallback?.let {
                            connectivityManager?.unregisterNetworkCallback(it)
                            wifiNetworkCallback = null
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            connectivityManager?.bindProcessToNetwork(null)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "openHotspotSettings" -> {
                    try {
                        val intent = Intent()
                        intent.action = "android.settings.TETHER_SETTINGS"
                        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val intent = Intent(android.provider.Settings.ACTION_WIRELESS_SETTINGS)
                            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            startActivity(intent)
                            result.success(true)
                        } catch (e2: Exception) {
                            result.error("ERROR", e2.message, null)
                        }
                    }
                }
                "isHotspotSupported" -> {
                    result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                }
                else -> result.notImplemented()
            }
        }

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
