/// The persistence-port conformance suite.
///
/// A **separate entry point** from `package:stride_storage/stride_storage.dart`
/// on purpose. This library imports `package:test`, and the app must be able to
/// depend on the adapters without dragging a test framework into a release
/// build. Import this one only from test files.
library;

export 'src/conformance.dart';
