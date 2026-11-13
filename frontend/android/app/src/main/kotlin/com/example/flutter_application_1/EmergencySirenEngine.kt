package com.example.flutter_application_1

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.media.ToneGenerator
import android.os.Build
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.PI
import kotlin.math.sin

/**
 * Native Android emergency siren synthesizer and haptic alarm controller.
 *
 * Uses [AudioTrack] (44.1 kHz PCM) with [ToneGenerator] fallback so sirens remain
 * audible across all Android devices during offline disasters with zero external asset dependencies.
 */
class EmergencySirenEngine(private val context: Context) : MethodChannel.MethodCallHandler {
    private val isPlaying = AtomicBoolean(false)
    private var audioThread: Thread? = null
    private var audioTrack: AudioTrack? = null
    private var activeToneGen: ToneGenerator? = null
    private var previousAlarmVolume: Int? = null
    private var previousMediaVolume: Int? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startSiren" -> {
                val pattern = call.argument<String>("pattern") ?: "wail"
                val durationSeconds = call.argument<Int>("durationSeconds") ?: 45
                val maxVolume = call.argument<Boolean>("maxVolume") ?: true
                startSiren(pattern, durationSeconds, maxVolume)
                result.success(true)
            }
            "stopSiren" -> {
                stopSiren()
                result.success(true)
            }
            "isSirenPlaying" -> {
                result.success(isPlaying.get())
            }
            else -> result.notImplemented()
        }
    }

    @Synchronized
    fun startSiren(pattern: String, durationSeconds: Int, maxVolume: Boolean) {
        stopSiren()

        val clampedDuration = durationSeconds.coerceIn(2, 180)
        isPlaying.set(true)

        if (maxVolume) {
            boostAlarmVolume()
        }
        startVibrationPattern(pattern)

        val thread = Thread {
            // Standard 44100 Hz guaranteed by every Android audio HAL
            val sampleRate = 44100
            val chunkSamples = 2048
            val minBufBytes = AudioTrack.getMinBufferSize(
                sampleRate,
                AudioFormat.CHANNEL_OUT_MONO,
                AudioFormat.ENCODING_PCM_16BIT
            ).let { if (it > 0) it else 8192 }.coerceAtLeast(chunkSamples * 4)

            var track: AudioTrack? = null

            // Try USAGE_ALARM first, fall back to USAGE_MEDIA if device firmware restricts alarm channel
            val usages = intArrayOf(AudioAttributes.USAGE_ALARM, AudioAttributes.USAGE_MEDIA)
            for (usage in usages) {
                try {
                    val candidate = AudioTrack.Builder()
                        .setAudioAttributes(
                            AudioAttributes.Builder()
                                .setUsage(usage)
                                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                                .build()
                        )
                        .setAudioFormat(
                            AudioFormat.Builder()
                                .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                                .setSampleRate(sampleRate)
                                .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                                .build()
                        )
                        .setBufferSizeInBytes(minBufBytes * 2)
                        .setTransferMode(AudioTrack.MODE_STREAM)
                        .build()

                    if (candidate.state == AudioTrack.STATE_INITIALIZED) {
                        track = candidate
                        break
                    } else {
                        candidate.release()
                    }
                } catch (e: Exception) {
                    android.util.Log.w("EmergencySiren", "AudioTrack creation with usage $usage failed: $e")
                }
            }

            if (track == null) {
                // Secondary hardware ToneGenerator fallback guaranteed on all Android phones
                playFallbackToneSiren(pattern, clampedDuration)
                return@Thread
            }

            audioTrack = track
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    track.setVolume(1.0f)
                }
                track.play()

                val buffer = ShortArray(chunkSamples)
                val totalSamples = sampleRate.toLong() * clampedDuration
                var sampleIndex = 0L
                var phase = 0.0
                var subPhase = 0.0

                while (isPlaying.get() && sampleIndex < totalSamples) {
                    for (i in 0 until chunkSamples) {
                        if (!isPlaying.get() || sampleIndex >= totalSamples) {
                            buffer[i] = 0
                            continue
                        }
                        val t = sampleIndex.toDouble() / sampleRate.toDouble()
                        val (freqHz, secondaryHz, amp) = computePatternSample(pattern, t)

                        phase += 2.0 * PI * freqHz / sampleRate
                        if (phase > 2.0 * PI) phase -= 2.0 * PI

                        var sampleVal = sin(phase)
                        if (secondaryHz > 0.0) {
                            subPhase += 2.0 * PI * secondaryHz / sampleRate
                            if (subPhase > 2.0 * PI) subPhase -= 2.0 * PI
                            sampleVal = 0.65 * sampleVal + 0.35 * sin(subPhase)
                        } else {
                            // Subtle second harmonic gives civil-defense siren clarity on phone speakers
                            sampleVal = 0.82 * sampleVal + 0.18 * sin(phase * 2.0)
                        }

                        buffer[i] = (sampleVal * amp * Short.MAX_VALUE).toInt()
                            .coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt())
                            .toShort()
                        sampleIndex++
                    }
                    track.write(buffer, 0, chunkSamples)
                }
            } catch (e: Exception) {
                android.util.Log.e("EmergencySiren", "PCM AudioTrack streaming failed, switching to ToneGenerator: $e")
                playFallbackToneSiren(pattern, clampedDuration)
            } finally {
                try {
                    track.stop()
                } catch (_: Exception) {}
                try {
                    track.release()
                } catch (_: Exception) {}
                if (audioTrack === track) {
                    audioTrack = null
                }
                isPlaying.set(false)
                stopVibration()
                restoreAlarmVolume()
            }
        }
        thread.name = "CampusOS-EmergencySiren"
        thread.isDaemon = true
        audioThread = thread
        thread.start()
    }

    private fun computePatternSample(pattern: String, t: Double): Triple<Double, Double, Double> {
        return when (pattern) {
            "yelp" -> {
                // Fast fire/evacuation sweep: 520 Hz <-> 1220 Hz at ~2.4 Hz cycle
                val cycle = (t * 2.4) % 1.0
                val tri = if (cycle < 0.5) cycle * 2.0 else (1.0 - cycle) * 2.0
                val freq = 520.0 + tri * 700.0
                Triple(freq, 0.0, 0.88)
            }
            "lockdown" -> {
                // Security klaxon dual-tone blast: 0.60s ON / 0.25s OFF
                val slot = t % 0.85
                if (slot < 0.60) {
                    Triple(390.0, 520.0, 0.90)
                } else {
                    Triple(390.0, 520.0, 0.0)
                }
            }
            "alertChime" -> {
                // Repeating triple attention chime: 880 / 660 / 987 Hz with pause
                val slot = t % 1.6
                when {
                    slot < 0.18 -> Triple(880.0, 0.0, 0.72)
                    slot < 0.26 -> Triple(880.0, 0.0, 0.0)
                    slot < 0.44 -> Triple(660.0, 0.0, 0.72)
                    slot < 0.52 -> Triple(660.0, 0.0, 0.0)
                    slot < 0.72 -> Triple(987.77, 0.0, 0.75)
                    else -> Triple(880.0, 0.0, 0.0)
                }
            }
            else -> {
                // "wail": Classic rising & falling civil defense disaster siren (3.2s cycle)
                val lfo = 0.5 - 0.5 * kotlin.math.cos(2.0 * PI * t / 3.2)
                val freq = 440.0 + lfo * 540.0
                Triple(freq, 0.0, 0.88)
            }
        }
    }

    private fun playFallbackToneSiren(pattern: String, durationSeconds: Int) {
        var toneGen: ToneGenerator? = null
        try {
            toneGen = try {
                ToneGenerator(AudioManager.STREAM_ALARM, 100)
            } catch (_: Exception) {
                ToneGenerator(AudioManager.STREAM_MUSIC, 100)
            }
            activeToneGen = toneGen
            val endTime = System.currentTimeMillis() + durationSeconds * 1000L
            while (isPlaying.get() && System.currentTimeMillis() < endTime) {
                when (pattern) {
                    "yelp" -> {
                        toneGen.startTone(ToneGenerator.TONE_CDMA_EMERGENCY_RINGBACK, 320)
                        Thread.sleep(380)
                    }
                    "lockdown" -> {
                        toneGen.startTone(ToneGenerator.TONE_CDMA_ALERT_NETWORK_LITE, 550)
                        Thread.sleep(800)
                    }
                    "alertChime" -> {
                        toneGen.startTone(ToneGenerator.TONE_PROP_BEEP, 200)
                        Thread.sleep(260)
                        toneGen.startTone(ToneGenerator.TONE_PROP_BEEP2, 300)
                        Thread.sleep(600)
                    }
                    else -> { // "wail"
                        toneGen.startTone(ToneGenerator.TONE_CDMA_EMERGENCY_RINGBACK, 650)
                        Thread.sleep(750)
                    }
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("EmergencySiren", "Fallback ToneGenerator error: $e")
        } finally {
            try {
                toneGen?.stopTone()
                toneGen?.release()
            } catch (_: Exception) {}
            if (activeToneGen === toneGen) {
                activeToneGen = null
            }
            isPlaying.set(false)
            stopVibration()
            restoreAlarmVolume()
        }
    }

    @Synchronized
    fun stopSiren() {
        isPlaying.set(false)
        try {
            audioTrack?.pause()
            audioTrack?.flush()
            audioTrack?.stop()
        } catch (_: Exception) {}
        try {
            activeToneGen?.stopTone()
            activeToneGen?.release()
            activeToneGen = null
        } catch (_: Exception) {}
        audioThread?.interrupt()
        audioThread = null
        stopVibration()
        restoreAlarmVolume()
    }

    private fun boostAlarmVolume() {
        try {
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
            
            // Boost STREAM_ALARM
            val maxVol = audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM)
            val currentVol = audioManager.getStreamVolume(AudioManager.STREAM_ALARM)
            if (previousAlarmVolume == null) {
                previousAlarmVolume = currentVol
            }
            val targetVol = (maxVol * 0.90).toInt().coerceAtLeast(1)
            if (currentVol < targetVol) {
                audioManager.setStreamVolume(AudioManager.STREAM_ALARM, targetVol, 0)
            }

            // Also ensure STREAM_MUSIC (Media) is audible in case device routes through media channel
            val maxMedia = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
            val currentMedia = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
            if (previousMediaVolume == null) {
                previousMediaVolume = currentMedia
            }
            val targetMedia = (maxMedia * 0.85).toInt().coerceAtLeast(1)
            if (currentMedia < targetMedia) {
                audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, targetMedia, 0)
            }
        } catch (e: Exception) {
            android.util.Log.w("EmergencySiren", "Could not boost volume (missing permission?): $e")
        }
    }

    private fun restoreAlarmVolume() {
        try {
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
            previousAlarmVolume?.let { audioManager.setStreamVolume(AudioManager.STREAM_ALARM, it, 0) }
            previousAlarmVolume = null
            previousMediaVolume?.let { audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, it, 0) }
            previousMediaVolume = null
        } catch (_: Exception) {}
    }

    private fun startVibrationPattern(pattern: String) {
        try {
            val vibrator = getVibrator() ?: return
            val timings = when (pattern) {
                "yelp" -> longArrayOf(0, 250, 120, 250, 120, 250, 300)
                "lockdown" -> longArrayOf(0, 600, 250, 600, 250)
                "alertChime" -> longArrayOf(0, 180, 100, 180, 600)
                else -> longArrayOf(0, 500, 200, 500, 200, 800, 400)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                val attrs = VibrationAttributes.Builder()
                    .setUsage(VibrationAttributes.USAGE_ALARM)
                    .build()
                vibrator.vibrate(VibrationEffect.createWaveform(timings, 0), attrs)
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(VibrationEffect.createWaveform(timings, 0))
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(timings, 0)
            }
        } catch (_: Exception) {}
    }

    private fun stopVibration() {
        try {
            getVibrator()?.cancel()
        } catch (_: Exception) {}
    }

    private fun getVibrator(): Vibrator? {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vm = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
                vm?.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            }
        } catch (_: Exception) {
            null
        }
    }
}
