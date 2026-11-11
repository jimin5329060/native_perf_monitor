package com.jimin.native_perf_monitor

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import android.os.Handler
import android.os.Looper
/** NativePerfMonitorPlugin */
class NativePerfMonitorPlugin :
    FlutterPlugin,
    MethodCallHandler {
    // The MethodChannel that will the communication between Flutter and native Android
    //
    // This local reference serves to register the plugin with the Flutter Engine and unregister it
    // when the Flutter Engine is detached from the Activity
    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private val handler = Handler(Looper.getMainLooper())
    private var ticker: Runnable? = null
    private var eventSink: EventChannel.EventSink? = null
    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "native_perf_monitor")
        channel.setMethodCallHandler(this)
        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "native_perf_monitor/events")
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                startTicking()
            }
            override fun onCancel(arguments: Any?) {
                stopTicking()
                eventSink = null
            }
        })
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result
    ) {
        when (call.method) {
            "getPlatformVersion" -> result.success("Android ${android.os.Build.VERSION.RELEASE}")
            "ping" -> {
                val input = call.argument<String>("input")
                result.success("$input from android")
            }
            else -> result.notImplemented()
        }
    }

    private fun startTicking() {
        stopTicking()
        ticker = object : Runnable {
            override fun run() {
                eventSink?.success(
                    mapOf(
                        "gapMs" to (16..200).random(),
                        "ts" to System.currentTimeMillis(),
                    )
                )
                handler.postDelayed(this, 1000L)
            }
        }
        handler.post(ticker!!)
    }

    private fun stopTicking() {
        ticker?.let { handler.removeCallbacks(it) }
        ticker = null
    }


    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        stopTicking()
        eventSink = null
        eventChannel.setStreamHandler(null)
    }
}
