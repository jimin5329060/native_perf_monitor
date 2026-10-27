
import 'native_perf_monitor_platform_interface.dart';

class NativePerfMonitor {
  Future<String?> ping(String input) {
    return NativePerfMonitorPlatform.instance.ping(input);
  }
}
