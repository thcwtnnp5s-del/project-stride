/// Device-local persistence for Project Stride.
///
/// Concrete `dart:io` adapters for the pure-Dart ports in `stride_core`, plus
/// the reusable conformance suite that any implementation of those ports must
/// pass.
///
/// No Flutter. Everything here runs under `dart test` against a real temporary
/// directory, which is what makes filesystem behaviour verifiable from a
/// Windows development machine with no emulator and no device.
library;

export 'src/file_storage.dart';
