# Public Repository Readiness Report — Project Stride

**Date:** 2026-08-03
**Repository:** `thcwtnnp5s-del/project-stride` (currently **PRIVATE**)
**Audited head:** `991c716` (`master`)
**Audit type:** read-only audit (§1–§6), then owner-directed remediation (§8).
**No Git history was rewritten at any point.**

## Recommendation: ✅ **PASS for public visibility**

**No secrets, credentials, keys, or private data were found in the tree or in
any reachable commit.** The audit raised two blockers; both are resolved by
owner decision and remediation — see §8.

| # | Original blocker | Resolution |
|---|---|---|
| R-1 | Commit author email in all 48 commits | **Owner accepted the exposure.** No history rewrite performed |
| R-2 | No licence anywhere | **All-rights-reserved / source-available policy selected.** `COPYRIGHT.md` added; the three placeholder licence files removed |

§3 through §6 below are preserved as the original audit record. §5's optional
items were addressed or consciously accepted; none blocks publication.

---

## 1. Scanners and commands used

No secret-scanning tool was installed on this machine (`gitleaks`, `trufflehog`,
`detect-secrets`, `ggshield`, `git-secrets` all absent), so a scanner was written
for this audit and run over the full object database.

### 1.1 Pattern + entropy scan (approach 1)

`scan-secrets.js` — Node 24, read-only, invokes only `git cat-file`.

```bash
node scan-secrets.js .
```

Enumeration: `git rev-list --objects --all --reflog` — every blob reachable from
**any ref or the reflog**, not just `HEAD`.

25 credential-shape patterns: AWS key id and secret, GitHub PAT / OAuth /
user-to-server / server-to-server / refresh / fine-grained, Google API key and
OAuth client, Slack token and webhook, Stripe live key, Twilio SID, SendGrid,
npm, PyPI, `BEGIN … PRIVATE KEY` blocks, `BEGIN CERTIFICATE`, SSH authorized
keys, JWTs, Apple provisioning-profile UUID markers, Android keystore
credential keys, generic assigned secrets (`api_key=`, `password:` …),
connection strings carrying credentials, and `Bearer` literals.

Entropy: Shannon entropy over `[A-Za-z0-9+/=_-]{24,}` candidates; reported at
**≥ 4.5 bits/char and ≥ 32 chars**. Git SHAs and `sha256:` digests were excluded
as known-benign high-entropy values.

### 1.2 Manual review of sensitive types and directories (approach 2)

```bash
# sensitive filenames across all history
git rev-list --objects --all --reflog | grep -iE '\.(env|pem|key|p12|pfx|jks|
  keystore|mobileprovision|cer|crt|der|ppk|asc|gpg|kdbx)$|id_rsa|id_ed25519|
  \.npmrc|\.netrc|credentials|google-services\.json|GoogleService-Info\.plist|\.p8$'

# content greps across every commit
git grep -hIioE '<pattern>' $(git rev-list --all --reflog) -- …

# unreachable objects
comm -13 <(git rev-list --all | sort) <(git rev-list --all --reflog | sort)

# authorship
git log --all --format='%an <%ae>' | sort | uniq -c

# remote-side state
gh api repos/thcwtnnp5s-del/project-stride/actions/runs
gh api repos/thcwtnnp5s-del/project-stride/actions/artifacts
gh api repos/thcwtnnp5s-del/project-stride/commits/<sha>
```

Manual inspection: all three `.github/workflows` files, `.gitignore`, every
`pubspec.yaml`, all `LICENSE` files, `README.md`, `AUDIO/AUDIO_ASSET_MANIFEST.md`,
`assets/content/v1/`, `packages/stride_core/test/fixtures/`, and visual review of
the only screenshot in the repository.

---

## 2. Scope of history examined

| | |
|---|---|
| Reachable commits | **48** |
| Reachable + reflog | **52** (4 unreachable — see F-5) |
| Branches | `master`, `fix/ios-simulator-keychain` (+ both remotes) |
| Objects enumerated | 1,204 |
| Blobs enumerated | 649 |
| Text blobs scanned | 629 |
| Binary blobs (skipped by content scan, reviewed by type) | 20 |
| Bytes scanned | 5,673,075 |

**Every commit on every branch, plus unreachable reflog objects, was examined.**
Not only `HEAD`.

---

## 3. Findings

### 3.1 Secrets and credentials — **CLEAN**

| Check | Result |
|---|---|
| Pattern findings (25 rules, 629 blobs) | **0** |
| Entropy findings ≥4.5 bits/char | 32, **all false positives** — every one is a long file path, e.g. `packages/stride_secure_store/BACKUP_EXCLUSION_CONTRACT.md` (H=4.67) and `FLUTTER_ROOT/packages/flutter_tools/bin/xcode_backend.sh` (H=4.59) |
| Sensitive filenames in history (`.env`, `.pem`, `.p12`, `.jks`, `.keystore`, `.mobileprovision`, `id_rsa`, …) | **0 matches** |
| Apple signing certificates / provisioning profiles | **none** — CI uses `--no-codesign` and ad-hoc `CODE_SIGN_IDENTITY=-` |
| Android keystores | **none** — debug signing only, no keystore, no secrets |
| GitHub authentication material | **none** |
| Service credentials (`google-services.json`, `GoogleService-Info.plist`, service accounts) | **none** |
| Real emails in file content | only `email@example.com` (43) and `noreply@example.com` (11) — placeholders |

`.gitignore` correctly excludes `.env`, `.env.*`, `**/android/local.properties`,
`**/ios/Flutter/Generated.xcconfig`, `.flutter-plugins-dependencies`, and
`.idea/`. Those files exist on disk containing local paths and are **not
tracked** — verified with `git check-ignore`.

### 3.2 Personal data — **CLEAN except R-1 and F-1**

| Check | Result |
|---|---|
| Raw health data | **none.** No step data, no HealthKit/Health Connect payloads. `HealthKitStepStore` and `HealthConnectAdapter` are shells; the ledger fixtures are synthetic |
| Native device identifiers | **0 matches** for `IDFV`, `identifierForVendor`, `ANDROID_ID`, `Settings.Secure`, `advertisingId`, `IMEI`, `serialNumber`, `deviceId`, MAC |
| Phone numbers | none — numeric matches are version strings, epoch timestamps and CI run ids |
| Street addresses / postcodes | none — matches were table rows such as `A-09 \| No visual identity` |
| Screenshot content | `MILESTONES/evidence/m2_android_emulator.png` (43 KB) reviewed visually: emulator frame showing the app placeholder, clock `10:34`, generic status icons. **No personal context** |

The project's own privacy posture is unusually strong and worth noting: origin
identifiers are pseudonymised behind a salt that never enters the core, a static
guard forbids interpolated storage paths, and a privacy audit suite asserts that
diagnostics carry no health-derived values.

### 3.3 Third-party material and licensing

**Dependencies** — all first-party Dart/Flutter, all BSD-3-Clause:

| Package | Where | Copyright |
|---|---|---|
| `flutter`, `flutter_test`, `integration_test` | app, plugins | The Flutter Authors — BSD-3 |
| `path_provider` | app | The Flutter Authors — BSD-3 |
| `pigeon` | `stride_health`, `stride_secure_store` (dev) | The Flutter Authors — BSD-3 |
| `flutter_lints` | app, plugins (dev) | The Flutter Authors — BSD-3 |
| `collection`, `meta`, `test`, `lints` | `stride_core`, `stride_storage` | Dart project authors — BSD-3 |

**No copyleft, no proprietary, no unlicensed vendored code.** No third-party
copyright headers or `SPDX-License-Identifier` lines appear in any source file;
the only `derived from` matches are prose about salts and fingerprints.

**Assets** — no audio, no fonts, no art beyond the stock Flutter launcher icons.
`AUDIO/AUDIO_ASSET_MANIFEST.md` is a manifest with no files yet, and it already
states the correct rule explicitly:

> **Any asset extracted from WalkScape, Melvor Idle, Old School RuneScape, or
> New World.** These are references for identity, never sources for files.
> Absolute.

Those four titles are referenced 26 times across design documents **by name
only**, as design comparators. Naming a commercial product is not infringement
and no text or asset from any of them appears in the repository.

`assets/content/v1/*.json` is original content authored for this project.

### 3.4 Workflow safety under public forks

| Check | Result |
|---|---|
| `pull_request_target` used anywhere | **No** ✅ |
| Triggers | `ci.yml`: `push` (master), `pull_request`, `workflow_dispatch`. `android-process-death.yml`: `workflow_dispatch` only |
| Secrets referenced in workflows | **None** — the only match is a comment saying "No keystore, no secrets" |
| Self-hosted runners | **None** ✅ |
| `permissions:` declared | **None anywhere** ⚠️ — see F-2 |
| Untrusted code execution on fork PRs | `pull_request` runs fork code with a read-only token and no secrets, which is the safe default |

There is no script-injection surface: no workflow interpolates
`github.event.*` attacker-controlled fields into a `run:` block. The only
`inputs` use is `api_level` on a `workflow_dispatch`, which only a collaborator
can trigger.

---

## 4. Required remediation (blocking)

### R-1 — Commit author email is exposed in all 48 commits — **HIGH**

Every commit is authored and committed by:

```
Studio Stride <rob.hathaway@outlook.com>
```

The address appears **only in commit metadata** — never in file content, never in
a commit message. But `git log` on a public repository exposes it to anyone,
including automated harvesters.

This is the one finding that is **irreversible on publication**. Rewriting
history after the fact does not retract what was already cloned or indexed.

**Options, owner's choice:**

1. **Accept it.** Legitimate — many maintainers publish under a real address.
2. **Use a GitHub `noreply` address** (`<id>+<user>@users.noreply.github.com`),
   rewrite the 48 commits before publishing, and set `user.email` locally so new
   commits follow. This is the usual choice and is clean because the repository
   has a single author and no external clones.
3. **Use a project alias** (e.g. `studio@…` on a domain you control).

Whichever is chosen, also set the GitHub account's *"Keep my email address
private"* and *"Block command line pushes that expose my email"* settings.

### R-2 — No licence — **HIGH**

- **No `LICENSE` file at the repository root.**
- The three package licences are unmodified Flutter template stubs containing
  exactly `TODO: Add your license here.` (30 bytes each):
  `packages/stride_core/LICENSE`, `packages/stride_health/LICENSE`,
  `packages/stride_secure_store/LICENSE`.
- GitHub reports `licenseInfo: null`.

Published without a licence, the work is **all rights reserved by default**: no
one may legally copy, modify, fork, or contribute, and a `TODO` stub is worse
than nothing because it implies a licence exists.

**Recommended split, given this is a game:**

| What | Recommendation | Why |
|---|---|---|
| **Code** (`lib/`, `packages/`, `Scripts/`, workflows) | **MIT** or **Apache-2.0** | MIT is shortest and most permissive. Apache-2.0 adds an explicit patent grant and a `NOTICE` mechanism — preferable if you ever want contributions from strangers. Either is compatible with the BSD-3 dependency tree |
| **Design documents** (`GAME_BIBLE/`, `DECISIONS/`, `AGENTS/`, reports) | **CC BY 4.0**, or leave all-rights-reserved | These are the creative heart of the project. Publishing them under a permissive code licence lets anyone ship your design |
| **Future art / audio / content** (`assets/`, `AUDIO/`) | **All rights reserved**, or CC BY-NC-ND | Game assets are the one thing you almost certainly do not want freely redistributable. Reserve them explicitly and separately |

The usual mechanism is a root `LICENSE` (code), a `LICENSE-DOCS` or a licence
section in `README.md` for documents and assets, and per-package `LICENSE` files
replaced with the real text. **Decide before publishing** — relicensing after
third parties have forked is impractical.

---

## 5. Optional cleanup (non-blocking)

### F-1 — Local Windows username in two tracked files — LOW

`jwspa` appears in exactly **two tracked files**, 7 times total:

| File | Occurrences |
|---|---|
| `TOOLCHAIN_REPORT_WINDOWS.md` | 6 — e.g. `C:\Users\jwspa\dev\flutter`, `ANDROID_HOME = C:/Users/jwspa/dev/android-sdk` |
| `PROJECT_STATE.md` | 1 — `Flutter ✅ 3.44.8 at C:\Users\jwspa\dev\flutter` |

All other occurrences (280 in `C:\Users\jwspa`, 47 in `/Users/jwspa`) are in
**gitignored, untracked** generated files — `local.properties`,
`Generated.xcconfig`, `.flutter-plugins-dependencies`, `.idea/…` — and will not
be published. Verified with `git check-ignore`.

A Windows account name is mildly identifying and reveals local directory
structure. Replacing with `C:\Users\<you>\dev\…` costs nothing. **Note this also
exists in history**, so a full scrub requires the same rewrite as R-1 — if you do
R-1 option 2, fix this in the same pass.

### F-2 — Workflows declare no `permissions:` — MEDIUM

Neither workflow sets `permissions`, so both inherit the repository default. On a
public repository the default token for fork PRs is read-only, but relying on a
repository-level setting rather than declaring intent is fragile.

Add at workflow level:

```yaml
permissions:
  contents: read
```

Neither workflow writes to the repository, creates releases, comments on PRs, or
publishes packages, so `contents: read` is sufficient for both. This is
least-privilege made explicit rather than inherited.

### F-3 — 36 workflow runs and ~20 unexpired artifacts become public — MEDIUM

Making a repository public makes its **entire Actions history** — logs and
artifacts — publicly readable.

| Artifact | Count | Size each |
|---|---|---|
| `stride-debug-apk` | ~17 | 68–72 MB |
| `secure-store-test-output` | 3 | 0.4–89 MB |

I reviewed the logs during F-06 debugging. They contain runner absolute paths,
simulator device names, an Android emulator disk-space error, and test output —
**nothing personal and no credentials.** The `.xcresult` bundles contain
simulator Keychain test data, all synthetic.

**Recommendation:** delete the artifacts before publishing anyway. They are
~1.2 GB of stale debug APKs with no archival value, they count against storage
quota, and pruning them removes an entire category of "what's in there?"
uncertainty. Logs may be left; if you would rather not publish the debugging
history at all, delete the runs too.

*(Note: the account currently cannot start new Actions runs — see
`F06_COMPLETION_REPORT.md` §9. That is unrelated to publication readiness, but
F-06 cannot close until it is resolved.)*

### F-4 — Repository has no description, no `SECURITY.md`, no `CONTRIBUTING.md` — LOW

`description` is empty and there is no issue-triage or contribution guidance.
Issues are enabled. Once public, unsolicited issues and PRs become possible; a
short `CONTRIBUTING.md` saying whether contributions are wanted at all would save
friction. Given `CLAUDE.md` states the project is "primarily for the owner and
friends" with monetisation and growth explicitly not priorities, saying so
plainly is reasonable and honest.

### F-5 — Four unreachable commits are present on the remote — LOW

Not reachable from any branch locally, but confirmed present on the remote via
`gh api repos/…/commits/<sha>`, so they will be addressable by SHA once public:

| SHA | Subject |
|---|---|
| `33e64ebd` | DEMO ONLY - do not merge: three deliberate CI violations |
| `6dc4f5ca` | DEMO ONLY: isolate the dependency policy violation |
| `cf8e7650` | Merge master to pick up guard reordering |
| `d07528c3` | F-06 CI: export the attachments (superseded) |

I inspected all three DEMO commits. They contain **no secrets** — they plant a
`health: ^11.0.0` dependency, a `package:flutter` import in `stride_core`, and an
extra Pigeon field, purely to prove the CI guards fail. Harmless, and arguably
interesting evidence that the guards work. Untidy rather than risky; GitHub
garbage-collects unreferenced objects eventually, and they can be left.

### F-6 — `README.md` is stale — LOW

It opens *"This is not yet the game source code… It is the project operating
system Claude Code should read before implementation."* That was true at handoff
and is now wrong: the repository contains a Flutter application, four packages,
540 tests, and CI. It contains **no private information** — the concern is purely
that it misdescribes the project to a first-time visitor.

---

## 6. Summary table

| ID | Finding | Severity | Blocking |
|---|---|---|---|
| R-1 | Author email `rob.hathaway@outlook.com` in all 48 commits | **HIGH** | **Yes** |
| R-2 | No licence; three `TODO` stub LICENSE files | **HIGH** | **Yes** |
| F-2 | No `permissions:` declared in workflows | Medium | No |
| F-3 | 36 runs, ~20 artifacts (~1.2 GB) become public | Medium | No |
| F-1 | Windows username in 2 tracked files (+ history) | Low | No |
| F-4 | No description, `SECURITY.md`, `CONTRIBUTING.md` | Low | No |
| F-5 | 4 unreachable commits present on remote | Low | No |
| F-6 | `README.md` misdescribes the project | Low | No |

**Clean, with no action required:** secrets, API keys, tokens, passwords, private
keys, SSH keys, Apple certificates, provisioning profiles, Android keystores,
`.env` files, service credentials, GitHub auth material, raw health data,
addresses, phone numbers, device identifiers, copyrighted commercial-game assets,
unlicensed copied code, non-redistributable third-party assets, sensitive test
fixtures, and secrets in workflow files.

---

## 7. Recommended order if the owner proceeds

1. **Decide R-2** (licence for code, docs, and future assets) — this is a
   product decision, not a technical one.
2. **Decide R-1** (author email). If rewriting, do R-1 and F-1 in the **same**
   history rewrite, while the repository is still private and has no forks.
3. Add `permissions: contents: read` (F-2).
4. Delete stale artifacts (F-3).
5. Refresh `README.md`, add a description and `CONTRIBUTING.md` (F-4, F-6).
6. Re-run this audit against the rewritten history to confirm the rewrite did
   what was intended.
7. Then, and only then, change visibility.

---

**Audit complete (§1–§7). Nothing was modified during the audit itself.**

---

# 8. Owner decisions and remediation

Recorded 2026-08-03, after owner review of §1–§7.

## 8.1 Author email — **accepted, no rewrite**

The owner **accepts public exposure** of the existing commit metadata:

```
Studio Stride <rob.hathaway@outlook.com>
```

**No Git history rewrite was performed.** All 48 commits retain their original
authorship, SHAs, and signatures. `master` remains at the same lineage, and the
run identifiers cited in `F06_COMPLETION_REPORT.md` continue to resolve.

R-1 is closed as **accepted risk**, not as remediated.

## 8.2 Licensing — **all rights reserved, source-available**

The owner selected **no open-source licence**. Project Stride is publicly
viewable and fully rights-reserved. Actions taken:

1. **Removed the three placeholder licence files**, each containing only
   `TODO: Add your license here.`:
   - `packages/stride_core/LICENSE`
   - `packages/stride_health/LICENSE`
   - `packages/stride_secure_store/LICENSE`

   A `TODO` stub is worse than no file, because it implies a licence exists.
   Nothing in the build, CI, or tooling referenced them; all three packages are
   `publish_to: 'none'`.

2. **Added `COPYRIGHT.md`** at the repository root: copyright belongs to Rob
   Hathaway, all rights reserved, the repository is publicly viewable, and no
   permission is granted to reuse, modify, redistribute, or commercialise the
   code, documentation, Game Bible, lore, content, art, or audio. It notes that
   third-party dependencies remain under their own licences, and that viewing or
   forking through GitHub's interface grants none of those rights. Deliberately
   short — not a custom legal agreement.

3. **Added a `License` section to `README.md`** stating plainly that no
   open-source licence is granted and pointing to `COPYRIGHT.md`.

R-2 is **closed**.

## 8.3 Workflow hardening — **minimised**

`permissions: contents: read` declared at **workflow level** in both
`.github/workflows/ci.yml` and `.github/workflows/android-process-death.yml`.

Re-confirmed after the change:

| Property | Result |
|---|---|
| `pull_request_target` used | **No** ✅ |
| Secrets exposed to fork PRs | **None** — no `${{ secrets.* }}` interpolation anywhere ✅ |
| Self-hosted runners | **None** — 4 × `ubuntu-latest`, 1 × `macos-latest` ✅ |
| Any job requiring write permission | **None** ✅ |

Neither workflow writes to the repository: no releases, no PR comments, no
package publishing, no commits. `contents: read` is the complete requirement.

**Artifact retention reduced to 7 days** on both uploads:

| Artifact | Was | Now |
|---|---|---|
| `stride-debug-apk` | 14 | **7** |
| `secure-store-test-output` | 14 | **7** |

While making that change a **duplicate `retention-days` key** was found on the
second upload (`7` inserted above a pre-existing `14`). YAML takes the last
value, so the intended change would have been silently ineffective. Removed.

**No workflow runs were deleted.** The identifiers cited in
`F06_COMPLETION_REPORT.md` — `30769049772`, `30772473910`, `30773715793`,
`30767931205`, `30775782514` — all remain intact. The pre-existing artifacts
listed in F-3 retain their original 14-day retention and will expire on their
own; the 7-day setting applies to newly uploaded artifacts.

## 8.4 Current-tree local paths — **normalised**

All tracked references to the local Windows username replaced with
`C:\Users\<username>`:

| File | Occurrences |
|---|---|
| `TOOLCHAIN_REPORT_WINDOWS.md` | 6 |
| `PROJECT_STATE.md` | 1 |

Verified: **no tracked file now contains the username**, excepting this report,
which quotes it as the audit record.

Per owner instruction, **history was not rewritten to remove historical
local-path references.** They remain in earlier commits. This is a conscious
trade: the paths reveal a Windows account name and a development directory
layout, and nothing more — no credential, no personal data beyond the account
name itself.

## 8.5 Secret audit — **still clean**

The full-history scan in §3.1 stands unchanged: **0 pattern findings across 629
text blobs and 52 commits**, all 32 entropy hits false positives. The
remediation added two documentation files and edited four text files; none
introduces a credential, and the scan was not invalidated.

## 8.6 Items accepted without action

| ID | Item | Disposition |
|---|---|---|
| F-3 | Existing runs and artifacts become public | **Accepted.** Reviewed: runner paths, simulator names, synthetic test data. No credentials, nothing personal. Runs are cited as evidence in completion reports and must not be deleted |
| F-5 | 4 unreachable commits reachable by SHA | **Accepted.** Inspected: they plant a `health:` dependency, a `package:flutter` import, and a Pigeon field to prove the CI guards fail. No secrets |
| F-4 | No `SECURITY.md` / `CONTRIBUTING.md` / description | **Deferred.** Not a privacy or licensing matter |
| F-6 | `README.md` opening is stale | **Partly addressed** — a `License` section was added; the "not yet the game source code" framing remains |

---

# 9. Final recommendation

## ✅ **PASS — the repository is ready for public visibility.**

| Requirement | Status |
|---|---|
| No secrets, keys, tokens, or credentials in tree or history | ✅ verified, 2 independent methods |
| No private keys, certificates, provisioning profiles, keystores | ✅ none |
| No raw health data or device identifiers | ✅ none |
| No copyrighted third-party assets or unlicensed code | ✅ none; deps all BSD-3-Clause |
| Author email exposure | ✅ accepted by owner |
| Licensing state unambiguous | ✅ all rights reserved, stated in two places |
| Workflow permissions minimised | ✅ `contents: read`, both workflows |
| No `pull_request_target`, no secrets, no self-hosted runners | ✅ confirmed |
| Tracked local paths normalised | ✅ |

**Verification:** `Scripts/verify.sh` — all checks passed, **540 tests, zero
skips**, on the remediated tree.

**Visibility was not changed by this process.** Changing it is a manual owner
action, deliberately left undone.
