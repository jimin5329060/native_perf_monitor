import Flutter
import UIKit

public class NativePerfMonitorPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    /// 事件通道出口，Dart 订阅之后才有值
    private var eventSink:FlutterEventSink?
    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var displayLink:CADisplayLink?
    /// 上一帧的 vsync 时刻（秒）
    private var lastFrameTs:CFTimeInterval = 0
    /// 判定阈值：间隔达到帧预算 2 倍 = 至少掉一帧
    private let jankRatio = 2.0
    /// 取消上一轮没跑完的卡顿任务
    private var jankGeneration = 0
    
    
    public static func register(with registrar: FlutterPluginRegistrar) {
      let instance = NativePerfMonitorPlugin()
      // 通道名必须和 Dart 侧完全一致，否则收不到
      let channel = FlutterMethodChannel(name: "native_perf_monitor", binaryMessenger: registrar.messenger())
      let events = FlutterEventChannel(name: "native_perf_monitor/events", binaryMessenger:registrar.messenger())
        
      // 转存到实例上，detach 时才能清 handler
      instance.methodChannel = channel
      instance.eventChannel = events
        
      registrar.addMethodCallDelegate(instance, channel: channel)
      events.setStreamHandler(instance)
      registrar.publish(instance)// ← 没有这行 detach 永远不会被调用
   }
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
      switch call.method {
      case "ping":
        let input = (call.arguments as? [String: Any])?["input"] as? String ?? ""
        result("\(input) from ios")
      case "getPlatformVersion":
        result("iOS " + UIDevice.current.systemVersion)
      case "simulateJank":
          let args = call.arguments as?[String:Any]
          let ms = args?["ms"] as? Int ?? 80
          let times = args?["times"] as? Int ?? 1
          let intervalMs = args?["intervalMs"] as? Int ?? 300
          startJank(blockMs: ms, times: times, intervalMs: intervalMs)
          // 立刻返回，不阻塞通道；真正的卡顿在下一轮主线程消息里
          result("blocked \(ms)ms x \(times)")
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        startDisplayLink()
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        stopDisplayLink()
        eventSink = nil
        return nil
    }
    
   
    
    private func startDisplayLink(){
        stopDisplayLink()
        let link = CADisplayLink(target: self, selector: #selector(onFrame(_:)))
        // 必须 .common：滚动/手势/转场时 RunLoop 切 tracking mode，
        // 挂 .default 会收不到回调，正好漏掉最该测的场景
        link.add(to: .main, forMode:.common)
        displayLink = link
    }
    
    private func stopDisplayLink(){
        displayLink?.invalidate()
        displayLink = nil
        lastFrameTs = 0
    }
    
    
    
    @objc private func onFrame(_ link: CADisplayLink) {
      // link.timestamp 是这一帧的 vsync 时刻，不是回调执行时刻。
      // 用 CACurrentMediaTime() 会把「回调被推迟」也算进间隔，全是误报
      let now = link.timestamp
      if lastFrameTs > 0 {
        let gap = now - lastFrameTs
        if gap > 0.5 { lastFrameTs = now; return }
        let budget = link.duration > 0 ? link.duration : 1.0 / 60.0
        if gap >= budget * jankRatio {
          let gapMs = gap * 1000
          let budgetMs = budget * 1000
          NSLog("[PerfMonitor] jank gap=%.0fms budget=%.0fms", gapMs, budgetMs)
          // 原生只测量，不聚合判断
          eventSink?([
            "gapMs": gapMs,
            "budgetMs": budgetMs,
            "ratio": gap / budget,
            "ts": Int(Date().timeIntervalSince1970 * 1000),
          ])
        }
      }
      lastFrameTs = now
    }
    

    
  private func startJank(blockMs:Int,times:Int,intervalMs:Int){
      jankGeneration+=1
      blockOnce(blockMs: blockMs, remaining: times, intervalMs: intervalMs, generation: jankGeneration)
  }
  
  private func blockOnce(blockMs: Int, remaining: Int, intervalMs: Int, generation: Int){
      guard remaining>0 else {return}
      DispatchQueue.main.async{
          // 新一轮点击来了就丢掉旧的
          guard generation == self.jankGeneration else { return }
          // 主线程 sleep，制造真实可观测的卡顿
          Thread.sleep(forTimeInterval: Double(blockMs) / 1000.0)
          guard remaining > 1 else { return }
          DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(intervalMs), execute: {
              self.blockOnce(blockMs: blockMs, remaining: remaining-1, intervalMs: intervalMs, generation: generation)
          })
      }
  }
    
  public func detachFromEngine(for registrar:FlutterPluginRegistrar){
     stopDisplayLink()
     eventSink = nil
     jankGeneration+=1
     methodChannel?.setMethodCallHandler(nil)
     eventChannel?.setStreamHandler(nil)
  }
    
}
