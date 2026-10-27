
import 'native_perf_monitor_platform_interface.dart';

class NativePerfMonitor {
  Future<String?> getPlatformVersion() {
    return NativePerfMonitorPlatform.instance.getPlatformVersion();
  }
}
