import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_perf_monitor/native_perf_monitor_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelNativePerfMonitor platform = MethodChannelNativePerfMonitor();
  const MethodChannel channel = MethodChannel('native_perf_monitor');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          return '42';
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
