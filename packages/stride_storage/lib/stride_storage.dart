/// Device-local persistence for Project Stride.
///
/// Concrete `dart:io` adapters for the pure-Dart ports in `stride_core`.
///
/// The reusable conformance suite every implementation of those ports must pass
/// lives at `package:stride_storage/conformance.dart` — a separate entry point,
/// because it imports `package:test` and the app must be able to depend on the
/// adapters without dragging a test framework into a release build.
///
/// No Flutter. Everything here runs under `dart test` against a real temporary
/// directory, which is what makes filesystem behaviour verifiable from a
/// Windows development machine with no emulator and no device.
library;

export 'src/file_lock.dart';
export 'src/file_storage.dart';
