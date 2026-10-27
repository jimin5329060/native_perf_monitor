import 'package:flutter_test/flutter_test.dart';
import 'package:native_perf_monitor/native_perf_monitor.dart';
import 'package:native_perf_monitor/native_perf_monitor_platform_interface.dart';
import 'package:native_perf_monitor/native_perf_monitor_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockNativePerfMonitorPlatform
    with MockPlatformInterfaceMixin
    implements NativePerfMonitorPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
  @override
  Future<String?> ping(String input) async => '$input from mock';
}

void main() {
  final NativePerfMonitorPlatform initialPlatform = NativePerfMonitorPlatform.instance;

  test('$MethodChannelNativePerfMonitor is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelNativePerfMonitor>());
  });

  test('ping', () async {
    NativePerfMonitor nativePerfMonitorPlugin = NativePerfMonitor();
    MockNativePerfMonitorPlatform fakePlatform = MockNativePerfMonitorPlatform();
    NativePerfMonitorPlatform.instance = fakePlatform;
    expect(await nativePerfMonitorPlugin.ping('test'), 'test from mock');
  });
}
