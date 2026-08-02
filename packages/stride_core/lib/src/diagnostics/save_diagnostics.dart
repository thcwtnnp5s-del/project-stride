/// The only shape a save diagnostic is permitted to take.
///
/// ## Why a type rather than a convention
///
/// `DECISIONS/0012` §3 permits, after journal compaction, "minimal redacted
/// diagnostic metadata: transaction id, generation, outcome or recovery code,
/// aggregate counters, integrity result". `TECHNICAL/STEP_LEDGER_PRIVACY.md`
/// §4.1 requires that `lateDiscardedSlices` surface "in opt-in redacted
/// diagnostics only".
///
/// Both are rules about what a *string* may contain, and a string is a string.
/// The enforcement here is structural instead: every field of this class is an
/// `int` or an enum from a closed set. There is no `String` field, no
/// `Object?`, and no constructor that accepts free text. A device name, a
/// bucket boundary, a cursor, a salt fingerprint, or an exception message is
/// **not a representable value** — the same technique `StepOriginKey` uses to
/// make a device name unstorable.
///
/// ## What may be carried
///
/// | Field | Why it is safe |
/// |---|---|
/// | snapshot generation | A small counter. Says nothing about the player |
/// | selected slot | One of two |
/// | recovery result codes | Enum names from a closed set |
/// | save format version | A build constant |
/// | journal record count | A cardinality |
/// | aggregate `lateDiscardedSlices` | A count. The one lossy path, and a loss you cannot count is a haunting |
/// | integrity result | Three values |
///
/// ## What is deliberately absent, and why each one is a trap
///
/// - **`StepOriginKey` values.** Pseudonymous, but stable per installation:
///   two diagnostics naming the same key link two sessions to one device.
/// - **Bucket timestamps.** A UTC millisecond boundary is when the player was
///   moving. `StepLedger.signature` carries `watermarkMillis` and is therefore
///   *not* usable here — that is why this type does not delegate to it.
/// - **Bucket amounts.** How far they walked, and when.
/// - **Cursor bytes.** An opaque platform token, but it is the provider's
///   handle on the player's health timeline.
/// - **The salt, or its fingerprint.** The fingerprint does not reverse, but it
///   is a stable per-installation identifier by any other name.
/// - **Save payloads.** The whole ledger, transitively.
/// - **Device or source names.** The thing the pseudonymizer exists to remove.
/// - **Raw exception text.** The quietest leak available: an I/O error message
///   contains a filesystem path, and a decode error can echo the value it
///   rejected. `BootstrapBlocked.detail` already carries `'$e'`; that string
///   must not be forwarded here.
///
/// Nothing in this file may gain a `String` field without a privacy review. The
/// frozen key set in `save_diagnostics_privacy_test.dart` is what makes that
/// obligation mechanical rather than remembered.
library;

import 'package:meta/meta.dart';

import '../save/save_codec.dart';
import '../save/save_outcomes.dart';
import '../steps/step_ledger.dart';

/// How the load ended, at diagnostic resolution.
enum DiagnosticOutcome {
  /// Loaded cleanly.
  loaded,

  /// Loaded, but something was repaired or discarded on the way.
  loadedDegraded,

  /// The build declined to open the save. Nothing was deleted.
  refused,
}

/// What the integrity check concluded.
///
/// Three values rather than a boolean, because "we did not get far enough to
/// check" is a different fact from "it verified", and reporting it as `false`
/// would send someone looking for corruption that was never observed.
enum DiagnosticIntegrity {
  /// A slot verified its CRC-32C and its full envelope.
  verified,

  /// A slot's digest did not match its payload.
  mismatch,

  /// No slot got far enough to be checked.
  notEstablished,
}

/// A redacted view of one load, safe for any diagnostic surface.
@immutable
final class SaveDiagnostics {
  const SaveDiagnostics._({
    required this.outcome,
    required this.saveFormatVersion,
    required this.snapshotGeneration,
    required this.selectedSlot,
    required this.integrity,
    required this.journalRecordCount,
    required this.lateDiscardedSlices,
    required this.recoveryCodes,
    required this.refusalCode,
  });

  /// From a successful load.
  ///
  /// [ledger] supplies exactly one number: the aggregate discard count. The
  /// ledger is passed whole rather than as an `int` so a caller cannot quietly
  /// substitute some other figure, and so this file — which is the reviewed
  /// one — decides what is read off it.
  factory SaveDiagnostics.fromLoaded(
    SaveLoaded load,
    StepLedger ledger, {
    required int journalRecordCount,
    int saveFormatVersion = SaveFormatVersion.current,
  }) => SaveDiagnostics._(
    outcome: load.degraded
        ? DiagnosticOutcome.loadedDegraded
        : DiagnosticOutcome.loaded,
    saveFormatVersion: saveFormatVersion,
    snapshotGeneration: load.generation,
    selectedSlot: load.fromSlot,
    integrity: _integrityFrom(load.repairs, loaded: true),
    journalRecordCount: journalRecordCount,
    lateDiscardedSlices: ledger.lateDiscardedSlices,
    recoveryCodes: _codes(load.repairs),
    refusalCode: null,
  );

  /// From a refusal.
  ///
  /// [refusal.explanation] is player-legible prose and [SaveRepair.detail] is
  /// free-form text; **neither is read**. Only the enum names cross into a
  /// diagnostic, because a reviewed string today is an unreviewed string after
  /// the next edit.
  ///
  /// [ledger] is optional: a refusal may occur before any state exists. Absent,
  /// the discard count is reported as unknown rather than as zero — zero is a
  /// claim, and it would be a false one.
  factory SaveDiagnostics.fromRefused(
    LoadRefused refusal, {
    StepLedger? ledger,
    required int journalRecordCount,
    int saveFormatVersion = SaveFormatVersion.current,
  }) => SaveDiagnostics._(
    outcome: DiagnosticOutcome.refused,
    saveFormatVersion: saveFormatVersion,
    snapshotGeneration: null,
    selectedSlot: null,
    integrity: _integrityFrom(refusal.repairs, loaded: false),
    journalRecordCount: journalRecordCount,
    lateDiscardedSlices: ledger?.lateDiscardedSlices,
    recoveryCodes: _codes(refusal.repairs),
    refusalCode: refusal.reason,
  );

  final DiagnosticOutcome outcome;

  /// The framing version this build writes and reads.
  final int saveFormatVersion;

  /// Null on a refusal: no slot was selected, so there is no generation to
  /// report. Reporting 0 would look like a genesis save.
  final int? snapshotGeneration;

  /// Null on a refusal, for the same reason.
  final SnapshotSlot? selectedSlot;

  final DiagnosticIntegrity integrity;

  /// How many records the journal held. A cardinality, never their contents —
  /// a reconciliation record carries a full granted-slice map.
  final int journalRecordCount;

  /// The aggregate count from `StepLedger.lateDiscardedSlices`.
  ///
  /// Null when no ledger was available. Non-zero means real steps were probably
  /// lost, and S-01 is obliged to investigate every occurrence on a real
  /// device — which is exactly why it must be visible here and why it must be
  /// a count and nothing more.
  final int? lateDiscardedSlices;

  /// The `SaveDiagnosis` names from the repairs the load recorded.
  final List<String> recoveryCodes;

  /// Null unless the load was refused.
  final LoadRefusal? refusalCode;

  static List<String> _codes(List<SaveRepair> repairs) =>
      List<String>.unmodifiable(
        repairs.map((SaveRepair r) => r.diagnosis.name),
      );

  static DiagnosticIntegrity _integrityFrom(
    List<SaveRepair> repairs, {
    required bool loaded,
  }) {
    for (final SaveRepair repair in repairs) {
      if (repair.diagnosis == SaveDiagnosis.slotIntegrityMismatch) {
        return DiagnosticIntegrity.mismatch;
      }
    }
    // A load that produced a state necessarily verified the slot it used.
    return loaded
        ? DiagnosticIntegrity.verified
        : DiagnosticIntegrity.notEstablished;
  }

  /// The structured form. Every value is an int, a bool-free enum name, or a
  /// list of enum names.
  ///
  /// The key set is frozen by test. Adding a key is a privacy review.
  Map<String, Object?> toMap() => <String, Object?>{
    'outcome': outcome.name,
    'saveFormatVersion': saveFormatVersion,
    'snapshotGeneration': snapshotGeneration,
    'selectedSlot': selectedSlot?.name,
    'integrity': integrity.name,
    'journalRecordCount': journalRecordCount,
    'lateDiscardedSlices': lateDiscardedSlices,
    'recoveryCodes': recoveryCodes,
    'refusalCode': refusalCode?.name,
  };

  /// The rendered form — the string that would actually reach a log or a
  /// support screen.
  ///
  /// `?` for an absent value rather than omitting the field, so a reader can
  /// tell "not applicable" from "the diagnostic did not report it".
  String render() {
    String or(Object? value) => value?.toString() ?? '?';
    return 'SaveDiagnostics('
        'outcome=${outcome.name}; '
        'format=$saveFormatVersion; '
        'generation=${or(snapshotGeneration)}; '
        'slot=${or(selectedSlot?.name)}; '
        'integrity=${integrity.name}; '
        'journalRecords=$journalRecordCount; '
        'lateDiscarded=${or(lateDiscardedSlices)}; '
        'recovery=[${recoveryCodes.join(",")}]; '
        'refusal=${or(refusalCode?.name)})';
  }

  @override
  String toString() => render();
}
