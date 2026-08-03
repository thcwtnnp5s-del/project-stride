# F-06 Completion Report — device persistence, bootstrap, restart validation

**Status:** ✅ **COMPLETE AND CLOSED.**
**Date:** 2026-08-03
**Task:** F-06 — device persistence, bootstrap, and restart validation
**Head:** `2d20280`
**Final green CI run:** `30780992412` · **process-death run:** `30781003035`

> §9 recorded F-06 as blocked because GitHub Actions was refusing to start jobs
> for billing reasons. Making the repository public restored hosted runners, and
> both workflows were re-run against the final commit with **no code changes**.
> Both are green. **See §10 for the full verification addendum** — that is the
> authoritative closure record.

---

## 1. What F-06 delivered

| Area | Outcome |
|---|---|
| Real filesystem persistence | `stride_storage` adapters over a real directory, conformance-tested |
| Typed contention | `load`, `commit`, `compact`, `eraseAll` all return typed results; nothing throws for an expected lock timeout |
| Erase / reset protocol | Durable intent, ordered deletion, verified at every step, never automatic |
| Identity-first provisioning | Seven-step new-game protocol with recoverable orphan handling |
| Concurrency | Single-writer-isolate model, three layers, mechanically enforced |
| iOS identity | Keychain, `AfterFirstUnlockThisDeviceOnly`, add-only, non-synchronizable |
| Backup exclusion | Launch sweep **plus** per-write re-application at seven sites |
| Restart validation | Android process-death harness, per-phase instrumented |

**540 automated Dart tests, zero skipped**, plus Swift and Kotlin suites in CI.

| Suite | Tests |
|---|---|
| `stride_core` | 357 |
| `stride_storage` | 108 |
| `stride_secure_store` (Dart) | 31 |
| App (`flutter test`) | 27 |
| `stride_health` | 17 |
| `stride_secure_store` (Swift, simulator) | 40 |

---

## 2. The rulings, and how each was met

### 2.1 Typed busy results

`SaveRepository._serialized` now **requires** `onBusy`. The old
`StateError('the save is in use by another process')` path and the comment
justifying it were deleted rather than left as a dead guard.

- `LoadRefusal.storageBusy`, `LoadRefusal.resetIncomplete`
- `CompactionRefusal.storageBusy`
- `CommitRefusal.storageBusy` (existing), `CommitRefusal.resetInProgress`
- `EraseOutcome` / `EraseComplete` / `EraseRefused` / `EraseRefusal`
- `BootstrapBlockReason.storageBusy` — distinct from `storageUnavailable`,
  because the storage *is* available and in use

A busy save can no longer reach the player as "Stride could not read its save
files", which is not what happened.

### 2.2 The erase / reset protocol

`eraseAll` takes the lock, records a **durable reset intent before deleting
anything**, deletes both slots, reads them back to prove they are gone, then
deletes the journal, then proves that too.

The intent is a marker line written **into the ledger journal**. That choice is
load-bearing: the journal's erase is the last step, so clearing the intent and
finishing the reset are the same act, and no new file or port method was needed.
It deliberately does not parse as a `JournalRecord`, so no replay path can adopt
it.

Without the intent, a death between the last slot delete and the journal delete
leaves a directory whose *contents* are identical to a fresh install, and the
next launch is entitled to conclude exactly that. With it, the next load refuses
`resetIncomplete` and the reset can be re-run to completion.

`ResetCoordinator` sequences lock → snapshots → journal → verify → **identity
last**. The ordering is the argument:

| Death mid-reset leaves | Recoverable? |
|---|---|
| save+journal deleted, identity remains | **yes** — next launch clears the orphan and reprovisions |
| identity deleted, save remains | **no** — `originIdentityMissing`, permanently, caused by us |

Reset is reachable only from a deliberate player action. Nothing erases as
automatic recovery.

### 2.3 Identity-first provisioning with recoverable orphan handling

The seven-step protocol is implemented, including step 6 — **reload and validate
the snapshot before reporting ready**. A new game that committed but does not
read back is not ready.

Recovery rules, all implemented and tested:

| Condition | Behaviour |
|---|---|
| identity + **no** save or journal artifacts at all | interrupted first-save orphan → delete and reprovision |
| identity + valid matching save | resume |
| identity + truncated / corrupt / malformed / busy / unreadable | **fail closed**, touch nothing |
| save + identity missing | `originIdentityMissing` |
| save identity mismatch | `originIdentityMismatch` |
| storage busy | typed blocked result, never "no save" |
| failed first commit | cleanup *attempted* |
| failed cleanup | recoverable orphan, typed refusal, not a crash |

The old C4 test asserted the opposite — that an identity can never remain after
an interrupted first commit — which the ruling disallows. It was **replaced**
with six tests of the observable rules. Its claim that the app writes a
salt-less identity was checked and is **false**; a test now proves it.

### 2.4 Single-writer-isolate concurrency — `DECISIONS/0013`

Three layers: path-keyed in-isolate mutex, OS advisory lock across processes,
compare-and-swap. **None serializes two isolates**, and none is intended to.

The persistence-owner prototype was **removed** rather than wired. Full reasoning
in `DECISIONS/0013`; the short version is that wiring it would have deleted
working controls (the per-write exclusion hook, the salt fail-closed check) to
close a race the app does not have, and leaving it in place meant shipping dead
code that documentation described as a protection layer.

Enforced by `Scripts/check-single-writer.sh`: six approved construction sites in
two files, production source only, plus a `--self-test` that injects three
violations and asserts each is rejected.

### 2.5 Backup exclusion

The invariant, per the owner's ruling:

> **After every persistence operation completes, the final sensitive file is
> excluded from backup.**

`NSURLIsExcludedFromBackupKey` belongs to the filesystem **node**, not the path.
The launch sweep alone was insufficient in three ways, one of which was a
regression rather than a gap:

| When | Effect |
|---|---|
| first commit | slot created after the sweep → never excluded |
| first append | journal created after the sweep → never excluded |
| **every compaction** | `replaceLines` renames a sidecar over the journal → the journal **loses** an exclusion it had |

Now re-applied at seven sites: snapshot write, journal append, both halves of the
compaction swap, both identity writes, and lock creation.

Platform behaviour is **recorded as observation, not asserted as product
behaviour**: on the iOS 26 simulator, `FileManager.replaceItemAt` *preserves*
the attribute, while a rename over the top *drops* it. The tests assert the end
state after our adapter re-applies, which is the thing we guarantee.

---

## 3. CI evidence

| Run | Commit | Workflow | Result |
|---|---|---|---|
| `30769049772` | `9fbb66c` | CI | Dart core ✓ 2m14s · Pigeon ✓ · **Android ✓ 8m37s** · iOS ✗ |
| `30772473910` | `b7d386e` | Android process death | **success**, 11m16s |
| `30773715793` | `d5c798f` | CI | **success — all four jobs**, 25m8s |
| `30775782514` | `0084802` | CI | **not started — billing** |

Superseded red runs, retained because they are the evidence for §5:
`30764020005`, `30764486314`, `30765692979`, `30765745272`, `30766062786`,
`30767931205`, `30767934429`.

---

## 4. What is proven, and where

| Claim | Evidence |
|---|---|
| Linux POSIX lock semantics | `30769049772`, Dart core ✓ |
| Android debug build + Kotlin tests | `30769049772`, Android ✓ |
| Swift compiles | `30769049772` and `30773715793`, three compile steps ✓ |
| Real simulator Keychain behaviour | `30773715793`, 40 Swift tests ✓ |
| A rename strips the backup exclusion | `30769049772` + `30771670303`, `testARenameOverTheTopDropsTheExclusion` ✓ |
| Android process death and resume | `30772473910` ✓, verdict `"result":"PASS"`, pid 2526 → 2929 |

### 4.1 Not proven, and not provable here

- **That Apple omits a `ThisDeviceOnly` Keychain item from a real iCloud backup,
  and does not restore it onto a second device.** No runner can perform a backup
  and restore onto a second physical device. This is the behaviour the entire
  device-bound identity design depends on, and it is **relied upon, not
  verified**. A green suite must never be quoted as evidence for it.
- **That `NSURLIsExcludedFromBackupKey` is honoured by iCloud or Finder.** Same
  reason.
- **A locked-device Keychain read** (`errSecInteractionNotAllowed`). A simulator
  is never locked.
- **Survival of sudden power loss.** `force-stop` kills a process; it does not
  drop the page cache or make a storage controller ignore a barrier.

Both iCloud items need two physical iPhones, an iCloud account, and a real backup
and restore.

---

## 5. Defects found during F-06

Ordered by how badly they would have shipped.

### 5.1 The OS lock excluded nothing within a process, on the shipping platform

CI run `30767931205` was the first time four of the storage test files executed
on Linux: **94 passed, 11 failed**, against 105/105 on Windows.

```
S1 same-process exclusion: a second FileTransactionLock over the same file is refused
Expected: null      Actual: <Instance of '_FileLockHandle'>
```

Both acquirers are in **one isolate**. `fcntl` ownership is the process, so the
lock is a no-op against yourself — worse than the standing ruling, which said the
hole was cross-isolate. Downstream: `totalGranted` of 7 where 0 was required
(grant-accounting divergence), `journalAppendFailed` instead of a clean CAS
refusal, `SaveLoaded` where `LoadRefused` was required, and the `-1` journal-fork
sentinel.

Windows passed all eleven because `LockFileEx` is per-handle — the opposite
semantics. **A green Windows run was never evidence for this property**, and the
suite had been read as verification for its entire life.

Closed by the path-keyed in-isolate mutex, taken before the `open()` and released
after the close, because on POSIX closing any descriptor drops the whole
process's locks on that file.

### 5.2 Two guards that could not fail

Both found by a closure critic that mutated source and watched a green suite stay
green.

1. **The "no automatic recovery erases" scan** matched `\.eraseAll\s*\(` — it
   required a receiver dot, so a bare self-call inside `SaveRepository`, the
   likeliest place for the defect, was invisible. Injecting
   `repairByWiping() async { await eraseAll(); }` kept it green.
2. **The backup-exclusion guard counted call sites.** Deleting the real
   snapshot-slot site and adding `reapplyExclusion?.call(<String>[])` as a decoy
   left it printing "OK", exit 0, naming "snapshot writes" as covered.

Both now anchor each site to the write it must follow. **Fixing the second
exposed the same defect in the fix**: the post-rename check ran off the end of
`replaceLines` and found the identity-write site 200 lines later, so deleting the
post-rename call still passed. Bounded to the method body; all seven sites then
verified to fail individually.

`Scripts/check-single-writer.sh` was written with this history in mind and ships
with a mutation self-test.

### 5.3 The backup exclusion was a launch sweep only

See §2.5. The compaction case is a regression, not a gap: the journal *was*
protected, and routine maintenance silently unprotected it.

### 5.4 CI was red on every F-06 commit, for two unrelated reasons

- `closure_probes_test.dart` was committed unformatted.
- "Pigeon bindings are stale" against an **unchanged contract**. `pigeon` is
  pinned exactly; the formatter it generates through is a floating transitive
  dependency, and `pubspec.lock` was gitignored for both plugin packages citing
  guidance meant for *published* libraries. Diff-checked codegen must be
  reproducible, so those locks are now committed.

Because the format check runs before the storage tests **in the same job**, the
storage suite never executed on Linux while this was true. That is how 5.1
survived five commits.

### 5.5 The Keychain tests could not run at all

Every Keychain-touching test failed; every pure-logic test passed. The cause,
printed rather than inferred:

```
SecItemCopyMatching with nothing stored returned -34018 errSecMissingEntitlement,
expected -25300 errSecItemNotFound.
```

`CODE_SIGNING_ALLOWED=NO` left the test host unsigned, so iOS refused every
`SecItem*` call before any logic ran. Fixed by ad-hoc signing the **test** step
only. Nothing was mocked, skipped, or weakened.

Obtaining that number took three attempts: Xcode 26.6 writes no assertion text to
`xcodebuild` stdout and a test-process `print()` never leaves the simulator, so
the messages exist only in the `.xcresult`. Hence
`packages/stride_secure_store/tool/xcresult-failures.sh`.

Two more guards were lying here: the suite-presence check greped a string this
toolchain never emits, and the failure grep matched `failed` then `tail -60`, so
detail was crowded out. That is why run `30769049772` diagnosed nothing.

### 5.6 The Android process-death job was hiding its own cause

It died at the 45-minute job timeout. Per-phase instrumentation found it in
seconds:

```
FATAL | Not enough space to create userdata partition.
        Available: 2124.99 MB, need 7372.80 MB.
```

The emulator died 0.2 s after launch and the action then polled a nonexistent
device for ten minutes. Fixed with a reclaim-disk step and a pre-flight assertion
that fails immediately with the real reason. Harness total is now **52 s**.

### 5.7 Smaller findings

- A test asserted that a string literal *declared inside the test* contained no
  `update` — it would have stayed green through an `update` method added to the
  real port.
- Four files stated Apple's backup/restore behaviour as verified fact.
- A comment cited `test/reset_protocol_test.dart`, which does not exist.
- `perWriteExclusionFailures` had zero readers while its doc claimed failures
  were "surfaced".
- `FileIdentityStore` threw on the salt-less record the core-facing port writes
  by design — latent, one call site from being a permanent next-launch failure.
- `TECHNICAL/PERSISTENCE_CONCURRENCY.md` asserted Linux evidence that did not
  exist when it was written.

---

## 6. Known risks carried forward

- **Two 50 ms lock deadlines in `concurrency_test.dart`** (lines ~793, ~831).
  They are deliberate — *"short enough that a lingering hold cannot pass by
  luck"* — and did not flake in six local runs or on Linux CI. They are a
  flake risk on a loaded runner. Recorded rather than silently retuned. A third
  such deadline in `closure_probes_test.dart` S6 **did** flake under full
  `verify.sh` load and was bounded generously; its assertion is unchanged.
- **Windows-green is weak evidence** for anything lock-shaped. Linux is the
  signal. This is now stated in the test file, the technical doc, and CI.

---

## 7. Files of record

| Document | Purpose |
|---|---|
| `DECISIONS/0013_SINGLE_WRITER_PERSISTENCE.md` | The concurrency model and the binding rule |
| `TECHNICAL/PERSISTENCE_CONCURRENCY.md` | The three layers, what each does not cover, and the removed prototype's design findings |
| `packages/stride_secure_store/BACKUP_EXCLUSION_CONTRACT.md` | The invariant, the platform observations, and the call sites |
| `packages/stride_storage/test/linux_lock_semantics_test.dart` | Named evidence for the four lock properties |
| `Scripts/check-single-writer.sh` | Enforcement of the binding rule, with mutation self-test |

---

## 8. Follow-up for S-01

- **S-01 must design and validate a real persistence coordinator before enabling
  any Health Connect background writer.** It must carry the per-write
  backup-exclusion hook and `originSaltFingerprint` across the port — the
  prototype did neither.
- It will need an extracted repository interface in `stride_core` that
  `BootstrapCoordinator` can be typed against; `SaveRepository` is a `final
  class` today.
- V-02b still needs physical devices for real health data, background sync, and
  cross-adapter equivalence.

---

## 9. Why this is not signed off

The owner's closure gate requires: Linux green, Android green, real Keychain
behaviour understood, final backup exclusions verified, a recorded process-death
run, no skipped tests, `/loop` to two clean passes, and **a final CI run**.

Everything except the last is satisfied — but each was proven against an
**earlier commit**, not against the final tree.

| Gate | Status |
|---|---|
| Linux green | ✓ at `9fbb66c` / `d5c798f` |
| Android green | ✓ at `9fbb66c` |
| Keychain behaviour understood | ✓ at `d5c798f`, with the numeric OSStatus |
| Final backup exclusions verified | ✓ at `d5c798f` |
| Process-death recorded run | ✓ `30772473910` at `b7d386e` |
| No skipped tests | ✓ 540 tests, zero skips |
| `/loop` two clean passes | ✓ on `0084802`, from cleared temp and build state |
| **Final CI run** | ✗ **blocked** |

`30775782514` on `0084802` did not start:

> The job was not started because recent account payments have failed or your
> spending limit needs to be increased.

**The final tree has never been compiled on macOS or tested on Linux.** Two
commits — `bb77599` and `0084802` — carry the owner-isolate removal, the new
lock-semantics test, the single-writer guard, and the CI rewiring, and none of it
has run anywhere but Windows. Given §5.1, Windows-only verification is precisely
the evidence standard that let the worst defect in this task survive five
commits.

**Required to close:** resolve GitHub billing, re-run CI on `master`, and re-run
the Android process-death workflow against the final tree. If both are green,
F-06 closes with no further code changes expected.

---

# 10. Final verification addendum — F-06 CLOSED

**Date:** 2026-08-03
**Commit under test:** `2d20280` (`master`)
**Blocker resolution:** the repository was made **public**, so GitHub-hosted
runners became available. No code changed between §9 and this addendum.

## 10.1 Workflow runs

| Workflow | Run ID | Result | Duration |
|---|---|---|---|
| CI | **`30780992412`** | ✅ **success** | — |
| Android process death | **`30781003035`** | ✅ **success** | 6m40s |

| Job | Job ID | Result | Duration |
|---|---|---|---|
| Dart core (Linux) | `91585441087` | ✅ | 1m55s |
| Pigeon bindings | `91585441118` | ✅ | 30s |
| Android | `91585711838` | ✅ | 5m6s |
| iOS compile + simulator tests | `91585711848` | ✅ | 16m55s |
| force-stop and resume | `91585470651` | ✅ | 6m40s |

**No billing or runner refusal occurred** — `grep -c "spending limit|payments
have failed|job was not started"` returns **0** across all three job logs.

## 10.2 Dart / core on Linux

| Requirement | Evidence |
|---|---|
| `stride_storage` executed on Linux | ✅ **108 tests passed** in the `stride_storage analyze and test` step |
| `linux_lock_semantics_test.dart` executed | ✅ all 6 cases ran in the *concurrency proofs (Linux, no skips allowed)* step |
| Final test count | ✅ **540**: 357 core + 108 storage + 27 app + 17 health + 31 secure-store |
| Zero skipped or quarantined | ✅ — the 5 lines matching the skip grep are one GitHub action's own cache step (`outcome=skipped`) and four lines of the guard's **own echoed command text**. No test skipped |
| Background-construction guard passed | ✅ `single-writer: OK` |
| Guard mutation self-tests passed | ✅ `single-writer: self-test OK -- all 3 injected violations were rejected` |
| Storage privacy / backup-exclusion guard | ✅ `storage privacy: OK` |

### The POSIX finding, executed on Linux

The caveat probe printed, on ubuntu:

```
>> raw kernel lock, second ISOLATE, linux: acquired
```

**A second isolate was granted a lock the first still held.** On Windows the same
probe reports `refused`. This is the finding that justifies the entire
single-writer model, and it is now recorded from the shipping platform rather
than argued. In the same run:

```
>> second same-isolate acquire: refused      (the path-keyed mutex holds)
>> journal transaction ids: [2]              (no fork)
>> holder still alive: 8 heartbeats          (cross-process refusal is real)
>> after the kill: Instance of 'CommitDurable'   (kernel reclaims on death)
>> stale commit -> Instance of 'CommitRefused'   (CAS rejects stale state)
```

## 10.3 Pigeon bindings

✅ Both surfaces regenerate byte-identical — the lockfile pinning from `9fbb66c`
holds. This job had failed on every F-06 commit before `9fbb66c`.

## 10.4 Android

✅ Application debug APK, health-plugin example APK, and the Kotlin adapter unit
tests all built and passed.

## 10.5 iOS compile and simulator tests

All four suites executed against a **real simulator Keychain** on
`iPhone 17 Pro`, **38 cases, 0 failed**:

| Suite | Cases | Failed |
|---|---|---|
| `SecureStoreTests` | 16 | 0 |
| `BackupExclusionTests` | 14 | 0 |
| `SecureStoreAdapterTests` | 7 | 0 |
| `KeychainEntitlementProbe` | 1 | 0 |

**The suites genuinely executed** — the step enforces this, requiring each named
suite to appear with ≥1 executed case, zero failed case lines, and
`** TEST SUCCEEDED **`.

**The Keychain calls were genuinely behavioural.**
`KeychainEntitlementProbe.testTheTestHostCanReachTheKeychain()` passed, which is
the guard against the `errSecMissingEntitlement (-34018)` state where every
`SecItem*` call fails before any logic runs. That probe existing and passing is
what distinguishes this from the vacuous green a mocked Keychain would give.

| Requirement | Test | Result |
|---|---|---|
| `AfterFirstUnlockThisDeviceOnly` | `testStoredItemIsAfterFirstUnlockThisDeviceOnly` | ✅ |
| — pinned value matches Dart | `testTheAccessibilityConstantMatchesTheValuePinnedInDart` | ✅ |
| Synchronization absent or disabled | `testStoredItemIsNotSynchronizable` | ✅ |
| — no operation ever creates one | `testNoOperationEverProducesASynchronizableItem` | ✅ |
| — a stray one is swept on delete | `testDeleteSweepsUpAStraySynchronizableItem` | ✅ |
| Create / read / delete behaviour | `testCreateThenRead`, `testDeleteRemovesTheItem`, `testReadWithNothingStoredIsAbsentNotAnError`, `testItemSurvivesANewStoreInstance` | ✅ |
| No overwrite path | `testSecondCreateDoesNotOverwriteTheFirst` | ✅ |
| Never overwritten after a read failure | `testACreateAfterAFailedReadDoesNotClobberTheStoredItem`, `testAFailedReadFollowedByCreateLeavesTheAccessibilityAlone` | ✅ |
| Unreadable ≠ absent | `testAPresentButUnreadableItemIsUnavailableNotAbsent` | ✅ |
| A read never creates | `testReadingAnEmptyStoreCreatesNothing` | ✅ |

### Backup-exclusion postconditions

The invariant — *after every persistence operation completes, the final
sensitive file is excluded from backup* — verified for each operation:

| Operation | Test | Result |
|---|---|---|
| **create** | `testAFileCreatedAfterTheSweepIsNotExcludedUntilReapplied` | ✅ |
| **write** (atomic) | `testAnAtomicWriteDropsTheExclusion` (platform observation) | ✅ |
| **write** (in place) | `testTruncatingInPlaceKeepsTheExclusion` (counter-case) | ✅ |
| **rename** — this **is** the compaction case (`replaceLines` renames the sidecar over the journal) | `testARenameOverTheTopDropsTheExclusion` | ✅ |
| **replacement** | `testTheFileIsExcludedAfterAReplaceItemAt` — asserts the **end state**, records that `replaceItemAt` preserves | ✅ |
| directory recreated | `testExclusionIsReappliedAfterTheDirectoryIsRecreated` | ✅ |
| every declared file covered | `testEveryDeclaredFileIsExcluded` | ✅ |
| launch sweep and per-write are the same code | `testTheLaunchSweepAndThePerWriteCallAreTheSameCode` | ✅ |

*Note on compaction:* there is no XCTest literally named "compaction", because
compaction **is** the rename-over-the-top operation at the Swift level. The Dart
side is covered separately: `Scripts/check-backup-exclusions.sh` verifies the
re-apply call exists both before and after `journalSidecar.rename`, positionally
and bounded to the method body, and every one of the seven call sites was proven
to fail the guard individually when removed.

## 10.6 Workflow permissions

✅ **No workflow required write permissions.** Every job log reports:

```
GITHUB_TOKEN Permissions
  Contents: read
  Metadata: read
```

## 10.7 Android process-death

| Item | Value |
|---|---|
| **Run ID** | **`30781003035`** (job `91585470651`) |
| **Verdict** | `{"phase":"verified","result":"PASS", ...}` |
| **Initial process PID** | **2432** |
| **First process terminated** | ✅ `am force-stop`, phase completed in 1s |
| **Replacement process PID** | **2782** — a different process, so the relaunch is genuinely new |
| **Recovered snapshot generation** | **3** |
| **totalGranted** | **1041** (seeded `expectedTotal: 1041` — exact match) |
| **Replayed grant amount** | **0** — the snapshot was current; nothing above the watermark |
| **Selected snapshot slot** | **`b`** |
| **Journal recovery result** | `"repairs":[]`, `"detail":[]` — clean, nothing to repair |
| **Cursor / checkpoint disposition** | `sync=0; wm=null; recovery=idle` — no health source consumed, so no cursor to advance and the watermark stays null. Correct for a synthetic seed |
| **Verdict written by the replacement process** | ✅ — the `verified` marker is emitted at `03:14:15`, after `pid before kill: 2432` at `03:14:08` and after the relaunch; verdict-retrieval is the phase following relaunch |
| **Completed without timeout** | ✅ 6m40s against a 60-minute backstop; harness total **25s** |
| Lineage | `saveId qGVjhW5ZfzqGC6Ck`, `saltFingerprint 23ca0a65ecc357c6` |

### Phase-by-phase timing

| Phase | Seconds | Status |
|---|---|---|
| emulator-and-boot | 2 | ok |
| installation | 6 | ok |
| clear-app-data | 1 | ok |
| first-launch | 0 | ok |
| save-seeding | 8 | ok |
| force-stop | 1 | ok |
| relaunch | 0 | ok |
| verdict-retrieval | 7 | ok |
| shutdown | 0 | ok |
| **TOTAL** | **25** | |

Every phase individually bounded and reported. The 45-minute timeout that
previously masked an emulator disk-space failure is gone as a diagnostic
problem: each phase now fails in seconds with its own message.

## 10.8 Closure gate — all satisfied

| Gate | Status |
|---|---|
| Linux green | ✅ `30780992412`, on `2d20280` |
| Android green | ✅ `30780992412` |
| Real Keychain simulator behaviour understood | ✅ 38 cases, entitlement probe passing |
| Final backup exclusions verified | ✅ create, write, rename, replacement, compaction |
| Process-death recorded run | ✅ `30781003035` |
| No skipped or quarantined tests | ✅ 540 Dart, 0 skips |
| `/loop` two clean passes | ✅ on the final tree |
| Final CI run | ✅ **green on the exact commit** |

Totals: **540 Dart tests, 38 Swift simulator tests, 5 Kotlin tests.**

## ✅ F-06 is COMPLETE and CLOSED.

### Still unproven, and still unprovable

Unchanged by this run, and restated so it is never mistaken for settled:

- That Apple omits a `ThisDeviceOnly` Keychain item from a **real iCloud backup**
  and does not restore it onto a second device.
- That `NSURLIsExcludedFromBackupKey` is honoured by iCloud or Finder.
- A locked-device Keychain read (`errSecInteractionNotAllowed`).
- Survival of sudden power loss.

The first two need two physical iPhones, an iCloud account, and a real backup and
restore. **A green suite is not evidence for any of them.**
