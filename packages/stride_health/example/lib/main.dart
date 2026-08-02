// Host app for stride_health platform tests.
//
// Not a demo and not a second game. This exists because a Flutter plugin's
// native halves cannot be tested in isolation without a host: Kotlin
// instrumentation tests on Android, Swift XCTest on iOS — which is what the
// macOS CI job runs.

import 'package:flutter/material.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/stride_health.dart';

void main() {
  runApp(const StrideHealthExampleApp());
}

class StrideHealthExampleApp extends StatefulWidget {
  const StrideHealthExampleApp({super.key});

  @override
  State<StrideHealthExampleApp> createState() => _StrideHealthExampleAppState();
}

class _StrideHealthExampleAppState extends State<StrideHealthExampleApp> {
  final StepProvider _provider = PlatformStepProvider();

  String _availability = 'unknown';
  String _authorization = 'not requested';

  @override
  void initState() {
    super.initState();
    _probe();
  }

  Future<void> _probe() async {
    // The adapter must never throw for an expected condition. Absence and
    // denial are normal states reported through the result, not errors.
    final bool available = await _provider.isAvailable();
    if (!mounted) return;
    setState(() => _availability = available ? 'available' : 'unavailable');
  }

  Future<void> _authorize() async {
    final StepAuthorization result = await _provider.requestAuthorization();
    if (!mounted) return;
    setState(() => _authorization = result.name);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('stride_health host')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('Health service: $_availability'),
              Text('Authorization: $_authorization'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _authorize,
                child: const Text('Request authorization'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
