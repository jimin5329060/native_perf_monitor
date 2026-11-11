import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:native_perf_monitor/native_perf_monitor.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: HomePage());
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _pingStr = 'Unknown';
  final _nativePerfMonitorPlugin = NativePerfMonitor();

  final List<Map> _rows = []; // 最近的事件
  StreamSubscription<dynamic>? _sub; // ← 关键：手动订阅，才能显式取消

  @override
  void initState() {
    super.initState();
    initPlatformState();
    _sub = _nativePerfMonitorPlugin.events().listen((event) {
      setState(() {
        _rows.insert(0, event as Map);
        if (_rows.length > 20) _rows.removeLast();
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel(); // ← 这一句会触发原生 onCancel
    super.dispose();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String pingStr;
    // Platform messages may fail, so we use a try/catch PlatformException.
    // We also handle the message potentially returning null.
    try {
      pingStr =
          await _nativePerfMonitorPlugin.ping('hello') ??
          'Unknown platform version';
    } on PlatformException {
      pingStr = 'Failed to get platform version.';
    }
    debugPrint('pingStr = $pingStr');

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _pingStr = pingStr;
    });
  }

  /// 制造卡顿：阻塞 ms 毫秒，重复 times 次，间隔 intervalMs
  Future<void> _jank(int ms, int times, int intervalMs) async {
    final r = await _nativePerfMonitorPlugin.simulateJank(
      ms: ms,
      times: times,
      intervalMs: intervalMs,
    );
    debugPrint('simulateJank -> $r');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plugin example app')),
      body: Column(
        children: [
          // ── 顶部固定区：ping 结果 + 两个按钮 + 计数
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Text('ping: $_pingStr'),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () => initPlatformState(),
                      child: const Text('重新 ping'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const Scaffold(body: Center(child: Text('第二页'))),
                        ),
                      ),
                      child: const Text('push 新页面'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(

                  children: [
                    ElevatedButton(
                      onPressed: () => _jank(80, 1, 300),
                      child: const Text('卡 80ms'),
                    ),
                    ElevatedButton(
                      onPressed: () => _jank(80, 5, 300),
                      child: const Text('连续 5 次'),
                    ),
                    ElevatedButton(
                      onPressed: () => _jank(200, 1, 300),
                      child: const Text('卡 200ms'),
                    ),
                    ElevatedButton(
                      onPressed: () => setState(_rows.clear),
                      child: const Text('清空'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('已收到 ${_rows.length} 条'),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── 列表区：每条事件一行
          Expanded(
            child: ListView.builder(
              itemCount: _rows.length,
              itemBuilder: (context, index) {
                final row = _rows[index];
                final gap = (row['gapMs'] as num?)?.toDouble() ?? 0;
                final ratio = (row['ratio'] as num?)?.toDouble() ?? 0;
                final hot = ratio >= 5;
                return ListTile(
                  dense: true,
                  leading: Text(
                    '#${_rows.length - index}',
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                  title: Text(
                    '${gap.toStringAsFixed(1)}ms  ·  ${ratio.toStringAsFixed(1)}x',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: hot ? Colors.red : Colors.orange.shade800,
                    ),
                  ),
                  subtitle: Text(_formatTs(row['ts'])),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 毫秒时间戳 → HH:mm:ss
  String _formatTs(dynamic ts) {
    if (ts is! int) return '--';
    final t = DateTime.fromMillisecondsSinceEpoch(ts);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }
}
