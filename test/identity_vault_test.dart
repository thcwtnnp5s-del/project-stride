// The identity ordering, through the real app wiring, against a fake secure
// store.
//
// ===========================================================================
// What this suite is really testing
// ===========================================================================
//
// The restore scenario, in the shape it actually occurs:
//
//   Device A plays. The save, the ledger and the identity all exist.
//   The player restores an iCloud backup onto device B.
//   The files arrive. The Keychain item does not — it is ThisDeviceOnly.
//   Device B must refuse.
//
// Before the identity was device-bound, the identity file arrived *with* the
// save, its fingerprint matched, `LoadRefusal.originKeyReset` never fired, and
// device B resumed a monotonic step ledger against a HealthKit source device A
// had already consumed from. The fail-closed check was defeated by the exact
// transport it was designed to detect.
//
// `restoreOnAFreshDevice` below is that scenario: the same files, a different
// (empty) secure store. It must block.
//
// ===========================================================================
// What this suite cannot test
// ===========================================================================
//
// Anything about Apple. There is no Keychain here and no backup machinery: the
// store is a fake and the assertions are about *our* ordering. That the real
// Keychain honours `ThisDeviceOnly`, and that iCloud honours
// `NSURLIsExcludedFromBackupKey`, is documented Apple behaviour this design
// relies on and has not verified. Two physical iPhones are needed for that.

import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/identity_vault.dart';
import 'package:stride/runtime/runtime_bootstrap.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_secure_store/stride_secure_store.dart';
import 'package:stride_storage/stride_storage.dart';

void main() {
  // rootBundle, for the content pack.
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('stride_identity_vault');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  StorageLayout layoutFor(Directory dir) =>
      StorageLayout(Directory('${dir.path}/${StorageLayout.directoryName}'));

  Future<StrideRuntime> launch(FakeSecureIdentityStore store) =>
      bootstrapStride(
        overrideRoot: root,
        secureStore: store,
        // Deterministic, so a saveId or a salt appearing in an assertion is
        // reproducible rather than a different value on every run.
        random: Random(1750000000),
      );

  // -------------------------------------------------------------------------
  // Rule 3 — no save and no key: create, and only on success
  // -------------------------------------------------------------------------

  group('no save and no key', () {
    test('starts a new game and creates the key exactly once', () async {
      final FakeSecureIdentityStore store = FakeSecureIdentityStore();

      final StrideRuntime runtime = await launch(store);

      expect(runtime.outcome, isA<BootstrapNewGame>());
      expect(store.creates, hasLength(1));
      expect(store.stored, isNotNull);
      expect(runtime.identityStorage, 'keychain');
    });

    test('the key that was created is the one the save records', () async {
      final FakeSecureIdentityStore store = FakeSecureIdentityStore();

      final StrideRuntime runtime = await launch(store);
      final BootstrapNewGame game = runtime.outcome as BootstrapNewGame;

      expect(store.stored!.saveId, game.identity.saveId);
      // The fingerprint in the save envelope is derived from the salt in the
      // store. If these ever diverge, every launch after the first refuses.
      expect(
        OriginSaltPolicy.fingerprint(store.stored!.salt),
        game.identity.saltFingerprint,
      );
    });

    test('the salt reaches the pseudonymizer and nothing else', () async {
      final FakeSecureIdentityStore store = FakeSecureIdentityStore();

      final StrideRuntime runtime = await launch(store);

      expect(runtime.pseudonymizer, isNotNull);
      // The identity file is the *old* home of the salt. On the keychain path
      // it must not be written at all — a file copy of the salt would travel
      // in a backup and reopen the exact hole this closes.
      expect(
        layoutFor(root).identity.existsSync(),
        isFalse,
        reason: 'the salt must not also be left in a backed-up file',
      );
    });

    test('a second launch resumes and creates nothing', () async {
      final FakeSecureIdentityStore store = FakeSecureIdentityStore();
      await launch(store);

      final StrideRuntime second = await launch(store);

      expect(second.outcome, isA<BootstrapExistingGame>());
      expect(
        store.creates,
        hasLength(1),
        reason: 'the key is created once per installation, not once per launch',
      );
    });
  });

  // -------------------------------------------------------------------------
  // Rule 1 — existing save, missing key
  // -------------------------------------------------------------------------

  group('restore onto a fresh device', () {
    test(
      'an existing save with no key blocks as originIdentityMissing',
      () async {
        // Device A.
        final FakeSecureIdentityStore deviceA = FakeSecureIdentityStore();
        expect((await launch(deviceA)).outcome, isA<BootstrapNewGame>());

        // Device B: the same files, a Keychain that did not travel.
        final FakeSecureIdentityStore deviceB = FakeSecureIdentityStore();
        final StrideRuntime restored = await launch(deviceB);

        expect(restored.outcome, isA<BootstrapBlocked>());
        expect(
          (restored.outcome as BootstrapBlocked).reason,
          BootstrapBlockReason.originIdentityMissing,
          reason:
              'this is the double-grant the whole reconciliation design exists '
              'to prevent, and it is silent if it gets through',
        );
      },
    );

    test('the restore never mints a replacement key', () async {
      final FakeSecureIdentityStore deviceA = FakeSecureIdentityStore();
      await launch(deviceA);

      final FakeSecureIdentityStore deviceB = FakeSecureIdentityStore();
      await launch(deviceB);

      // The assertion the ruling names: never mint a replacement before
      // checking whether a save exists. The save was checked; it exists; so
      // nothing was minted.
      expect(deviceB.creates, isEmpty);
      expect(deviceB.stored, isNull);
    });

    test('the refusal leaves every byte of the save alone', () async {
      final FakeSecureIdentityStore deviceA = FakeSecureIdentityStore();
      await launch(deviceA);

      final StorageLayout layout = layoutFor(root);
      final Map<String, int> before = <String, int>{
        for (final File f in layout.allFiles)
          if (f.existsSync()) f.path: f.lengthSync(),
      };

      await launch(FakeSecureIdentityStore());

      for (final MapEntry<String, int> entry in before.entries) {
        expect(
          File(entry.key).lengthSync(),
          entry.value,
          reason: 'refusing is recoverable; deleting is not',
        );
      }
    });

    test('the player is told the way out', () async {
      await launch(FakeSecureIdentityStore());
      final StrideRuntime restored = await launch(FakeSecureIdentityStore());

      final BootstrapBlocked blocked = restored.outcome as BootstrapBlocked;
      expect(blocked.explanation, contains('Reconnect health'));
      expect(blocked.explanation, contains('progress is kept'));
      // No pseudonymizer on a blocked launch: nothing may key an origin
      // against a salt this device has not established.
      expect(restored.pseudonymizer, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // Rule 2 — existing save, mismatched key
  // -------------------------------------------------------------------------

  group('a key from another installation', () {
    test('blocks as originIdentityMismatch, distinctly from missing', () async {
      await launch(FakeSecureIdentityStore());

      final FakeSecureIdentityStore foreign = FakeSecureIdentityStore(
        initial: SecureIdentity(saveId: 'another-lineage', salt: fakeSalt(9)),
      );
      final StrideRuntime result = await launch(foreign);

      expect(
        (result.outcome as BootstrapBlocked).reason,
        BootstrapBlockReason.originIdentityMismatch,
      );
      expect(foreign.creates, isEmpty, reason: 'never overwrite a live key');
      expect(foreign.stored!.saveId, 'another-lineage');
    });
  });

  // -------------------------------------------------------------------------
  // Rule 4 — a failed read is never a reason to write
  // -------------------------------------------------------------------------

  group('a read that could not answer', () {
    test('over a live save: blocks, and writes nothing', () async {
      await launch(FakeSecureIdentityStore());

      final FakeSecureIdentityStore locked = FakeSecureIdentityStore()
        ..readIsUnavailable = true;
      final StrideRuntime result = await launch(locked);

      expect(
        (result.outcome as BootstrapBlocked).reason,
        BootstrapBlockReason.storageUnavailable,
      );
      expect(locked.creates, isEmpty);
      expect(locked.stored, isNull);
    });

    test('on an empty device: still blocks, and still writes nothing', () async {
      // The tempting case, and the one the ruling calls out. Nothing on disk,
      // an identity read that failed, and the obvious repair is "there is
      // nothing here, make one".
      //
      // On iOS this is a real state, not a contrivance: the save files are
      // readable at first unlock while the Keychain is not readable before it,
      // so a background launch can genuinely see an unreadable identity beside
      // files it has not yet been able to interpret. Minting here writes a key
      // that the next successful read contradicts.
      final FakeSecureIdentityStore locked = FakeSecureIdentityStore()
        ..readIsUnavailable = true;

      final StrideRuntime result = await launch(locked);

      expect(
        (result.outcome as BootstrapBlocked).reason,
        BootstrapBlockReason.storageUnavailable,
      );
      expect(locked.creates, isEmpty, reason: 'a failed read must not write');
      expect(layoutFor(root).slotA.existsSync(), isFalse);
      expect(layoutFor(root).slotB.existsSync(), isFalse);
    });

    test(
      'a later launch, once the device is unlocked, starts normally',
      () async {
        final FakeSecureIdentityStore store = FakeSecureIdentityStore()
          ..readIsUnavailable = true;
        expect((await launch(store)).outcome, isA<BootstrapBlocked>());

        store.readIsUnavailable = false;
        final StrideRuntime second = await launch(store);

        // Refusing is recoverable, which is the whole argument for refusing.
        expect(second.outcome, isA<BootstrapNewGame>());
        expect(store.creates, hasLength(1));
      },
    );
  });

  // -------------------------------------------------------------------------
  // The vault itself
  // -------------------------------------------------------------------------

  group('the vault', () {
    test('refuses to write an identity it did not mint', () async {
      final IdentityVault vault = await IdentityVault.open(
        layout: layoutFor(root),
        secureStore: FakeSecureIdentityStore(),
      );

      expect(
        () => vault.write(
          const ReconciliationIdentity(
            saveId: 'not-ours',
            saltFingerprint: 'ffffffffffffffff',
          ),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('refuses to write over an identity that was already there', () async {
      final IdentityVault vault = await IdentityVault.open(
        layout: layoutFor(root),
        secureStore: FakeSecureIdentityStore(
          initial: SecureIdentity(saveId: 'live', salt: fakeSalt()),
        ),
      );

      final ReconciliationIdentity? existing = await vault.read();
      expect(existing, isNotNull);

      // The coordinator does not do this. The port allows it, and an adapter
      // that silently replaced a live key on being asked would undo the whole
      // control, so it is refused here rather than trusted not to happen.
      expect(
        () => vault.write(existing!),
        throwsA(isA<IdentityAlreadyExists>()),
      );
    });

    test('an unavailable read faults at read(), not at open()', () async {
      // Deferred deliberately. Thrown from  it would escape
      //  as a crash; thrown from  — the port method the
      // coordinator calls — it becomes a typed refusal with a player-legible
      // explanation. Both are 'the game did not open', and only one of them is
      // a state the app can present and recover from.
      final IdentityVault vault = await IdentityVault.open(
        layout: layoutFor(root),
        secureStore: FakeSecureIdentityStore()..readIsUnavailable = true,
      );

      expect(vault.read, throwsA(isA<IdentityStoreUnavailable>()));
      expect(
        () => vault.write(
          const ReconciliationIdentity(
            saveId: 'x',
            saltFingerprint: 'ffffffffffffffff',
          ),
        ),
        throwsA(isA<IdentityStoreUnavailable>()),
        reason: 'a store that could not be read must not be written',
      );
      expect(
        vault.mintCandidate,
        throwsA(isA<StateError>()),
        reason: 'minting after a failed read is the rule the owner named',
      );
    });

    test('falls back to file storage where there is no secure store', () async {
      // Android's path. The identity is app-private and covered by
      // allowBackup=false plus domain-wide data-extraction excludes.
      final IdentityVault vault = await IdentityVault.open(
        layout: layoutFor(root),
        secureStore: FakeSecureIdentityStore(isSupported: false),
      );

      expect(vault.storageDescription, 'app-private file');
      // No plugin call: invoking an unregistered platform channel on Android
      // would raise MissingPluginException on every launch, for no gain.
      expect(vault.backupExclusion.excluded, isEmpty);
      expect(vault.backupExclusion.isClean, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // Backup exclusions
  // -------------------------------------------------------------------------

  group('backup exclusions', () {
    test('are re-applied on every launch, not once at install', () async {
      final FakeSecureIdentityStore store = FakeSecureIdentityStore();

      await launch(store);
      await launch(store);
      await launch(store);

      expect(
        store.calls.where((String c) => c == 'applyBackupExclusions').length,
        3,
        reason:
            'the attribute lives on the filesystem node, so a directory that '
            'is deleted and recreated loses it with nothing reporting so',
      );
    });

    test('cover the directory and every file StorageLayout declares', () async {
      final FakeSecureIdentityStore store = FakeSecureIdentityStore();
      await launch(store);

      final StorageLayout layout = layoutFor(root);
      final List<String> expected = <String>[
        layout.root.path,
        ...layout.allFiles.map((File f) => f.path),
      ];

      // Read out of `allFiles`, not from a list written here. A sixth file
      // added to the layout is covered the day it is added rather than the day
      // somebody notices it was not.
      expect(store.lastExclusionPaths, expected);
      expect(store.lastExclusionPaths, hasLength(greaterThanOrEqualTo(7)));
    });

    test('a failed exclusion is reported, not fatal', () async {
      final FakeSecureIdentityStore store = FakeSecureIdentityStore()
        ..plannedExclusionReport = const BackupExclusionReport(
          excluded: <String>[],
          missing: <String>[],
          failed: <String>['/x/ledger_journal\tattribute did not stick'],
        );

      final StrideRuntime runtime = await launch(store);

      // The Keychain identity is the primary control and still holds. Refusing
      // to start the game over a failed setResourceValues would be the worse
      // trade — but it must be visible, so it is on the runtime.
      expect(runtime.outcome, isA<BootstrapNewGame>());
      expect(runtime.backupExclusion.isClean, isFalse);
      expect(runtime.backupExclusion.failed, hasLength(1));
    });
  });
}
