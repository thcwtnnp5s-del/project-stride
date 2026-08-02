/// Module metadata and the architectural rule this package is built around.
class StrideCore {
  StrideCore._();

  /// Version of the core simulation module.
  ///
  /// Distinct from the app's version and from the save schema version that
  /// arrives with `SaveEnvelope` in F-05. Bumped when simulation rules change
  /// in a way that affects outcomes.
  static const String version = '0.1.0';

  /// Imports that must never appear under `lib/` in this package.
  ///
  /// Declared here so the rule is discoverable from inside the package it
  /// governs, and read by both enforcement points so the rule and its guards
  /// cannot drift apart.
  ///
  /// `dart:io` is on the list deliberately: the core touches neither the file
  /// system nor the clock. Persistence goes through the `SaveStore` port, and
  /// time enters only as data on ingestion records.
  ///
  /// See DECISIONS/0010_CROSS_PLATFORM_STACK.md.
  static const List<String> forbiddenImports = <String>[
    'package:flutter/',
    'package:flutter_test/',
    'package:stride_health/',
    'dart:ui',
    'dart:io',
    'dart:isolate',
    'dart:mirrors',
  ];
}
