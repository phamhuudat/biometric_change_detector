import 'package:biometric_change_detector/biometric_change_detector.dart';
import 'package:flutter/material.dart';

void main() => runApp(const MaterialApp(home: DemoPage()));

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  final _detector = BiometricChangeDetector.instance;
  final _keyId = TextEditingController(text: 'demo');
  final _log = <String>[];

  Future<void> _run(String label, Future<Object?> Function() action) async {
    String line;
    try {
      final value = await action();
      line =
          '$label → ${value is BiometricChangeStatus ? value.name : value ?? 'done'}';
    } on BiometricChangeException catch (e) {
      line = '$label → ${e.code}: ${e.message ?? ''}';
    } on ArgumentError catch (e) {
      line = '$label → ${e.message}';
    }
    if (!mounted) return;
    final time = TimeOfDay.now().format(context);
    setState(() => _log.insert(0, '[$time] $line'));
  }

  @override
  void dispose() {
    _keyId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyId = _keyId.text;
    return Scaffold(
      appBar: AppBar(title: const Text('Biometric change detector')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _keyId,
            decoration: const InputDecoration(labelText: 'keyId'),
            onChanged: (_) => setState(() {}),
          ),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                onPressed: () => _run('enroll', () => _detector.enroll(keyId)),
                child: const Text('Enroll'),
              ),
              FilledButton(
                onPressed: () => _run('check', () => _detector.check(keyId)),
                child: const Text('Check'),
              ),
              OutlinedButton(
                onPressed: () =>
                    _run('isEnrolled', () => _detector.isEnrolled(keyId)),
                child: const Text('Is enrolled'),
              ),
              OutlinedButton(
                onPressed: () => _run('remove', () => _detector.remove(keyId)),
                child: const Text('Remove'),
              ),
              OutlinedButton(
                onPressed: () => _run('removeAll', _detector.removeAll),
                child: const Text('Remove all'),
              ),
            ],
          ),
          const Divider(height: 32),
          for (final line in _log)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                line,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
        ],
      ),
    );
  }
}
