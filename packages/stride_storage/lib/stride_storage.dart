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

/// The cross-**isolate** serialization design.
///
/// `src/file_lock.dart` covers two cases: a second OS process, through the
/// kernel, and a second acquirer inside one isolate, through the mutex it takes
/// before opening the lock file. It cannot cover a second **isolate** — on
/// POSIX an OS lock is owned by the process, and Dart copies `static` state per
/// isolate — and an owner isolate is the shape that would.
///
/// **Nothing outside this package uses it.** The app builds a plain
/// `SaveRepository` in `lib/runtime/runtime_bootstrap.dart`, and that is
/// currently sound because the app has exactly one isolate touching the save
/// directory. This is therefore a tested design rather than a deployed control,
/// and it must not be cited as one. `TECHNICAL/PERSISTENCE_CONCURRENCY.md`
/// records the three things that would have to change to wire it, and the
/// recommendation attached to them.
export 'src/persistence_owner.dart';
