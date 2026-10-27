import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'native_perf_monitor_platform_interface.dart';

/// An implementation of [NativePerfMonitorPlatform] that uses method channels.
class MethodChannelNativePerfMonitor extends NativePerfMonitorPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('native_perf_monitor');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
