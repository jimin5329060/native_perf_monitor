import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'native_perf_monitor_method_channel.dart';

abstract class NativePerfMonitorPlatform extends PlatformInterface {
  /// Constructs a NativePerfMonitorPlatform.
  NativePerfMonitorPlatform() : super(token: _token);

  static final Object _token = Object();

  static NativePerfMonitorPlatform _instance = MethodChannelNativePerfMonitor();

  /// The default instance of [NativePerfMonitorPlatform] to use.
  ///
  /// Defaults to [MethodChannelNativePerfMonitor].
  static NativePerfMonitorPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [NativePerfMonitorPlatform] when
  /// they register themselves.
  static set instance(NativePerfMonitorPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<String?> ping(String input) {
    throw UnimplementedError('ping() has not been implemented.');
  }

  Stream<dynamic> events() {
    throw UnimplementedError('events() has not been implemented.');
  }

  /// 在主线程制造卡顿：阻塞 [ms] 毫秒，重复 [times] 次，间隔 [intervalMs]。
  /// 仅用于测试和演示，不要在业务代码里调用。
  Future<String?> simulateJank({
    int ms = 80,
    int times = 1,
    int intervalMs = 300,
  }) {
    throw UnimplementedError('simulateJank() has not been implemented.');
  }
}
