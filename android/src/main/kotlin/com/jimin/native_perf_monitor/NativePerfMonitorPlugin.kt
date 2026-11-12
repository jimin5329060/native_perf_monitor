package com.jimin.native_perf_monitor

import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Choreographer
import android.view.WindowManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result


class NativePerfMonitorPlugin :
    FlutterPlugin,
    MethodCallHandler {
    private var appContext: Context? = null
    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    // 帧回调必须在主线程，Choreographer 在构造时绑定当前线程的 Looper
    private val choreographer = Choreographer.getInstance()
    private var lastFrameNanos = 0L
    private var monitoring = false
    /** 判定阈值：实际间隔达到帧预算的 2 倍，等价于“至少掉了一帧” */
    private val jankRatio = 2.0

    // 卡顿模拟用：主线程队列，阻塞任务挂在它上面
    private val mainHandler = Handler(Looper.getMainLooper())
    private var jankTask: Runnable? = null

    private companion object {
        /** 拿不到刷新率时的兜底：按 60Hz 算，16.67ms */
        const val FALLBACK_BUDGET_NANOS = 16_666_667L
    }

    private val frameCallback = object : Choreographer.FrameCallback {
        override fun doFrame(frameTimeNanos: Long) {
//            Log.d("PerfMonitor", "frame $frameTimeNanos")
            if (lastFrameNanos != 0L) {
                val gapNanos = frameTimeNanos - lastFrameNanos
                if(gapNanos <= 500_000_000L){ // 连续帧才判定
                    val budgetNanos = currentFrameBudgetNanos()
                    // 原生只负责测量，不负责聚合判断
                    if (gapNanos >= budgetNanos * jankRatio) {
                        // 调试用：adb logcat -s PerfMonitor，能看出卡顿发生的精确时刻
                        Log.d(
                            "PerfMonitor",
                            "jank gap=${gapNanos / 1_000_000}ms budget=${budgetNanos / 1_000_000}ms"
                        )
                        eventSink?.success(
                            mapOf(
                                "gapMs" to gapNanos / 1_000_000.0,
                                "budgetMs" to budgetNanos / 1_000_000.0,
                                "ratio" to gapNanos.toDouble() / budgetNanos,
                                "ts" to System.currentTimeMillis(),
                            )
                        )
                    }
                }
            }
            lastFrameNanos = frameTimeNanos
            // postFrameCallback 是一次性的，必须自己续命
            if (monitoring) choreographer.postFrameCallback(this)
        }
    }

    /** 用当前屏幕刷新率换算帧预算：120Hz → 8.33ms，60Hz → 16.67ms */
    @Suppress("DEPRECATION")
    private fun currentFrameBudgetNanos(): Long {
        val wm = appContext?.getSystemService(Context.WINDOW_SERVICE) as? WindowManager
            ?: return FALLBACK_BUDGET_NANOS
        val rate = wm.defaultDisplay?.refreshRate ?: 0f
        return if (rate > 0f) (1_000_000_000.0 / rate).toLong() else FALLBACK_BUDGET_NANOS
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        appContext = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "native_perf_monitor")
        channel.setMethodCallHandler(this)
        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "native_perf_monitor/events")
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                startFrameMonitoring()
            }
            override fun onCancel(arguments: Any?) {
                eventSink = null
                stopFrameMonitoring()
            }
        })
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result
    ) {
        when (call.method) {
            "getPlatformVersion" -> result.success("Android ${Build.VERSION.RELEASE}")
            "ping" -> {
                val input = call.argument<String>("input")
                result.success("$input from android")
            }
            // 在主线程阻塞，用来制造可观测的卡顿
            "simulateJank" -> {
                val ms = call.argument<Int>("ms") ?: 80
                val times = call.argument<Int>("times") ?: 1
                val intervalMs = call.argument<Int>("intervalMs") ?: 300
                startJank(ms, times, intervalMs.toLong())
                // 立刻回，不阻塞通道；真正的卡顿在下一轮主线程消息里发生
                result.success("blocked ${ms}ms x $times")
            }
            else -> result.notImplemented()
        }
    }

    private fun startFrameMonitoring () {
        if (monitoring) return
        monitoring = true
        lastFrameNanos = 0L
        choreographer.postFrameCallback(frameCallback)
    }

    private fun stopFrameMonitoring() {
        monitoring = false
        choreographer.removeFrameCallback(frameCallback)
        lastFrameNanos = 0L
    }

    /**
     * 在主线程制造卡顿：每次阻塞 blockMs 毫秒，重复 times 次，两次之间隔 intervalMs。
     *
     * 注意：Thread.sleep 在 Android 主线程上就是真实卡顿，这是刻意的。
     * 用 postDelayed 而不是在 onMethodCall 里直接 sleep，是为了让方法立刻返回，
     * 这样 Dart 侧不会挂着一个 Future，而卡顿按自然的节奏发生。
     */
    private fun startJank(blockMs: Int, times: Int, intervalMs: Long) {
        stopJank()
        val task = object : Runnable {
            var remaining = times
            override fun run() {
                try {
                    Thread.sleep(blockMs.toLong())
                } catch (e: InterruptedException) {
                    Thread.currentThread().interrupt()
                    return
                }
                remaining--
                if (remaining > 0) mainHandler.postDelayed(this, intervalMs)
            }
        }
        jankTask = task
        mainHandler.post(task)
    }

    private fun stopJank() {
        jankTask?.let { mainHandler.removeCallbacks(it) }
        jankTask = null
    }


    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        stopFrameMonitoring()
        stopJank()
        eventSink = null
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }
}
