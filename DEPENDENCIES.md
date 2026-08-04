# Third-party dependencies

Project Stride is deliberately dependency-light. This file records every
third-party package the repository installs, what it is for, and why it was
accepted — so that adding one is a decision with a written record rather than a
line in a lockfile.

**Last verified:** 2026-08-03, against the committed lockfiles.

---

## Build-guard tooling (Node) — `Scripts/tooling/`

Not shipped. Not linked into the app. Not a dependency of any Dart package or
either native target. It exists so `Scripts/check-*.sh` can read XML, plists and
entitlements **semantically** instead of matching them with `grep`.

| | |
|---|---|
| Package | `@xmldom/xmldom` |
| Version | **0.9.10**, pinned exactly (no `^`, no `~`) |
| Integrity | `sha512-A9gOqLdi6cV4i…` (full value in `Scripts/tooling/package-lock.json`) |
| Licence | MIT |
| Transitive dependencies | **none at this version** — see the caveat below |
| Required by | `Scripts/lib/xmlq.js` |
| Installed by | `Scripts/bootstrap-tooling.sh` |

### Why a dependency at all

Three guard defects in this repository were one mistake: matching structured
files with `grep` and removing comments with `sed`. Two of them matched the
file's **own prose** about the thing being forbidden and failed a correct tree.
A comment is a lexical construct; removing it correctly is parsing.

An earlier fix hand-rolled a parser in `xmlq.js`. That only moved the place
where a guard can be silently wrong — a security decision resting on 120 lines
of bespoke tokenizer is not obviously better than one resting on a regex. The
owner's ruling was explicit: *do not make a hand-written XML parser the final
semantic authority*; use a maintained, pinned dependency.

### Why Node and not Python

`plistlib` would have been the natural choice. This project's development
machine has no usable Python — both `python` and `python3` resolve to the
Windows Store stub — and `Scripts/verify.sh` has to run **locally**, not only in
CI. A guard that only runs in CI is a guard developers learn to ignore.

### The transitive-dependency claim, stated honestly

`@xmldom/xmldom@0.9.10` declares an empty `dependencies` object, verified
against the installed package and the lockfile. That is a fact about **this
pinned version at the date above**, not a guarantee about the package's future.
A version bump must re-check it; the lockfile is what makes the bump visible.

### Determinism

```bash
bash Scripts/bootstrap-tooling.sh
```

which runs:

```bash
npm ci --prefix Scripts/tooling --ignore-scripts --no-audit --no-fund
```

| Flag | Why |
|---|---|
| `ci` | exact lockfile install; **fails** if `package.json` and the lock disagree, where `npm install` would rewrite the lock to make the disagreement go away |
| `--ignore-scripts` | no lifecycle scripts from any package, install-time or otherwise |
| `--no-audit` | no audit request |
| `--no-fund` | no funding request |

`Scripts/bootstrap-tooling.sh` then runs `Scripts/lib/no-resolution-probe.js`,
which loads the parser in a **cold process** with probes installed *before* the
parser is required, parses a document carrying an external DTD identifier, and
asserts that nothing resolved: `Module._load`, `http`, `https`, `net`, `tls`,
`dns`, `fetch` and `child_process` all stay silent.

### `verify.sh` never installs anything

`Scripts/verify.sh` checks for the dependency and **stops with the bootstrap
command in the message** if it is missing. It does not install it.

A verification script that silently downloads code has made a network fetch part
of the answer to "is this repository correct?". That is wrong in two directions:
it fails offline for a reason unrelated to the code, and it means a run can
install something without anyone having decided to.

### `node_modules` is not committed

`Scripts/tooling/node_modules/` is in `.gitignore`. The manifest and the
lockfile are committed; the installed tree is not.

Vendoring was tried on the `wip/commit-b-tooling` branch and reverted. It puts
third-party source into a repository that has been through a public-readiness
audit, it makes every dependency bump a large unreviewable diff, and it lets a
checkout drift from the lockfile without anything noticing. A lockfile plus
`npm ci` is reproducible without any of that.

---

## Dart and Flutter

Enforced mechanically by `Scripts/check-dependency-policy.sh`, which is why this
section is short: the policy is executable, and this file only records intent.

- **`stride_core`** is pure Dart. No Flutter, no `dart:io`, no plugins. This is
  what lets the entire simulation — reconciliation, the ledger, the save
  protocol — be tested with `dart test` in seconds, on any platform, with no
  device and no emulator.
- **`stride_storage`**, **`stride_health`**, **`stride_secure_store`** may use
  Flutter and platform channels, because that is their entire job.
- Pigeon is a **dev** dependency. It generates the platform boundary; nothing it
  produces is a runtime dependency, and the generated files are committed and
  diff-checked in CI.

`pubspec.lock` is committed for every package, including the plugins. It was
briefly gitignored for the plugin packages, and `dart_style` floated as a
result — which turned into five consecutive red CI runs whose cause was a
formatter version, not the code.

---

## Native

| Platform | Third-party |
|---|---|
| iOS | none. HealthKit, Security and Foundation are system frameworks. |
| Android | AndroidX Health Connect client, declared in `packages/stride_health/android/build.gradle.kts`. |

The Health Connect client's own minimum is API 26, which is why the project's
`minSdk` is 26 everywhere and explicitly — see `DECISIONS/0014` and
`Scripts/check-android-target.sh`. It was previously 24 plus a
`tools:overrideLibrary`, which is a manifest asserting on the project's behalf
that the SDK supports Android 7. It does not. An override does not add support;
it moves the failure from a build here onto a phone belonging to someone who
cannot report it usefully.

---

## Adding a dependency

1. Say what it is for and what breaks without it.
2. Pin it exactly. No ranges.
3. Record its transitive count **as of that version**, and check it again on
   every bump.
4. Record its licence.
5. Add it here before adding it to a manifest.
6. If it is tooling, it installs through `bootstrap-tooling.sh` and never
   implicitly during verification.
