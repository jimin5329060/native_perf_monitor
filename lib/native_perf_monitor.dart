import 'native_perf_monitor_platform_interface.dart';

class NativePerfMonitor {
  Future<String?> ping(String input) {
    return NativePerfMonitorPlatform.instance.ping(input);
  }

  Stream<dynamic> events() {
    return NativePerfMonitorPlatform.instance.events();
  }

  /// 在主线程制造卡顿，仅用于验证监控逻辑。
  Future<String?> simulateJank({
    int ms = 80,
    int times = 1,
    int intervalMs = 300,
  }) {
    return NativePerfMonitorPlatform.instance.simulateJank(
      ms: ms,
      times: times,
      intervalMs: intervalMs,
    );
  }
}
