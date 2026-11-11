import Flutter
import UIKit

public class NativePerfMonitorPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    /// 事件通道出口，Dart 订阅之后才有值
    private var eventSink:FlutterEventSink?
    private var displayLink:CADisplayLink?
    /// 上一帧的 vsync 时刻（秒）
    private var lastFrameTs:CFTimeInterval = 0
    /// 判定阈值：间隔达到帧预算 2 倍 = 至少掉一帧
    private let jankRatio = 2.0
    private var jankGeneration = 0
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
    
    
    
    
    
   public static func register(with registrar: FlutterPluginRegistrar) {
     let channel = FlutterMethodChannel(name: "native_perf_monitor", binaryMessenger: registrar.messenger())
     let instance = NativePerfMonitorPlugin()
     registrar.addMethodCallDelegate(instance, channel: channel)
     // 通道名必须和 Dart 侧完全一致，否则收不到
     let events = FlutterEventChannel(name: "native_perf_monitor/events", binaryMessenger:registrar.messenger())
     events.setStreamHandler(instance)
      
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
        let ms = args?["ms"] as? Int ?? 100
        let times = args?["times"] as? Int ?? 1
        let intervalMs = args?["intervalMs"] as? Int ?? 300
        // 立刻返回，不阻塞通道；真正的卡顿在下一轮主线程消息里
        result("blocked \(ms)ms x \(times)")
        
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
