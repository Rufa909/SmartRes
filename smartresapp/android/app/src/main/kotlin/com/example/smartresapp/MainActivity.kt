package com.example.smartresapp

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Handler
import android.os.Looper

class MainActivity : FlutterActivity() {
    private var tone: ToneGenerator? = null
    private val handler = Handler(Looper.getMainLooper())
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ThermalReceiptPrinter.register(this, flutterEngine.dartExecutor.binaryMessenger)
        val prefs = getSharedPreferences("staff_alerts", MODE_PRIVATE)
        volumeControlStream = AudioManager.STREAM_NOTIFICATION
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "smartres/ready_alert").setMethodCallHandler { call, result ->
            when (call.method) {
                "enabled" -> result.success(prefs.getBoolean("enabled", true))
                "setEnabled" -> {
                    prefs.edit().putBoolean("enabled", call.arguments as Boolean).apply()
                    result.success(null)
                }
                "play" -> {
                    try {
                        handler.removeCallbacksAndMessages(null)
                        tone?.release()
                        val player = ToneGenerator(AudioManager.STREAM_NOTIFICATION, 100)
                        tone = player
                        val started = player.startTone(ToneGenerator.TONE_PROP_ACK, 350)
                        handler.postDelayed({ player.startTone(ToneGenerator.TONE_PROP_ACK, 350) }, 550)
                        handler.postDelayed({ player.startTone(ToneGenerator.TONE_PROP_ACK, 350) }, 1100)
                        handler.postDelayed({ player.release(); if (tone === player) tone = null }, 1600)
                        result.success(started)
                    } catch (e: RuntimeException) { result.error("AUDIO", "Không phát được âm báo", null) }
                }
                else -> result.notImplemented()
            }
        }
    }
    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        tone?.release()
        tone = null
        super.onDestroy()
    }
}
