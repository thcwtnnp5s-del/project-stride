// The example exists to give the plugin's Swift a host app to compile in and a
// test target to run in, exactly as stride_health's example does. It is not a
// demo, and it deliberately does not exercise the Keychain from the UI: the
// interesting behaviour is asserted in ios/RunnerTests, and a button that
// created or deleted a real identity would be a footgun on a device that also
// runs the game.

import 'package:flutter/material.dart';
import 'package:stride_secure_store/stride_secure_store.dart';

void main() {
  runApp(const SecureStoreExampleApp());
}

class SecureStoreExampleApp extends StatelessWidget {
  const SecureStoreExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Constructed, not called. Proving the plugin's Dart surface links and
    // registers is the whole job of this file.
    final SecureIdentityStore store = KeychainIdentityStore();

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('stride_secure_store')),
        body: Center(
          child: Text(
            store.isSupported
                ? 'Device-bound identity storage is available.'
                : 'No device-bound store on this platform; app-private files '
                      'are used instead.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
