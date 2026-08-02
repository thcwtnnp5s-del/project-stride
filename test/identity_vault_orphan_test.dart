// The orphan identity, through the real app wiring.
//
// ===========================================================================
// The claim this file exists to settle
// ===========================================================================
//
// `test/closure_audit_test.dart`'s C4 probe used to assert that a refused
// first commit must write no identity at all, and its stated harm was specific
// and checkable:
//
//   "the coordinator writes the core-facing shape (saveId + saltFingerprint,
//   no salt), and FileIdentityStore.readStored throws ... on a record with no
//   salt. bootstrapStride calls readStored outside any try, so the NEXT launch
//   throws out of startup entirely."
//
// It is false, and the tests below are what makes that a fact rather than an
// assertion in a comment. The coordinator does not reach `FileIdentityStore`
// at all: it writes through `IdentityVault.write`, which ignores the
// core-facing argument except as a check and persists the **full candidate**
// via `_backend.create` — saveId and salt. So `readStored` finds the `salt`
// field it requires and returns normally.
//
// The owner's ruling then changed what happens next: an identity with
// conclusively no save beside it is an orphan, and the next launch clears it
// and reprovisions rather than reusing it. That is asserted here too, because
// "does not throw" and "recovers" are different properties and only the second
// one is worth having.

import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/runtime_bootstrap.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_secure_store/stride_secure_store.dart';
import 'package:stride_storage/stride_storage.dart';

void main() {
  // rootBundle, for the content pack.
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('stride_orphan_identity');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  StorageLayout layoutFor(Directory dir) =>
      StorageLayout(Directory('${dir.path}/${StorageLayout.directoryName}'));

  /// The file backend — Android's path, and the one the disproved claim was
  /// about, since `FileIdentityStore` is the only store with a decoder to
  /// throw out of.
  Future<StrideRuntime> launchOnFiles() => bootstrapStride(
    overrideRoot: root,
    secureStore: FakeSecureIdentityStore(isSupported: false),
    random: Random(1750000000),
  );

  group('a vault-written identity is a complete record', () {
    test('IdentityVault.write persists the salt, not just its '
        'fingerprint', () async {
      await launchOnFiles();

      final StorageLayout layout = layoutFor(root);
      expect(layout.identity.existsSync(), isTrue);

      // The exact call the deleted comment claimed would throw.
      final StoredIdentity? stored = await FileIdentityStore(
        layout,
      ).readStored();

      expect(
        stored,
        isNotNull,
        reason:
            'a record written by the coordinator must round-trip through '
            'readStored',
      );
      expect(
        stored!.salt,
        isNotEmpty,
        reason:
            'the salt-less shape is what would have made readStored throw; '
            'IdentityVault.write does not write it',
      );
    });

    test('an identity left with no save does not throw on the next '
        'launch', () async {
      // The orphan, built the way an interrupted first save builds it: a
      // complete identity record with the save artifacts absent.
      await launchOnFiles();
      final StorageLayout layout = layoutFor(root);
      for (final File f in <File>[layout.slotA, layout.slotB, layout.journal]) {
        if (f.existsSync()) f.deleteSync();
      }
      expect(layout.identity.existsSync(), isTrue);

      final StrideRuntime second = await launchOnFiles();

      expect(
        second.outcome,
        isA<BootstrapNewGame>(),
        reason:
            'the orphan is cleared and a new lineage provisioned; the launch '
            'is a typed outcome, not an exception out of bootstrapStride',
      );
    });

    test('the reprovisioned lineage is not the orphan lineage', () async {
      final StrideRuntime first = await launchOnFiles();
      final String orphanSaveId =
          (first.outcome as BootstrapNewGame).identity.saveId;

      final StorageLayout layout = layoutFor(root);
      for (final File f in <File>[layout.slotA, layout.slotB, layout.journal]) {
        if (f.existsSync()) f.deleteSync();
      }

      // A different entropy stream, so the new saveId cannot coincide with the
      // old one and pass this by accident.
      final StrideRuntime second = await bootstrapStride(
        overrideRoot: root,
        secureStore: FakeSecureIdentityStore(isSupported: false),
        random: Random(42),
      );

      final BootstrapNewGame game = second.outcome as BootstrapNewGame;
      expect(
        game.identity.saveId,
        isNot(orphanSaveId),
        reason:
            'a save must never be written under a lineage minted for a '
            'different save',
      );

      // And the durable save agrees with the object we were handed.
      final StoredIdentity stored = (await FileIdentityStore(
        layout,
      ).readStored())!;
      expect(stored.saveId, game.identity.saveId);
    });
  });
}
