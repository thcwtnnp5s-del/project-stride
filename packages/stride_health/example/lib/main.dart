// Host app for stride_health platform tests.
//
// Not a demo and not a second game. This exists because a Flutter plugin's
// native halves cannot be tested in isolation without a host: Kotlin
// instrumentation tests on Android, Swift XCTest on iOS — which is what the
// macOS CI job runs.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:stride_health/stride_health.dart';

void main() {
  runApp(const StrideHealthExampleApp());
}

/// A fixed salt, for this host app only.
///
/// The real salt is device-bound and lives in the iOS Keychain or app-private
/// Android storage, resolved by `IdentityVault` during bootstrap. This host has
/// no bootstrap and no save, so it uses a constant — which is safe precisely
/// because it never writes a ledger. **Nothing outside this host may do this:**
/// a fixed salt in the game would make every origin key reproducible on any
/// device, which is the whole property pseudonymization exists to provide.
final Uint8List _hostSalt = Uint8List.fromList(<int>[
  0x73,
  0x74,
  0x72,
  0x69,
  0x64,
  0x65,
  0x2d,
  0x68,
]);

class StrideHealthExampleApp extends StatefulWidget {
  const StrideHealthExampleApp({super.key});

  @override
  State<StrideHealthExampleApp> createState() => _StrideHealthExampleAppState();
}

class _StrideHealthExampleAppState extends State<StrideHealthExampleApp> {
  StepSyncSource? _source;

  String _availability = 'unknown';
  String _authorization = 'not requested';
  String _keying = 'not installed';

  @override
  void initState() {
    super.initState();
    _probe();
  }

  Future<void> _probe() async {
    // Keying first, and nothing works without it. `open` installs the
    // device-bound salt into the native adapter and hands back a source only if
    // the adapter accepted it — there is no unkeyed source to hold.
    final OriginKeyingInstall install = await PlatformStepSource.open(
      salt: _hostSalt,
    );
    if (!mounted) return;

    final PlatformStepSource? source = install.source;
    if (source == null) {
      setState(() => _keying = 'refused (${install.refusal?.name})');
      return;
    }
    _source = source;
    setState(() => _keying = 'installed');

    // The adapter must never throw for an expected condition. Absence and
    // denial are normal states reported through the result, not errors.
    final HealthAvailability result = await source.availability();
    if (!mounted) return;
    setState(
      () => _availability = result.available
          ? 'available'
          : 'unavailable (${result.reason?.name ?? 'no reason given'})',
    );
  }

  Future<void> _authorize() async {
    final StepSyncSource? source = _source;
    if (source == null) return;
    final HealthAuthorization result = await source.requestAuthorization();
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
              Text('Origin keying: $_keying'),
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
