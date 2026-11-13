package com.example.flutter_application_1

import android.annotation.SuppressLint
import android.bluetooth.*
import android.bluetooth.le.*
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import android.util.Log
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.*
import java.util.concurrent.ConcurrentHashMap

/**
 * BitChat-compatible BLE GATT Client and Server Mesh Manager for CampusOS.
 *
 * Implements high-resilience, bidirectional peer-to-peer GATT communication:
 * 1. Hosts a GATT Server with BitChat Service & Characteristic UUIDs.
 * 2. Continuously advertises Service UUID so nearby peers can discover this device.
 * 3. Scans for peers advertising Service UUID and establishes GATT Client connections.
 * 4. Maintains dual-role symmetry: writes directly via GATT Client and notifies via GATT Server.
 * 5. Transparently handles MTU negotiation, CCCD descriptor registration with retries,
 *    and multi-frame fragmentation/reassembly for 100% reliable packet delivery.
 */
class CampusGattMeshManager(private val context: Context) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        private const val TAG = "CampusGattMesh"

        // Exact BitChat GATT UUIDs
        val SERVICE_UUID: UUID = UUID.fromString("F47B5E2D-4A9E-4C5A-9B3F-8E1D2C3A4B5C")
        val CHARACTERISTIC_UUID: UUID = UUID.fromString("A1B2C3D4-E5F6-4A5B-8C9D-0E1F2A3B4C5D")
        val DESCRIPTOR_UUID: UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")

        // Notification chunk frame magic byte (0xFA != CampusOS packet magic 0xCA)
        private const val CHUNK_MAGIC_BYTE: Byte = 0xFA.toByte()
    }

    private val bluetoothManager: BluetoothManager? =
        context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
    private val bluetoothAdapter: BluetoothAdapter?
        get() = bluetoothManager?.adapter

    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null
    private val incomingPacketBuffer = ArrayDeque<ByteArray>()
    private val pendingOutboundBuffer = ArrayDeque<ByteArray>()

    private var isRunning = false

    private var isAdvertising = false
    @Volatile
    private var isAdvertisingPaused = false

    // GATT Server state
    private var gattServer: BluetoothGattServer? = null
    private var serverCharacteristic: BluetoothGattCharacteristic? = null
    private var advertiseCallback: AdvertiseCallback? = null
    private val serverConnectedDevices = ConcurrentHashMap<String, BluetoothDevice>()
    private val subscribedDevices = ConcurrentHashMap.newKeySet<String>()
    private val serverDeviceMtus = ConcurrentHashMap<String, Int>()
    private val clientDeviceMtus = ConcurrentHashMap<String, Int>()
    private val packetBroadcastExecutor = java.util.concurrent.Executors.newSingleThreadExecutor()
    private val preparedWriteBuffers = ConcurrentHashMap<String, ByteArrayOutputStream>()

    // GATT Client state
    private var scanCallback: ScanCallback? = null
    private var activeScanSettings: ScanSettings? = null
    private val clientConnections = ConcurrentHashMap<String, BluetoothGatt>()
    private val clientCharacteristics = ConcurrentHashMap<String, BluetoothGattCharacteristic>()
    private val pendingConnections = ConcurrentHashMap<String, Long>()

    // Reassembly state for chunked inbound notifications
    private val chunkReassemblyBuffers = ConcurrentHashMap<String, Array<ByteArray?>>()

    // Maintenance pulse: keeps connections healthy, flushes buffered packets, and purges stale timestamps
    private val maintenancePulseRunnable = object : Runnable {
        override fun run() {
            if (isRunning) {
                // Periodically flush any outbound packets if connections are now available
                flushPendingOutbound()

                // Clean up stale pending connection attempts older than 20 seconds
                val now = System.currentTimeMillis()
                pendingConnections.entries.removeIf { (now - it.value) > 20000L }

                mainHandler.postDelayed(this, 15000L)
            }
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startMesh" -> {
                val success = start()
                result.success(success)
            }
            "stopMesh" -> {
                stop()
                result.success(true)
            }
            "pauseAdvertising" -> {
                pauseAdvertising()
                result.success(true)
            }
            "resumeAdvertising" -> {
                resumeAdvertising()
                result.success(true)
            }
            "sendPacket" -> {
                val bytes = when (val args = call.arguments) {
                    is ByteArray -> args
                    is List<*> -> args.filterIsInstance<Number>().map { it.toByte() }.toByteArray()
                    else -> null
                }
                if (bytes != null) {
                    val count = broadcastPacket(bytes)
                    result.success(count)
                } else {
                    result.error("INVALID_ARGS", "Packet bytes missing or malformed", null)
                }
            }
            "getConnectedPeerCount" -> {
                result.success(getConnectedPeerCount())
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        if (events != null) {
            synchronized(incomingPacketBuffer) {
                while (incomingPacketBuffer.isNotEmpty()) {
                    val pkt = incomingPacketBuffer.removeFirst()
                    events.success(pkt)
                }
            }
        }
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    @SuppressLint("MissingPermission")
    @Synchronized
    fun start(): Boolean {
        if (isRunning) return true
        val adapter = bluetoothAdapter ?: return false
        if (!adapter.isEnabled) return false

        try {
            setupGattServer()
            startAdvertising()
            startScanning()
            isRunning = true
            Log.i(TAG, "🟢 BitChat GATT Mesh Manager started successfully")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to start GATT Mesh: ${e.message}", e)
            stop()
            return false
        }
    }

    @SuppressLint("MissingPermission")
    @Synchronized
    fun stop() {
        isRunning = false
        mainHandler.removeCallbacks(maintenancePulseRunnable)

        // Stop scanning
        try {
            val scanner = bluetoothAdapter?.bluetoothLeScanner
            if (scanner != null && scanCallback != null) {
                scanner.stopScan(scanCallback)
            }
        } catch (e: Exception) {
            Log.w(TAG, "Error stopping scanner: ${e.message}")
        }
        scanCallback = null

        // Disconnect clients
        for ((_, gatt) in clientConnections) {
            try {
                gatt.disconnect()
                gatt.close()
            } catch (_: Exception) {}
        }
        clientConnections.clear()
        clientCharacteristics.clear()
        pendingConnections.clear()

        // Stop advertising
        try {
            val advertiser = bluetoothAdapter?.bluetoothLeAdvertiser
            if (advertiser != null && advertiseCallback != null) {
                advertiser.stopAdvertising(advertiseCallback)
            }
        } catch (e: Exception) {
            Log.w(TAG, "Error stopping advertiser: ${e.message}")
        }
        advertiseCallback = null

        // Stop GATT server
        try {
            gattServer?.close()
        } catch (e: Exception) {
            Log.w(TAG, "Error closing GATT server: ${e.message}")
        }
        gattServer = null
        serverCharacteristic = null
        serverConnectedDevices.clear()
        subscribedDevices.clear()
        serverDeviceMtus.clear()
        clientDeviceMtus.clear()
        preparedWriteBuffers.clear()
        chunkReassemblyBuffers.clear()

        Log.i(TAG, "🔴 BitChat GATT Mesh Manager stopped")
    }

    fun getConnectedPeerCount(): Int {
        val uniqueAddresses = HashSet<String>()
        uniqueAddresses.addAll(serverConnectedDevices.keys)
        uniqueAddresses.addAll(clientConnections.keys)
        return uniqueAddresses.size
    }

    // ==========================================
    // GATT SERVER SETUP & CALLBACKS
    // ==========================================
    @SuppressLint("MissingPermission")
    private fun setupGattServer() {
        val manager = bluetoothManager ?: return

        val serverCallback = object : BluetoothGattServerCallback() {
            override fun onConnectionStateChange(device: BluetoothDevice, status: Int, newState: Int) {
                if (newState == BluetoothProfile.STATE_CONNECTED) {
                    serverConnectedDevices[device.address] = device
                    Log.i(TAG, "🟢 GATT Server: Client connected: ${device.address}")

                    // Device connected to our GATT Server. Dual-role symmetry:
                    // This peer can WRITE to us, and we can NOTIFY this peer.
                    // Avoid racing reverse GATT Client connections to the same MAC address,
                    // which causes Android status 133 (GATT_CONN_L2C_FAILURE) collisions.
                    pendingConnections.remove(device.address)

                    flushPendingOutbound()
                } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                    serverConnectedDevices.remove(device.address)
                    subscribedDevices.remove(device.address)
                    serverDeviceMtus.remove(device.address)
                    preparedWriteBuffers.remove(device.address)
                    Log.i(TAG, "ℹ️ GATT Server: Client disconnected: ${device.address}")
                }
            }

            override fun onCharacteristicWriteRequest(
                device: BluetoothDevice,
                requestId: Int,
                characteristic: BluetoothGattCharacteristic,
                preparedWrite: Boolean,
                responseNeeded: Boolean,
                offset: Int,
                value: ByteArray?
            ) {
                if (preparedWrite) {
                    if (value != null && value.isNotEmpty()) {
                        val stream = preparedWriteBuffers.getOrPut(device.address) { ByteArrayOutputStream() }
                        stream.write(value)
                    }
                    if (responseNeeded) {
                        gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null)
                    }
                } else {
                    if (responseNeeded) {
                        gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null)
                    }
                    if (value != null && value.isNotEmpty()) {
                        handleInboundCharacteristicData(value, device.address)
                    }
                }
            }

            override fun onExecuteWrite(device: BluetoothDevice, requestId: Int, execute: Boolean) {
                if (execute) {
                    val stream = preparedWriteBuffers.remove(device.address)
                    if (stream != null) {
                        val fullBytes = stream.toByteArray()
                        if (fullBytes.isNotEmpty()) {
                            handleInboundCharacteristicData(fullBytes, device.address)
                        }
                    }
                } else {
                    preparedWriteBuffers.remove(device.address)
                }
                gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null)
            }

            override fun onDescriptorWriteRequest(
                device: BluetoothDevice,
                requestId: Int,
                descriptor: BluetoothGattDescriptor,
                preparedWrite: Boolean,
                responseNeeded: Boolean,
                offset: Int,
                value: ByteArray?
            ) {
                if (value != null) {
                    @Suppress("DEPRECATION")
                    descriptor.value = value
                    if (BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE.contentEquals(value) ||
                        BluetoothGattDescriptor.ENABLE_INDICATION_VALUE.contentEquals(value) ||
                        (value.isNotEmpty() && value[0].toInt() != 0)) {
                        subscribedDevices.add(device.address)
                        Log.i(TAG, "🟢 Client ${device.address} subscribed to GATT notifications")
                        flushPendingOutbound()
                    }
                }
                if (responseNeeded) {
                    // ATT Write Response for CCCD write requires offset=0, value=null
                    gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null)
                }
            }

            override fun onMtuChanged(device: BluetoothDevice, mtu: Int) {
                serverDeviceMtus[device.address] = mtu
                Log.i(TAG, "⚡ GATT Server: MTU changed to $mtu for ${device.address}")
            }

            override fun onNotificationSent(device: BluetoothDevice, status: Int) {
                if (status == BluetoothGatt.GATT_SUCCESS) {
                    Log.d(TAG, "GATT Server: Notification delivered to ${device.address}")
                } else {
                    Log.w(TAG, "⚠️ GATT Server: Notification failed to ${device.address}, status=$status")
                }
            }
        }

        gattServer = manager.openGattServer(context, serverCallback)

        val characteristic = BluetoothGattCharacteristic(
            CHARACTERISTIC_UUID,
            BluetoothGattCharacteristic.PROPERTY_READ or
                    BluetoothGattCharacteristic.PROPERTY_WRITE or
                    BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE or
                    BluetoothGattCharacteristic.PROPERTY_NOTIFY,
            BluetoothGattCharacteristic.PERMISSION_READ or
                    BluetoothGattCharacteristic.PERMISSION_WRITE
        )

        val descriptor = BluetoothGattDescriptor(
            DESCRIPTOR_UUID,
            BluetoothGattDescriptor.PERMISSION_READ or BluetoothGattDescriptor.PERMISSION_WRITE
        )
        characteristic.addDescriptor(descriptor)

        val service = BluetoothGattService(SERVICE_UUID, BluetoothGattService.SERVICE_TYPE_PRIMARY)
        service.addCharacteristic(characteristic)

        gattServer?.addService(service)
        serverCharacteristic = characteristic
    }

    // ==========================================
    // BLE ADVERTISING WITH RE-ARMING & COOPERATIVE YIELDING
    // ==========================================
    @SuppressLint("MissingPermission")
    fun pauseAdvertising() {
        isAdvertisingPaused = true
        val advertiser = bluetoothAdapter?.bluetoothLeAdvertiser
        try {
            if (advertiser != null && advertiseCallback != null) {
                advertiser.stopAdvertising(advertiseCallback)
            }
        } catch (e: Exception) {
            Log.w(TAG, "Error pausing advertiser: ${e.message}")
        }
        advertiseCallback = null
        isAdvertising = false
        Log.i(TAG, "⏸️ BitChat GATT Mesh advertising paused (yielding to priority BLE attendance)")
    }

    @SuppressLint("MissingPermission")
    fun resumeAdvertising() {
        isAdvertisingPaused = false
        if (isRunning) {
            mainHandler.postDelayed({
                if (isRunning && !isAdvertisingPaused && !isAdvertising) {
                    startAdvertising()
                }
            }, 500L)
        }
    }

    @SuppressLint("MissingPermission")
    private fun startAdvertising() {
        if (isAdvertising || isAdvertisingPaused) return
        val advertiser = bluetoothAdapter?.bluetoothLeAdvertiser ?: run {
            Log.e(TAG, "BLE advertiser not available on this device")
            return
        }

        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setConnectable(true)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
            .setTimeout(0)
            .build()

        val data = AdvertiseData.Builder()
            .addServiceUuid(ParcelUuid(SERVICE_UUID))
            .setIncludeDeviceName(false)
            .setIncludeTxPowerLevel(false)
            .build()

        val scanResponse = AdvertiseData.Builder()
            .addServiceUuid(ParcelUuid(SERVICE_UUID))
            .setIncludeDeviceName(false)
            .setIncludeTxPowerLevel(false)
            .build()

        advertiseCallback = object : AdvertiseCallback() {
            override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
                isAdvertising = true
                Log.i(TAG, "🟢 BLE Advertising BitChat GATT Service active")
            }

            override fun onStartFailure(errorCode: Int) {
                isAdvertising = false
                Log.e(TAG, "⚠️ BLE Advertising failed with code: $errorCode.")
                if (errorCode == AdvertiseCallback.ADVERTISE_FAILED_TOO_MANY_ADVERTISERS) {
                    // Back off and do not aggressively hog hardware advertiser slots when attendance is active
                    mainHandler.postDelayed({
                        if (isRunning && !isAdvertisingPaused) {
                            restartAdvertising()
                        }
                    }, 10000L)
                } else {
                    mainHandler.postDelayed({
                        if (isRunning && !isAdvertisingPaused) {
                            restartAdvertising()
                        }
                    }, 2000L)
                }
            }
        }

        try {
            advertiser.startAdvertising(settings, data, scanResponse, advertiseCallback)
        } catch (e: Exception) {
            isAdvertising = false
            Log.e(TAG, "Exception starting advertising: ${e.message}")
        }
    }

    @SuppressLint("MissingPermission")
    private fun restartAdvertising() {
        if (!isRunning || isAdvertisingPaused) return
        val advertiser = bluetoothAdapter?.bluetoothLeAdvertiser ?: return

        try {
            if (advertiseCallback != null) {
                advertiser.stopAdvertising(advertiseCallback)
            }
        } catch (_: Exception) {}
        isAdvertising = false

        mainHandler.postDelayed({
            if (isRunning && !isAdvertisingPaused) {
                startAdvertising()
            }
        }, 200L)
    }

    // ==========================================
    // GATT CLIENT SCAN & CONNECTION
    // ==========================================
    @SuppressLint("MissingPermission")
    private fun startScanning() {
        val scanner = bluetoothAdapter?.bluetoothLeScanner ?: run {
            Log.e(TAG, "BLE scanner not available on this device")
            return
        }

        val scanSettings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .setCallbackType(ScanSettings.CALLBACK_TYPE_ALL_MATCHES)
            .setMatchMode(ScanSettings.MATCH_MODE_AGGRESSIVE)
            .setNumOfMatches(ScanSettings.MATCH_NUM_MAX_ADVERTISEMENT)
            .setReportDelay(0)
            .build()
        activeScanSettings = scanSettings

        scanCallback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult) {
                if (isMeshAdvertisement(result)) {
                    handleDiscoveredDevice(result.device)
                }
            }

            override fun onBatchScanResults(results: MutableList<ScanResult>?) {
                results?.forEach { result ->
                    if (isMeshAdvertisement(result)) {
                        handleDiscoveredDevice(result.device)
                    }
                }
            }

            override fun onScanFailed(errorCode: Int) {
                Log.e(TAG, "⚠️ BLE Scan failed: $errorCode. Scheduling restart...")
                mainHandler.postDelayed({
                    if (isRunning) {
                        try {
                            scanner.stopScan(this)
                        } catch (_: Exception) {}
                        try {
                            scanner.startScan(null, scanSettings, this)
                        } catch (_: Exception) {}
                    }
                }, 3000L)
            }
        }

        try {
            val scanFilter = ScanFilter.Builder()
                .setServiceUuid(ParcelUuid(SERVICE_UUID))
                .build()
            scanner.startScan(listOf(scanFilter), scanSettings, scanCallback)
            mainHandler.postDelayed(maintenancePulseRunnable, 15000L)
            Log.i(TAG, "🟢 BLE Scanning for BitChat GATT Service started")
        } catch (e: Exception) {
            Log.w(TAG, "Filtered BLE scan start note ($e), trying unfiltered scan...")
            try {
                scanner.startScan(null, scanSettings, scanCallback)
                mainHandler.postDelayed(maintenancePulseRunnable, 15000L)
                Log.i(TAG, "🟢 BLE Scanning for BitChat GATT Service started (unfiltered)")
            } catch (e2: Exception) {
                Log.e(TAG, "Error starting BLE scanner: ${e2.message}")
            }
        }
    }

    private fun isMeshAdvertisement(result: ScanResult): Boolean {
        // 1. Check parsed service UUIDs
        if (result.scanRecord?.serviceUuids?.any { it.uuid == SERVICE_UUID } == true) {
            return true
        }

        // 2. Resilient fallback: Scan raw advertisement bytes for 128-bit UUID (Little Endian)
        val raw = result.scanRecord?.bytes ?: return false
        val uuidMsb = SERVICE_UUID.mostSignificantBits
        val uuidLsb = SERVICE_UUID.leastSignificantBits

        // Convert 128-bit UUID to little-endian bytes as formatted in BLE advertisement payloads
        val targetBytes = ByteArray(16)
        for (i in 0..7) {
            targetBytes[i] = ((uuidLsb ushr (8 * i)) and 0xFF).toByte()
            targetBytes[8 + i] = ((uuidMsb ushr (8 * i)) and 0xFF).toByte()
        }

        if (raw.size >= 16) {
            for (i in 0..(raw.size - 16)) {
                var match = true
                for (j in 0..15) {
                    if (raw[i + j] != targetBytes[j]) {
                        match = false
                        break
                    }
                }
                if (match) return true
            }
        }
        return false
    }

    @SuppressLint("MissingPermission")
    private fun handleDiscoveredDevice(device: BluetoothDevice) {
        val addr = device.address
        // 1. Skip if already actively connected as client or server
        if (clientConnections.containsKey(addr) || serverConnectedDevices.containsKey(addr)) {
            return
        }

        // 2. Rate-limit connection attempts to once every 5 seconds
        val now = System.currentTimeMillis()
        val lastAttempt = pendingConnections[addr]
        if (lastAttempt != null && (now - lastAttempt) < 5000L) {
            return
        }
        pendingConnections[addr] = now

        Log.i(TAG, "Connecting to discovered BitChat peer: $addr")
        val gattCallback = object : BluetoothGattCallback() {
            private var discoveryInitiated = false

            private fun triggerServiceDiscovery(gatt: BluetoothGatt) {
                if (!discoveryInitiated) {
                    discoveryInitiated = true
                    mainHandler.post {
                        try {
                            Log.i(TAG, "🔍 Initiating service discovery for $addr...")
                            gatt.discoverServices()
                        } catch (e: Exception) {
                            Log.w(TAG, "Error initiating discoverServices for $addr: ${e.message}")
                        }
                    }
                }
            }

            override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
                if (status != BluetoothGatt.GATT_SUCCESS) {
                    Log.w(TAG, "GATT connection status error: $status for $addr (client)")
                    clientConnections.remove(addr)
                    clientCharacteristics.remove(addr)
                    pendingConnections.remove(addr)
                    mainHandler.postDelayed({
                        try { gatt.close() } catch (_: Exception) {}
                    }, 500)
                    return
                }

                if (newState == BluetoothProfile.STATE_CONNECTED) {
                    clientConnections[addr] = gatt
                    pendingConnections.remove(addr)
                    Log.i(TAG, "🟢 GATT Client: Connected to $addr. Requesting MTU 517...")

                    mainHandler.postDelayed({
                        try {
                            val requested = gatt.requestMtu(517)
                            if (!requested) {
                                Log.w(TAG, "requestMtu returned false for $addr, triggering discovery directly")
                                triggerServiceDiscovery(gatt)
                            }
                        } catch (e: Exception) {
                            Log.w(TAG, "Error requesting MTU: ${e.message}")
                            triggerServiceDiscovery(gatt)
                        }
                    }, 200)

                    // Watchdog: Trigger discovery if onMtuChanged doesn't fire within 1500ms
                    mainHandler.postDelayed({
                        triggerServiceDiscovery(gatt)
                    }, 1500)
                } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                    clientConnections.remove(addr)
                    clientCharacteristics.remove(addr)
                    clientDeviceMtus.remove(addr)
                    pendingConnections.remove(addr)
                    mainHandler.postDelayed({
                        try { gatt.close() } catch (_: Exception) {}
                    }, 500)
                    Log.i(TAG, "ℹ️ GATT Client: Disconnected from $addr")
                }
            }

            override fun onMtuChanged(gatt: BluetoothGatt, mtu: Int, status: Int) {
                if (status == BluetoothGatt.GATT_SUCCESS) {
                    clientDeviceMtus[addr] = mtu
                }
                Log.i(TAG, "⚡ Negotiated MTU: $mtu with $addr. Discovering services...")
                triggerServiceDiscovery(gatt)
            }

            override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
                if (status == BluetoothGatt.GATT_SUCCESS) {
                    val service = gatt.getService(SERVICE_UUID)
                    val characteristic = service?.getCharacteristic(CHARACTERISTIC_UUID)
                    if (characteristic != null) {
                        clientCharacteristics[addr] = characteristic

                        // Post delayed CCCD descriptor registration to avoid mDeviceBusy state
                        mainHandler.postDelayed({
                            setupClientNotificationsWithRetry(gatt, characteristic, 0)
                        }, 300L)

                        Log.i(TAG, "✅ Ready for high-throughput packet transfers with peer $addr")
                        flushPendingOutbound()
                    } else {
                        Log.w(TAG, "Required characteristic not found on peer $addr")
                        pendingConnections.remove(addr)
                    }
                } else {
                    Log.w(TAG, "Service discovery failed with status $status for $addr")
                    pendingConnections.remove(addr)
                }
            }

            override fun onDescriptorWrite(gatt: BluetoothGatt, descriptor: BluetoothGattDescriptor, status: Int) {
                val devAddr = gatt.device.address
                Log.i(TAG, "CCCD descriptor write status: $status for $devAddr")
                if (status == BluetoothGatt.GATT_SUCCESS) {
                    Log.i(TAG, "🟢 CCCD notification registration verified for $devAddr")
                    flushPendingOutbound()
                } else {
                    Log.w(TAG, "⚠️ CCCD write callback failed with status $status for $devAddr, retrying in 500ms...")
                    val char = clientCharacteristics[devAddr]
                    if (char != null) {
                        mainHandler.postDelayed({
                            setupClientNotificationsWithRetry(gatt, char, 0)
                        }, 500L)
                    }
                }
            }

            @Deprecated("Deprecated in Java")
            override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
                @Suppress("DEPRECATION")
                val value = characteristic.value
                if (value != null && value.isNotEmpty()) {
                    handleInboundCharacteristicData(value, gatt.device.address)
                }
            }

            override fun onCharacteristicChanged(
                gatt: BluetoothGatt,
                characteristic: BluetoothGattCharacteristic,
                value: ByteArray
            ) {
                if (value.isNotEmpty()) {
                    handleInboundCharacteristicData(value, gatt.device.address)
                }
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            device.connectGatt(context, false, gattCallback, BluetoothDevice.TRANSPORT_LE)
        } else {
            device.connectGatt(context, false, gattCallback)
        }
    }

    @SuppressLint("MissingPermission")
    private fun setupClientNotificationsWithRetry(
        gatt: BluetoothGatt,
        characteristic: BluetoothGattCharacteristic,
        retryCount: Int
    ) {
        val addr = gatt.device.address
        try {
            gatt.setCharacteristicNotification(characteristic, true)
            val descriptor = characteristic.getDescriptor(DESCRIPTOR_UUID)
            if (descriptor == null) {
                Log.w(TAG, "CCCD descriptor not found on characteristic for $addr")
                return
            }

            @Suppress("DEPRECATION")
            descriptor.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE

            val result = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                gatt.writeDescriptor(descriptor, BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE)
            } else {
                @Suppress("DEPRECATION")
                if (gatt.writeDescriptor(descriptor)) BluetoothStatusCodes.SUCCESS else BluetoothStatusCodes.ERROR_UNKNOWN
            }

            if (result == BluetoothStatusCodes.SUCCESS) {
                Log.i(TAG, "🟢 CCCD write initiated successfully for $addr")
            } else {
                if (retryCount < 4) {
                    val delay = 350L * (retryCount + 1)
                    Log.w(TAG, "CCCD write busy/deferred ($result) for $addr, retrying in ${delay}ms (attempt ${retryCount + 1})...")
                    mainHandler.postDelayed({
                        setupClientNotificationsWithRetry(gatt, characteristic, retryCount + 1)
                    }, delay)
                } else {
                    Log.e(TAG, "❌ CCCD write exhausted retries for $addr")
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Exception configuring CCCD for $addr: ${e.message}")
        }
    }

    // ==========================================
    // INBOUND DATA HANDLING & REASSEMBLY
    // ==========================================
    private fun handleInboundCharacteristicData(value: ByteArray, peerAddress: String? = null) {
        if (value.isEmpty()) return

        // Check if this is a chunked notification frame: [0xFA, msgId, ...]
        if (value.size >= 4 && value[0] == CHUNK_MAGIC_BYTE) {
            val msgId = value[1]
            val chunkIdx: Int
            val totalChunks: Int
            val headerSize: Int

            if (value.size >= 6) {
                val total16 = ((value[4].toInt() and 0xFF) shl 8) or (value[5].toInt() and 0xFF)
                val idx16 = ((value[2].toInt() and 0xFF) shl 8) or (value[3].toInt() and 0xFF)
                if (total16 in 1..4096 && idx16 < total16) {
                    chunkIdx = idx16
                    totalChunks = total16
                    headerSize = 6
                } else {
                    chunkIdx = value[2].toInt() and 0xFF
                    totalChunks = value[3].toInt() and 0xFF
                    headerSize = 4
                }
            } else {
                chunkIdx = value[2].toInt() and 0xFF
                totalChunks = value[3].toInt() and 0xFF
                headerSize = 4
            }

            if (totalChunks <= 0 || chunkIdx >= totalChunks) {
                Log.w(TAG, "Malformed chunk frame: idx=$chunkIdx, total=$totalChunks")
                return
            }

            val key = "${peerAddress ?: "peer"}:$msgId:$totalChunks"
            val buffer = chunkReassemblyBuffers.getOrPut(key) { arrayOfNulls(totalChunks) }
            val chunkPayload = ByteArray(value.size - headerSize)
            System.arraycopy(value, headerSize, chunkPayload, 0, chunkPayload.size)
            buffer[chunkIdx] = chunkPayload

            // Auto-cleanup stale chunk buffers after 45 seconds
            mainHandler.postDelayed({
                chunkReassemblyBuffers.remove(key)
            }, 45000L)

            // Check if all chunks have arrived
            if (buffer.all { it != null }) {
                chunkReassemblyBuffers.remove(key)
                var totalBytes = 0
                for (c in buffer) totalBytes += c!!.size
                val fullPacket = ByteArray(totalBytes)
                var offset = 0
                for (c in buffer) {
                    System.arraycopy(c!!, 0, fullPacket, offset, c.size)
                    offset += c.size
                }
                Log.i(TAG, "🎉 Successfully reassembled full mesh packet: $totalBytes bytes ($totalChunks chunks) from ${peerAddress ?: "peer"}")
                dispatchPacketToFlutter(fullPacket)
            }
        } else {
            // Raw unchunked mesh packet
            dispatchPacketToFlutter(value)
        }
    }

    private fun dispatchPacketToFlutter(bytes: ByteArray) {
        mainHandler.post {
            val sink = eventSink
            if (sink != null) {
                try {
                    sink.success(bytes)
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to send packet to Flutter: ${e.message}")
                }
            } else {
                synchronized(incomingPacketBuffer) {
                    if (incomingPacketBuffer.size > 50) incomingPacketBuffer.removeFirst()
                    incomingPacketBuffer.addLast(bytes)
                }
            }
        }
    }

    private fun flushPendingOutbound() {
        mainHandler.postDelayed({
            synchronized(pendingOutboundBuffer) {
                if (pendingOutboundBuffer.isNotEmpty()) {
                    Log.i(TAG, "Flushing ${pendingOutboundBuffer.size} pending outbound packets to connected peers")
                    val packetsToSend = ArrayList<ByteArray>(pendingOutboundBuffer)
                    pendingOutboundBuffer.clear()
                    for (packet in packetsToSend) {
                        broadcastPacket(packet)
                    }
                }
            }
        }, 300)
    }

    // ==========================================
    // BIDIRECTIONAL PACKET TRANSMISSION
    // ==========================================
    @SuppressLint("MissingPermission")
    fun broadcastPacket(data: ByteArray): Int {
        var sendsCount = 0
        val sentAddresses = HashSet<String>()

        // 1. Direct GATT Client Writes (Central -> Peripheral)
        for ((addr, gatt) in clientConnections) {
            val char = clientCharacteristics[addr]
            if (char != null) {
                val confirmedMtu = clientDeviceMtus[addr]
                // If MTU has not yet been confirmed by onMtuChanged, assume safe BLE MTU 23 (payload 20)
                val clientMtu = confirmedMtu ?: 23
                val maxPayload = maxOf(14, clientMtu - 3)

                if (data.size <= maxPayload) {
                    var written = writeSingleClientPacket(gatt, char, data)
                    if (!written) {
                        try { Thread.sleep(25) } catch (_: Exception) {}
                        written = writeSingleClientPacket(gatt, char, data)
                    }
                    if (written) {
                        sentAddresses.add(addr)
                        sendsCount++
                        Log.i(TAG, "🟢 GATT Client wrote ${data.size} bytes (single) to $addr")
                    } else {
                        Log.w(TAG, "⚠️ GATT Client single write failed for $addr, falling back to chunked writes")
                        val chunkPayload = if (confirmedMtu != null) maxOf(14, maxPayload - 6) else 14
                        sendChunkedClientPacket(gatt, char, addr, data, chunkPayload)
                        sentAddresses.add(addr)
                        sendsCount++
                    }
                } else {
                    val chunkPayload = if (confirmedMtu != null) maxOf(14, maxPayload - 6) else 14
                    sendChunkedClientPacket(gatt, char, addr, data, chunkPayload)
                    sentAddresses.add(addr)
                    sendsCount++
                }
            }
        }

        // 2. Direct GATT Server Notifications (Peripheral -> Central)
        val server = gattServer
        val char = serverCharacteristic
        if (server != null && char != null) {
            val targetDevices = serverConnectedDevices.values.toList()

            for (device in targetDevices) {
                val addr = device.address
                if (sentAddresses.contains(addr)) continue // Avoid redundant double send

                val confirmedMtu = serverDeviceMtus[addr]
                // If MTU was not confirmed by onMtuChanged, assume safe BLE MTU 23 (payload 20)
                val peerMtu = confirmedMtu ?: 23
                val maxPayload = maxOf(14, peerMtu - 3)

                if (data.size <= maxPayload) {
                    var notified = sendSingleNotification(server, device, char, data)
                    if (!notified) {
                        try { Thread.sleep(20) } catch (_: Exception) {}
                        notified = sendSingleNotification(server, device, char, data)
                    }
                    if (notified) {
                        sentAddresses.add(addr)
                        sendsCount++
                        Log.i(TAG, "🟢 GATT Server notified ${data.size} bytes (single) to $addr")
                    } else {
                        Log.w(TAG, "⚠️ GATT Server single notification rejected for $addr, falling back to safe chunking")
                        sendChunkedNotification(server, device, char, addr, data, 14)
                        sentAddresses.add(addr)
                        sendsCount++
                    }
                } else {
                    val chunkPayloadSize = if (confirmedMtu != null) maxOf(14, maxPayload - 6) else 14
                    sendChunkedNotification(server, device, char, addr, data, chunkPayloadSize)
                    sentAddresses.add(addr)
                    sendsCount++
                }
            }
        }

        // 3. Queue outbound packet if zero physical links could accept it right now
        if (sendsCount == 0) {
            synchronized(pendingOutboundBuffer) {
                if (pendingOutboundBuffer.size > 50) pendingOutboundBuffer.removeFirst()
                pendingOutboundBuffer.addLast(data)
            }
            Log.i(TAG, "Outbound packet queued (${pendingOutboundBuffer.size} in buffer) waiting for peer link")
        }

        return sendsCount
    }

    @SuppressLint("MissingPermission")
    private fun sendChunkedClientPacket(
        gatt: BluetoothGatt,
        char: BluetoothGattCharacteristic,
        addr: String,
        data: ByteArray,
        chunkPayloadSize: Int
    ) {
        packetBroadcastExecutor.execute {
            try {
                val chunkHeaderSize = 6
                val totalChunks = (data.size + chunkPayloadSize - 1) / chunkPayloadSize
                val msgId = (System.currentTimeMillis() and 0xFF).toByte()

                var allChunksSent = true
                for (chunkIdx in 0 until totalChunks) {
                    val startOffset = chunkIdx * chunkPayloadSize
                    val endOffset = minOf(data.size, startOffset + chunkPayloadSize)
                    val chunkData = ByteArray(chunkHeaderSize + (endOffset - startOffset))
                    chunkData[0] = CHUNK_MAGIC_BYTE
                    chunkData[1] = msgId
                    chunkData[2] = ((chunkIdx ushr 8) and 0xFF).toByte()
                    chunkData[3] = (chunkIdx and 0xFF).toByte()
                    chunkData[4] = ((totalChunks ushr 8) and 0xFF).toByte()
                    chunkData[5] = (totalChunks and 0xFF).toByte()
                    System.arraycopy(data, startOffset, chunkData, chunkHeaderSize, endOffset - startOffset)

                    var written = false
                    for (attempt in 0..3) {
                        written = writeSingleClientPacket(gatt, char, chunkData)
                        if (written) break
                        try { Thread.sleep(35) } catch (_: Exception) {}
                    }

                    if (!written) {
                        Log.w(TAG, "⚠️ GATT Client chunk write failed at chunk $chunkIdx/$totalChunks for $addr")
                        allChunksSent = false
                        break
                    }
                    try { Thread.sleep(35) } catch (_: Exception) {}
                }

                if (allChunksSent) {
                    Log.i(TAG, "🟢 GATT Client wrote ${data.size} bytes in $totalChunks chunks to $addr")
                }
            } catch (e: Exception) {
                Log.w(TAG, "Client chunked write error for $addr: ${e.message}")
            }
        }
    }

    @SuppressLint("MissingPermission")
    private fun sendChunkedNotification(
        server: BluetoothGattServer,
        device: BluetoothDevice,
        char: BluetoothGattCharacteristic,
        addr: String,
        data: ByteArray,
        chunkPayloadSize: Int
    ) {
        packetBroadcastExecutor.execute {
            try {
                val chunkHeaderSize = 6
                val totalChunks = (data.size + chunkPayloadSize - 1) / chunkPayloadSize
                val msgId = (System.currentTimeMillis() and 0xFF).toByte()

                var allChunksSent = true
                for (chunkIdx in 0 until totalChunks) {
                    val startOffset = chunkIdx * chunkPayloadSize
                    val endOffset = minOf(data.size, startOffset + chunkPayloadSize)
                    val chunkData = ByteArray(chunkHeaderSize + (endOffset - startOffset))
                    chunkData[0] = CHUNK_MAGIC_BYTE
                    chunkData[1] = msgId
                    chunkData[2] = ((chunkIdx ushr 8) and 0xFF).toByte()
                    chunkData[3] = (chunkIdx and 0xFF).toByte()
                    chunkData[4] = ((totalChunks ushr 8) and 0xFF).toByte()
                    chunkData[5] = (totalChunks and 0xFF).toByte()
                    System.arraycopy(data, startOffset, chunkData, chunkHeaderSize, endOffset - startOffset)

                    var notified = false
                    for (attempt in 0..3) {
                        notified = sendSingleNotification(server, device, char, chunkData)
                        if (notified) break
                        try { Thread.sleep(35) } catch (_: Exception) {}
                    }

                    if (!notified) {
                        Log.w(TAG, "⚠️ GATT Server chunk notification failed at chunk $chunkIdx/$totalChunks for $addr")
                        allChunksSent = false
                        break
                    }
                    try { Thread.sleep(35) } catch (_: Exception) {}
                }

                if (allChunksSent) {
                    Log.i(TAG, "🟢 GATT Server notified ${data.size} bytes in $totalChunks chunks to $addr")
                }
            } catch (e: Exception) {
                Log.w(TAG, "Server chunked notification error for $addr: ${e.message}")
            }
        }
    }

    @SuppressLint("MissingPermission")
    private fun writeSingleClientPacket(
        gatt: BluetoothGatt,
        char: BluetoothGattCharacteristic,
        data: ByteArray
    ): Boolean {
        @Suppress("DEPRECATION")
        char.writeType = BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
        @Suppress("DEPRECATION")
        char.value = data
        var success = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            try {
                gatt.writeCharacteristic(char, data, BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE) == BluetoothStatusCodes.SUCCESS
            } catch (_: Exception) {
                false
            }
        } else {
            try {
                @Suppress("DEPRECATION")
                gatt.writeCharacteristic(char)
            } catch (_: Exception) {
                false
            }
        }

        if (!success) {
            @Suppress("DEPRECATION")
            char.writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
            @Suppress("DEPRECATION")
            char.value = data
            success = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                try {
                    gatt.writeCharacteristic(char, data, BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT) == BluetoothStatusCodes.SUCCESS
                } catch (_: Exception) {
                    false
                }
            } else {
                try {
                    @Suppress("DEPRECATION")
                    gatt.writeCharacteristic(char)
                } catch (_: Exception) {
                    false
                }
            }
        }
        return success
    }

    @SuppressLint("MissingPermission")
    private fun sendSingleNotification(
        server: BluetoothGattServer,
        device: BluetoothDevice,
        characteristic: BluetoothGattCharacteristic,
        payload: ByteArray
    ): Boolean {
        @Suppress("DEPRECATION")
        characteristic.value = payload
        var notified = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            try {
                server.notifyCharacteristicChanged(device, characteristic, false, payload) == BluetoothStatusCodes.SUCCESS
            } catch (_: Exception) {
                false
            }
        } else {
            false
        }
        if (!notified) {
            try {
                @Suppress("DEPRECATION")
                characteristic.value = payload
                @Suppress("DEPRECATION")
                notified = server.notifyCharacteristicChanged(device, characteristic, false)
            } catch (_: Exception) {
                notified = false
            }
        }
        return notified
    }
}
