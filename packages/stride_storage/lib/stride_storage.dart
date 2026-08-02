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

/// The in-process serialization layer.
///
/// `src/file_lock.dart` is an OS lock, and on POSIX an OS lock is owned by the
/// *process* — so it does not exclude a second isolate inside one process.
/// Every in-process caller must reach persistence through the owner isolate
/// declared here rather than by constructing a `SaveRepository` of its own over
/// the same directory. See `TECHNICAL/PERSISTENCE_CONCURRENCY.md`.
export 'src/persistence_owner.dart';
