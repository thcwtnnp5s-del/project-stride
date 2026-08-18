// S-01A iOS acceptance: what can be proved without a Mac, and only that.
//
// ===========================================================================
// The division of labour, stated so nobody has to infer it
// ===========================================================================
//
// The iOS vertical slice has three layers and each is proved somewhere
// different. Confusing them is how a green suite comes to be quoted as
// evidence for something nobody tested.
//
//   1. The simulation — reconciliation, the ledger, the save, the gathering
//      command. Platform-neutral, and `s01a_vertical_slice_test.dart` covers
//      it end to end through the real `StrideSession`. Those assertions hold
//      on iOS unchanged, because the whole point of the normalized
//      `SyncResponse` is that the two platforms produce the same value.
//
//   2. The Swift adapter's mapping rules — authorization states, absolute
//      restatement, deletion as zero, completeness suppression on a non-final
//      page, anchor handling, origin keying against the shared vectors.
//      `packages/stride_health/example/ios/RunnerTests/` covers it, and it
//      runs on the macOS CI job.
//
//   3. `HKHealthStore` itself. Covered by NOTHING, anywhere, and it cannot be:
//      an authorization prompt cannot be answered on a runner, a simulator
//      holds no real step samples, and a simulator is never locked. It needs a
//      physical iPhone.
//
// This file is a fourth thing, and a narrow one: the **configuration and
// structural** facts that decide whether the iOS build is capable of working
// at all. Every one of them is a property of files in this repository, which is
// why they are assertable from Windows — and every one of them has a failure
// mode that a compile would not catch.
//
// A missing `NSHealthShareUsageDescription` does not fail to build. It
// terminates the app at the moment the player taps Request Permission, on a
// device, in front of the owner.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stride/debug/dev_harness.dart';
import 'package:stride_core/stride_core.dart';

/// Reads a file relative to the repository root.
String repoFile(String path) {
  final File file = File(path);
  if (!file.existsSync()) {
    fail('$path does not exist. iOS cannot be built or installed without it.');
  }
  return file.readAsStringSync();
}

/// Swift sources that ship in the app, excluding generated bindings.
///
/// `Messages.g.swift` is Pigeon output and is regenerated from the contract, so
/// asserting against its text would be asserting against a code generator.
List<File> shippingSwiftSources() {
  final Directory root = Directory(
    'packages/stride_health/ios/stride_health/Sources/stride_health',
  );
  if (!root.existsSync()) fail('the iOS health plugin sources are missing');
  return root
      .listSync(recursive: true)
      .whereType<File>()
      .where((File f) => f.path.endsWith('.swift'))
      .where((File f) => !f.path.endsWith('Messages.g.swift'))
      .toList();
}

/// [source] with `//` comment lines removed.
///
/// Mandatory rather than tidy. Every file below documents the APIs it refuses
/// to use, by name, in prose — which is the reasoning worth keeping — and a
/// scan that cannot tell code from prose would make it impossible to write that
/// sentence down. The Android suite learned this the same way.
String codeOnly(String source) => source
    .split('\n')
    .where((String line) => !line.trimLeft().startsWith('//'))
    .where((String line) => !line.trimLeft().startsWith('///'))
    .where((String line) => !line.trimLeft().startsWith('*'))
    .join('\n');

/// A plist or XML file with its `<!-- ... -->` comments removed.
///
/// Separate from [codeOnly] because the entitlements file's explanation of why
/// `com.apple.developer.healthkit.background-delivery` is absent is an XML
/// comment spanning several lines, and a line-prefix filter cannot see it. The
/// first version of the test below failed on that comment — reporting the
/// entitlement as declared by the very sentence saying it is not.
///
/// `Scripts/check-ios-target.sh` parses the plist semantically and is the
/// authoritative check. This is the same rule where `flutter test` can see it.
String withoutXmlComments(String source) =>
    source.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // =========================================================================
  // 1, 2, 13 — the app cannot ask for more than it is entitled to
  // =========================================================================

  group('the iOS entitlement and usage-string surface', () {
    late String entitlements;
    late String infoPlist;

    setUp(() {
      entitlements = repoFile('ios/Runner/Runner.entitlements');
      infoPlist = repoFile('ios/Runner/Info.plist');
    });

    test('HealthKit is entitled, read-only', () {
      expect(entitlements, contains('com.apple.developer.healthkit'));
      // An empty access array. `health-records` would be clinical records,
      // which this game has no business asking for.
      expect(entitlements, contains('com.apple.developer.healthkit.access'));
      expect(entitlements, isNot(contains('health-records')));
    });

    test('13 — the background-delivery entitlement is absent', () {
      // The single most consequential absence in the iOS build. With it, iOS
      // wakes the app into a second execution context, and the single-writer
      // persistence model covers exactly none of that (DECISIONS/0013).
      //
      // Asserted on the code, not the prose: the file explains at length why
      // the key is missing, and naming it in that explanation must not read as
      // declaring it.
      expect(
        withoutXmlComments(entitlements),
        isNot(contains('com.apple.developer.healthkit.background-delivery')),
      );
    });

    test('the share usage string is present and the write one is not', () {
      // Present: iOS terminates the app the instant it requests read
      // authorization without `NSHealthShareUsageDescription`. That is a
      // crash on the owner's phone, at the exact moment of the demo, that no
      // compile and no simulator run would have surfaced.
      expect(infoPlist, contains('NSHealthShareUsageDescription'));
      // Absent: Stride reads steps and never writes health data. A write
      // string would ask the player to grant access the game cannot justify.
      expect(infoPlist, isNot(contains('NSHealthUpdateUsageDescription')));
    });

    test('no background mode is declared', () {
      expect(
        withoutXmlComments(infoPlist),
        isNot(contains('UIBackgroundModes')),
      );
    });

    test('the usage string explains the trade in the player\'s terms', () {
      // Not a formatting preference. Apple rejects a placeholder string, and
      // more to the point this sentence is the only explanation the player
      // ever gets before deciding.
      final int start = infoPlist.indexOf('NSHealthShareUsageDescription');
      final String tail = infoPlist.substring(start);
      expect(tail, contains('step'));
      expect(
        tail.length,
        greaterThan(60),
        reason:
            'a placeholder usage string is rejected by App Review and '
            'tells the player nothing',
      );
    });
  });

  // =========================================================================
  // 12, 13 — the Swift adapter's structural obligations
  // =========================================================================

  group('the Swift adapter, as source', () {
    test('13 — no background delivery, observer query, or background task', () {
      const List<String> forbidden = <String>[
        'enableBackgroundDelivery',
        'HKObserverQuery',
        'beginBackgroundTask',
        'BGTaskScheduler',
        'performFetchWithCompletionHandler',
      ];

      for (final File file in shippingSwiftSources()) {
        final String code = codeOnly(file.readAsStringSync());
        for (final String api in forbidden) {
          expect(
            code,
            isNot(contains(api)),
            reason:
                '${file.path} uses "$api". S-01A is foreground only; '
                'background delivery is S-01B and is blocked on a real '
                'persistence coordinator (DECISIONS/0013, 0014).',
          );
        }
      }
    });

    test('the candidate anchor is never persisted natively', () {
      // The commit order is inviolable: the adapter returns a candidate anchor
      // and forgets it, and only a committed ledger makes it durable. A native
      // cache would claim progress the ledger never recorded, and an
      // interrupted sync would be unrecoverable.
      //
      // `NSKeyedArchiver` is deliberately NOT in this list: archiving the
      // anchor is how it becomes bytes for the wire, which is the opposite of
      // persisting it.
      const List<String> durableStores = <String>[
        'UserDefaults',
        'NSUserDefaults',
        'FileManager',
        'SecItemAdd',
        'NSKeyedArchiver.archiveRootObject',
        'writeToFile',
      ];

      for (final File file in shippingSwiftSources()) {
        final String code = codeOnly(file.readAsStringSync());
        for (final String api in durableStores) {
          expect(code, isNot(contains(api)), reason: file.path);
        }
      }
    });

    test('12 — no source display name is read anywhere', () {
      // `HKSource.bundleIdentifier` is the only identifier this adapter may
      // touch. `HKSource.name` and `HKDevice.name` are device names a player
      // may have called anything at all, and a display name hashed into an
      // origin key is worse than useless because it looks correct.
      for (final File file in shippingSwiftSources()) {
        final String code = codeOnly(file.readAsStringSync());
        expect(code, isNot(contains('.localizedName')), reason: file.path);
        expect(code, isNot(contains('HKDevice')), reason: file.path);
        // Any `.name` read on a source or device. `bundleIdentifier` is the
        // permitted one and does not match this.
        expect(
          RegExp(r'\bsource\w*\.name\b', caseSensitive: false).hasMatch(code),
          isFalse,
          reason: '${file.path} reads a source display name',
        );
      }
    });

    test('12 — the Pigeon contract has no field a raw identifier could use', () {
      // The structural half of the control, and the reason it is structural:
      // there is no `String` origin field on the wire, so a raw identifier has
      // nowhere to travel. `originKey` is `Uint8List` of exactly eight bytes,
      // and a bundle identifier does not fit in eight bytes.
      //
      // This is a constraint, not a proof — eight arbitrary bytes are still
      // eight bytes — and the vector tests in both native suites are what
      // check the bytes are actually a digest.
      final String contract = repoFile(
        'packages/stride_health/pigeons/health_api.dart',
      );
      final String code = codeOnly(contract);

      expect(code, contains('final Uint8List originKey'));
      expect(code, isNot(contains('String originIdentifier')));
      expect(code, isNot(contains('String sourceIdentifier')));
      expect(code, isNot(contains('String sourceName')));
      expect(code, isNot(contains('String bundleIdentifier')));
    });

    test('read-only: no share type is ever requested', () {
      final String store = codeOnly(
        repoFile(
          'packages/stride_health/ios/stride_health/Sources/stride_health/'
          'HealthKitStepStore.swift',
        ),
      );
      // `toShare:` is passed, and must be passed empty. A non-empty share set
      // would ask the player for write access the game never uses.
      expect(store, contains('toShare: Set<HKSampleType>()'));
      expect(store, contains('HKQuantityTypeIdentifier.stepCount'));
    });

    test('availability is checked before the store is touched', () {
      final String store = codeOnly(
        repoFile(
          'packages/stride_health/ios/stride_health/Sources/stride_health/'
          'HealthKitStepStore.swift',
        ),
      );
      // On an iPad, or any device without HealthKit, `HKHealthStore()` calls
      // trap rather than fail. The guard is what makes absence a typed answer
      // instead of a crash.
      expect(store, contains('HKHealthStore.isHealthDataAvailable()'));
    });
  });

  // =========================================================================
  // 8, 9 — the exact figures the device checklist will be read against
  // =========================================================================

  group('the gathering figures, as the content actually defines them', () {
    late ContentRegistry registry;

    setUpAll(() async {
      final ContentLoadResult result = const ContentLoader().load(
        ContentSource(<String, String>{
          for (final FileSystemEntity entity in Directory(
            'assets/content/v1',
          ).listSync())
            if (entity is File && entity.path.endsWith('.json'))
              entity.uri.pathSegments.last: entity.readAsStringSync(),
        }),
        profileId: BalanceProfile.productionId,
      );
      registry = result.registry!;
    });

    test('8, 9 — Meadow Patch is 90 energy for 2 herbs and 10 Foraging XP', () {
      // The literal numbers, deliberately. Every other test in the project
      // reads the cost from the registry, which is right for a test of the
      // arithmetic and wrong here: the device checklist tells the owner to
      // expect 90 and 2 and 10, and if the content is retuned this must fail
      // so the checklist is corrected in the same change.
      final ResourceNodeDefinition node = registry
          .resourceNodes[ContentId.unchecked('resource_node.meadow_patch')]!;
      final BalanceProfile profile = registry.profile;

      expect(profile.applyStepCost(node.stepCost), 90);
      expect(profile.applyYield(node.yieldsQuantity), 2);
      expect(profile.applyXp(node.xp), 10);
      expect(node.yieldsItem, ContentId.unchecked('item.meadow_herb'));
      expect(node.skill, ContentId.unchecked('skill.foraging'));
    });

    test('it is reachable from a new game with nothing', () {
      // No travel, no tool, no level. The checklist depends on this: any
      // prerequisite would turn "can the player spend energy" into "can the
      // player satisfy a prerequisite", which is a different milestone.
      final ResourceNodeDefinition node = registry
          .resourceNodes[ContentId.unchecked('resource_node.meadow_patch')]!;

      expect(node.requiredLevel, 1);
      expect(node.requiredToolKind, ToolKind.none);
      expect(
        registry.startLocation.resourceNodes,
        contains(ContentId.unchecked('resource_node.meadow_patch')),
      );
    });

    test('the harness points at that node and no other', () {
      expect(kHarnessNode, ContentId.unchecked('resource_node.meadow_patch'));
    });
  });

  // =========================================================================
  // The harness is one screen, not two
  // =========================================================================

  group('the shared harness', () {
    test('names the provider per platform and branches on nothing else', () {
      // On the test host this is neither, and it says so rather than defaulting
      // to one of the two.
      expect(healthProviderName, 'Health provider');

      // The single platform branch. A second one would be the beginning of an
      // iOS fork of a screen whose value is that there is one of it.
      final String harness = codeOnly(repoFile('lib/debug/dev_harness.dart'));
      expect(
        'Platform.isIOS'.allMatches(harness).length,
        1,
        reason: 'the provider name is the only thing that may vary by platform',
      );
      expect('Platform.isAndroid'.allMatches(harness).length, 1);
    });

    test('the session layer branches on no platform at all', () {
      // `StrideSession` is the fetch → reconcile → commit loop, and it must be
      // byte-identical on both platforms: the normalized `SyncResponse` exists
      // precisely so that the ordering argument is made once.
      final String session = codeOnly(
        repoFile('lib/runtime/stride_session.dart'),
      );
      expect(session, isNot(contains('Platform.isIOS')));
      expect(session, isNot(contains('Platform.isAndroid')));
      expect(session, isNot(contains('HealthKit')));
      expect(session, isNot(contains('HKHealthStore')));
    });
  });

  // =========================================================================
  // Installability — the facts that decide whether a build can reach a phone
  // =========================================================================

  group('iOS build configuration', () {
    late String pbxproj;

    setUp(() {
      pbxproj = repoFile('ios/Runner.xcodeproj/project.pbxproj');
    });

    test('the entitlements file is actually wired into both configurations', () {
      // An entitlements file that no build configuration references is a file
      // that does nothing, and the failure is silent: the app builds, installs,
      // and is refused by HealthKit at runtime.
      expect(
        'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;'
            .allMatches(pbxproj)
            .length,
        greaterThanOrEqualTo(2),
        reason: 'Debug and Release must both carry the entitlements',
      );
    });

    test('the bundle identifier is stable and not a template', () {
      expect(
        pbxproj,
        contains('PRODUCT_BUNDLE_IDENTIFIER = com.projectstride.stride;'),
      );
      expect(pbxproj, isNot(contains('com.example')));
    });

    test('no signing team or certificate is committed', () {
      // A DEVELOPMENT_TEAM in the repository would be the owner's Apple team
      // identifier in a public repo, and it would break every other machine's
      // build. It is supplied in Xcode, per developer, which is why the
      // installation document walks through selecting one.
      expect(pbxproj, isNot(contains('DEVELOPMENT_TEAM = ')));
      expect(
        Directory('ios')
            .listSync(recursive: true)
            .whereType<File>()
            .where(
              (File f) =>
                  f.path.endsWith('.mobileprovision') ||
                  f.path.endsWith('.p12') ||
                  f.path.endsWith('.cer'),
            ),
        isEmpty,
        reason: 'signing material must never be committed',
      );
    });

    test('the deployment target matches the approved platform decision', () {
      // iOS 17, DECISIONS/0009. It bounds which iPhones can install at all, so
      // it is a fact the owner needs before plugging a phone in.
      expect(pbxproj, contains('IPHONEOS_DEPLOYMENT_TARGET = 17.0;'));
    });

    test('both plugins are registered with the iOS runner', () {
      // Registration is generated, and a plugin missing from it fails at
      // runtime as a MissingPluginException — on the device, not at compile.
      final String registrant = repoFile(
        'ios/Runner/GeneratedPluginRegistrant.m',
      );
      expect(registrant, contains('StrideHealthPlugin'));
      expect(registrant, contains('StrideSecureStorePlugin'));
    });
  });

  // =========================================================================
  // The unplugged device install — TECHNICAL/IOS_DEVICE_INSTALL.md
  //
  // A Flutter debug build is JIT and iOS refuses to launch it from the Home
  // Screen. The release workflow depends on a handful of repository facts that
  // no compile checks: the release configuration still includes Flutter's
  // generated settings, the per-machine signing team has somewhere to live
  // that is not the public repository, and the scripts the owner is told to
  // run actually exist. The entitlement, usage-string and background-mode
  // facts it also depends on are asserted above and are not repeated.
  // =========================================================================

  group('the device install workflow', () {
    // A line that sets DEVELOPMENT_TEAM to a LITERAL ten-character team id, in
    // xcconfig or shell form. Prose that names the setting does not match, and
    // neither does the script forwarding `$STRIDE_IOS_TEAM` from the
    // environment — that is the sanctioned way a team reaches a build.
    final RegExp assignsTeam = RegExp(
      r'^\s*(export\s+)?(FLUTTER_XCODE_)?DEVELOPMENT_TEAM\s*=\s*"?[A-Z0-9]{10}"?\s*;?\s*$',
      multiLine: true,
    );

    test('Debug and Release xcconfig include Flutter, then the local team', () {
      for (final String name in <String>['Debug', 'Release']) {
        final String xcconfig = repoFile('ios/Flutter/$name.xcconfig');
        // Flutter's build settings — without this include the Runner target
        // has no FLUTTER_ROOT, no build name, no target and the build fails
        // in a way that reads like a signing problem.
        expect(xcconfig, contains('#include "Generated.xcconfig"'));
        // OPTIONAL (#include?) so a machine without the file — CI, and any
        // clone that has never signed — builds exactly as before.
        expect(xcconfig, contains('#include? "Local.xcconfig"'));
        // The committed files ASSIGN no team. That is the whole point of the
        // indirection. Line-anchored: the comment naming the setting is not
        // the setting.
        expect(assignsTeam.hasMatch(xcconfig), isFalse, reason: name);
      }
    });

    test(
      'the local signing file is ignored, and only its example is tracked',
      () {
        // A tracked Local.xcconfig would put the owner's Apple team identifier
        // in a public repository (RULES G-8, MISTAKES M-08).
        final String gitignore = repoFile('.gitignore');
        // Trimmed: under `core.autocrlf=true` a Windows checkout reads CRLF.
        expect(
          gitignore.split('\n').map((String l) => l.trim()),
          contains('ios/Flutter/Local.xcconfig'),
        );
        final String example = repoFile('ios/Flutter/Local.xcconfig.example');
        expect(
          example,
          contains('DEVELOPMENT_TEAM = ABCDE12345'),
          reason: 'the example must carry the placeholder, never a real team',
        );
      },
    );

    test('the two owner scripts exist and are strict bash', () {
      for (final String path in <String>[
        'Scripts/ios/build-release-device.sh',
        'Scripts/ios/install-device.sh',
      ]) {
        final String script = repoFile(path);
        expect(script, startsWith('#!/usr/bin/env bash'), reason: path);
        expect(script, contains('set -euo pipefail'), reason: path);
        // No team identifier or device UDID may be written into a script; both
        // arrive through the environment (STRIDE_IOS_TEAM, STRIDE_IOS_DEVICE).
        expect(assignsTeam.hasMatch(script), isFalse, reason: path);
        expect(script, contains('STRIDE_IOS_DEVICE'), reason: path);
      }
      // The release script builds signed, never --no-codesign: that flag is
      // CI's compile-only build and its output cannot be installed.
      final String build = repoFile('Scripts/ios/build-release-device.sh');
      expect(build, contains('flutter build ios --release'));
      expect(
        RegExp(
          r'^\s*flutter build ios[^\n]*--no-codesign',
          multiLine: true,
        ).hasMatch(build),
        isFalse,
      );
    });

    test('the owner scripts are executable in git once tracked', () {
      // Windows checkouts do not carry the bit (core.fileMode=false), so the
      // mode is asked of the index. Untracked is reported, not passed: the
      // check goes live the moment the scripts are staged, and they must be
      // staged with `git add --chmod=+x`.
      for (final String path in <String>[
        'Scripts/ios/build-release-device.sh',
        'Scripts/ios/install-device.sh',
      ]) {
        final ProcessResult result = Process.runSync('git', <String>[
          'ls-files',
          '-s',
          '--',
          path,
        ]);
        if (result.exitCode != 0) {
          markTestSkipped('git is not available; mode not checked');
          return;
        }
        final String line = (result.stdout as String).trim();
        if (line.isEmpty) {
          markTestSkipped(
            '$path is not tracked yet; stage it with '
            'git add --chmod=+x so the mode is 100755',
          );
          continue;
        }
        expect(
          line,
          startsWith('100755'),
          reason: '$path must be executable in git (git add --chmod=+x)',
        );
      }
    });
  });
}
