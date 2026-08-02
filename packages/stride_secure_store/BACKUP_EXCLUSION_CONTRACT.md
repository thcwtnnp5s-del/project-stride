# Backup exclusion — the contract between this package and its callers

**Status:** the per-write entry point exists in this package and is tested. The
call sites in `stride_storage` and `lib/runtime` **have not been added** — they
are outside this agent's file ownership. Until they are, the exclusion is
applied once at launch and is lost again on the first commit.

---

## 1. The defect

`NSURLIsExcludedFromBackupKey` is a resource value on the **filesystem node**,
not on a path and not on the app. Apple documents it that way, and the
consequence is that the attribute does not follow a path across the ordinary
operations a save system performs. A replacement, an atomic write, a rename over
the top, or a delete-and-recreate all leave the path naming a *different* node,
and the new node carries whatever attributes it was born with — none.

Today the exclusion is applied exactly once per launch, in `IdentityVault.open`
(`lib/runtime/identity_vault.dart`), **before any save file is written or
replaced**. That is insufficient in three distinct ways:

| When | What happens | Result |
|---|---|---|
| First commit | `FileSnapshotStore.write` creates `save_slot_a`. At launch it did not exist, so the sweep reported it `missing` — correctly. | The slot is never excluded. |
| First append | `FileLedgerJournal.appendLine` creates `ledger_journal`. | The journal is never excluded. |
| **Every compaction** | `FileLedgerJournal.replaceLines` writes `ledger_journal.compacting` and **renames it over** `ledger_journal`. The journal path now names the sidecar's node. | The journal **loses** an exclusion it previously had. |

The third is the serious one, because it is a regression rather than a gap: the
file was protected, and a routine maintenance operation silently unprotected it.

This is demonstrated, not argued. `example/ios/RunnerTests/RunnerTests.swift`:

* `testARenameOverTheTopDropsTheExclusion` — the journal compaction, exactly.
* `testAnAtomicWriteDropsTheExclusion`
* `testReplaceItemAtDropsTheExclusion`
* `testAFileCreatedAfterTheSweepIsNotExcludedUntilReapplied`
* `testTruncatingInPlaceKeepsTheExclusion` — the counter-case, so the contract
  is precise rather than superstitious. `writeVerified` opens `FileMode.write`,
  which truncates the existing inode rather than replacing it, so an *overwrite*
  of an existing file does keep the attribute. Re-application is still required
  after it, because the file may not have existed beforehand.

These run on the macOS CI job and have never been executed on this machine.

---

## 2. What this package now provides

```dart
// packages/stride_secure_store/lib/src/secure_identity_store.dart

abstract interface class SecureIdentityStore {
  /// The launch sweep. Directory plus every declared file. Unchanged.
  Future<BackupExclusionReport> applyBackupExclusions({
    required String directoryPath,
    required List<String> filePaths,
  });

  /// The per-write call. A bare list, no directory.
  Future<BackupExclusionReport> reapplyBackupExclusions(List<String> paths);
}

/// The shape `stride_storage` accepts. Structural, so neither package needs to
/// import the other.
typedef ReapplyBackupExclusion = Future<void> Function(List<String> paths);

extension SecureIdentityStoreBackupHook on SecureIdentityStore {
  ReapplyBackupExclusion? backupExclusionHook({
    void Function(BackupExclusionReport report)? onReport,
  });
}
```

Cost per call: one Pigeon round trip, then two `setResourceValues`-class
operations per path (the write and the verifying read-back). Against an fsync on
the same commit, negligible. It is the *same* Swift code as the launch sweep —
`BackupExclusion.apply(paths:)`, with `apply(directoryPath:filePaths:)`
delegating to it — deliberately, because a second cheaper implementation that
dropped the read-back "for the hot path" would report success for precisely the
replaced-node case it exists to catch.

`backupExclusionHook` returns **null** where there is no platform
implementation, rather than a no-op closure, so "the control is not active here"
and "the control ran and did nothing" stay distinguishable. On Android the
exclusion is declarative and stronger (`allowBackup=false` plus domain-wide
data-extraction excludes), and calling an unregistered plugin would raise
`MissingPluginException` on every commit.

The hook **does not throw** on a failed re-application. It runs on the commit
path, and a refused `setResourceValues` must not turn a durable save into a
failed one — the Keychain identity is the first control and does not depend on
this succeeding. `onReport` exists so the failure is still visible: a `failed`
entry is the one condition meaning a file would travel in a restore, and
dropping it on the floor would make the per-write control unobservable, which is
the same mistake as applying it once at launch.

---

## 3. Why the wiring cannot be a direct call

`stride_storage` is pure `dart:io` with **no Flutter binding**, deliberately, so
its conformance suite runs headless under `dart test`. It therefore cannot
import `stride_secure_store`, which depends on Flutter. Do not add the
dependency; it would drag the Flutter engine into the one package that must stay
runnable without it.

The binding is made by **injecting a plain function** from `lib/runtime/`, which
already depends on both. Dart function types are structural, so a typedef
declared in `stride_storage` matches `ReapplyBackupExclusion` without either
package importing the other.

---

## 4. The call sites to add

### 4.1 `packages/stride_storage/lib/src/file_storage.dart`

**Declare the hook shape** (top level, near `StorageLayout`):

```dart
/// Re-applies the platform's backup exclusion to [paths].
///
/// Injected from `lib/runtime/`, because this package must not depend on
/// Flutter. Null off iOS. See
/// packages/stride_secure_store/BACKUP_EXCLUSION_CONTRACT.md.
typedef ReapplyBackupExclusion = Future<void> Function(List<String> paths);
```

**`FileSnapshotStore`** — add `final ReapplyBackupExclusion? reapplyExclusion;`
as an optional named constructor parameter (the class is `const`; it stays
`const`). Then in `write` (currently lines 176–181):

```dart
  @override
  Future<void> write(SnapshotSlot slot, Uint8List bytes) async {
    await layout.ensureExists();
    final File file = _fileFor(slot);
    await writeVerified(file, bytes);
    // The slot is created on its first write, after the launch sweep has
    // already reported it missing. The directory is included because
    // ensureExists may have just recreated it.
    await reapplyExclusion?.call(<String>[layout.root.path, file.path]);
  }
```

**`FileLedgerJournal`** — same constructor addition. Three call sites:

`appendLine` (currently lines 227–293), after the read-back block succeeds and
before returning:

```dart
    await reapplyExclusion?.call(<String>[layout.root.path, layout.journal.path]);
```

`replaceLines` (currently lines 296–327) — **the important one**, two calls:

```dart
    await writeVerified(layout.journalSidecar, bytes);
    // Excluded before the rename, not after: a crash between the two leaves the
    // sidecar on disk, and the launch sweep reported it missing because it did
    // not exist then.
    await reapplyExclusion?.call(<String>[layout.journalSidecar.path]);

    await layout.journalSidecar.rename(layout.journal.path);
    // The journal path now names the sidecar's node, which has the sidecar's
    // attributes. Without this the journal is unprotected from the first
    // compaction onward — see testARenameOverTheTopDropsTheExclusion.
    await reapplyExclusion?.call(<String>[layout.journal.path]);
```

**`FileIdentityStore`** — same constructor addition; after `writeVerified` in
both `writeStored` (line 406) and `write` (line 501):

```dart
    await reapplyExclusion?.call(<String>[layout.root.path, layout.identity.path]);
```

This is the Android path, where the hook is null and this is a no-op. Add it
anyway: the symmetry is what stops the next platform being a special case.

### 4.2 `packages/stride_storage/lib/src/file_lock.dart`

`FileTransactionLock` creates `transaction.lock` on first acquire (the
`open(mode: FileMode.write)` at line 64). `transactionLock` is in
`StorageLayout.allFiles` and therefore in the audited set, so leaving it
unexcluded makes the launch report internally inconsistent. Add the same
optional hook and call it after the open succeeds:

```dart
      await reapplyExclusion?.call(<String>[lockFile.path]);
```

It holds no data, so this is tidiness rather than a leak.

### 4.3 `lib/runtime/runtime_bootstrap.dart`

Resolve the secure store **once**, before the repository, and inject the hook.
Today `SaveRepository` is constructed at line 94 and `IdentityVault.open` runs
at line 119; the two must swap, because the repository now needs something the
store provides. That is safe — constructing the repository performs no I/O, and
the documented ordering rule ("nothing between opening storage and running the
coordinator writes an identity") is untouched, since the vault's *read* still
precedes the coordinator's load.

```dart
  await layout.ensureExists();

  // Resolved here rather than inside IdentityVault.open, because the repository
  // needs the same instance for its per-write exclusion hook.
  final SecureIdentityStore secure = secureStore ?? KeychainIdentityStore();

  final List<String> exclusionFailures = <String>[];

  final SaveRepository repository = SaveRepository(
    snapshots: FileSnapshotStore(
      layout,
      reapplyExclusion: secure.backupExclusionHook(
        onReport: (BackupExclusionReport r) =>
            exclusionFailures.addAll(r.failed),
      ),
    ),
    journal: FileLedgerJournal(
      layout,
      reapplyExclusion: secure.backupExclusionHook(
        onReport: (BackupExclusionReport r) =>
            exclusionFailures.addAll(r.failed),
      ),
    ),
    lock: FileTransactionLock(layout.transactionLock),
  );

  final IdentityVault vault = await IdentityVault.open(
    layout: layout,
    secureStore: secure,   // the resolved instance, not the nullable parameter
    entropy: random,
  );
```

`exclusionFailures` should be surfaced on `StrideRuntime` next to the existing
`vault.backupExclusion` launch report. A file that could not be excluded is the
one condition that means the ledger would travel; it must reach a diagnostic,
and it must not block startup.

**Also correct the doc comment at lines 66–74.** Step 2 currently reads as
though the launch sweep is the whole control. It should say the sweep covers the
directory and the files that exist at launch, and that the per-write hook covers
everything created or replaced afterwards.

### 4.4 `lib/runtime/identity_vault.dart`

Two comments overclaim and should be corrected (this is a project rule —
comments that lie are defects):

* Lines 34–38: "`ThisDeviceOnly` items are not in an encrypted backup and are
  not restored onto a different device" is stated as fact. It is **documented
  Apple behaviour this design relies on**, verified by nothing in this
  repository. The equivalent claims in `keychain_identity_store.dart`,
  `pigeons/secure_store_api.dart`, `lib/stride_secure_store.dart` and
  `KeychainIdentityStore.swift` have been hedged; this file was out of scope.
* Lines 40–46: "Re-applied on every launch, because the attribute lives on the
  filesystem node and a recreated directory silently loses it." Correct as far
  as it goes, and it is the sentence that made a launch-only application look
  sufficient. It should name the other, larger reason: the node is also replaced
  by every rename, atomic write, and replace, so the exclusion must be
  re-applied per write as well.

---

## 5. What remains unproven, and what is unprovable

**Unproven until the macOS CI job runs:** every Swift assertion in this
package. None has been executed — this is a Windows machine with no Xcode.

**Unprovable anywhere, by anything in this repository:**

* That a `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` Keychain item is
  genuinely omitted from an encrypted iCloud backup and genuinely not restored
  onto a second device.
* That `NSURLIsExcludedFromBackupKey` is genuinely honoured by iCloud or by
  Finder.

Both are properties of Apple's backup implementation. There is no API to
interrogate either. Demonstrating them requires two physical iPhones, an iCloud
account, a real backup and a real restore. No CI runner and no simulator can do
it, and a green suite must never be quoted as evidence that they hold. What the
tests prove is that the attributes are set to the values asked for, and that
they survive — or do not survive — specific local file operations.
