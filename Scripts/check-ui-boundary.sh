#!/usr/bin/env bash
# check-ui-boundary.sh
#
# Fails if the product UI under lib/ui/ reaches past StrideSession.
#
# RULES.md E-2 says player-facing UI must not become an alternate source of
# durable game state, and records that it is deliberately backed by no guard,
# ADR, or test. That was defensible while lib/ui/ held one developer harness.
# Phase 1 makes it a real product surface, and the audits found that a widget
# holding a StrideSession can currently reach:
#
#   session.engine.execute(...)      durable state mutated in memory, with no
#                                    commit and no staleness. For a step sync
#                                    this advances the in-memory cursor without
#                                    a durable grant, and the next real sync
#                                    then commits it -- permanently skipping
#                                    every step in between (RULES.md H-3).
#   session.runtime.repository       a second write path around compare-and-swap
#   session.runtime.layout           the save directory's paths
#   session.runtime.healthKeyingSalt the raw device-bound keying salt. Rendering
#                                    it violates H-7 outright, and
#                                    check-origin-privacy.sh does not catch it:
#                                    its sinks are anchored to sourceIdentifier
#                                    and the platform value types, and the salt
#                                    is neither.
#
# StrideSession now projects everything the UI legitimately needs, so this guard
# closes the reach rather than merely discouraging it.
#
# lib/debug/ is deliberately OUT OF SCOPE. The dev harness is a diagnostic
# instrument, not product UI, and it needs the deep access this forbids. Putting
# it in its own directory rather than exempting it here keeps this guard's scope
# statement true instead of caveated -- an allow-list hole is a hole that grows.
#
# Runs anywhere bash and grep exist, including Windows via Git Bash.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UI_DIR="$REPO_ROOT/lib/ui"

if [ ! -d "$UI_DIR" ]; then
  echo "error: product UI sources not found at $UI_DIR" >&2
  exit 1
fi

file_count=$(find "$UI_DIR" -name '*.dart' | wc -l | tr -d ' ')
if [ "$file_count" -eq 0 ]; then
  # An empty scan must not pass silently. "No UI file imports storage" and "no
  # UI file was read" produce identical clean output from a counting check, and
  # every rule here is an absence check.
  echo "error: no Dart sources found in $UI_DIR" >&2
  exit 1
fi

violations=0

# Comment stripping is mandatory, and this repository has paid for learning it
# twice. The most valuable documentation in a UI file is the paragraph naming
# the rule it obeys -- and that paragraph contains the very symbols this guard
# forbids. A guard that cannot tell code from prose makes the rule unwritable,
# which pushes the reasoning out of the file entirely.
scan() {
  local pattern="$1" label="$2" hits=""
  while IFS= read -r file; do
    local stripped
    stripped=$(sed 's://.*$::' "$file")
    if line=$(printf '%s\n' "$stripped" | grep -nE "$pattern" || true); [ -n "$line" ]; then
      hits+="${file#"$REPO_ROOT/"}: $line"$'\n'
    fi
  done < <(find "$UI_DIR" -name '*.dart')

  if [ -n "$hits" ]; then
    echo "error: $label" >&2
    printf '%s' "$hits" >&2
    violations=1
  fi
}

# 1. Storage internals. Real import/export directives only.
#
# NOTE what is deliberately absent from this list:
#   dart:io                       -- `import 'dart:io' show Platform;` is
#                                    legitimate; the symbols are forbidden below
#   package:stride_core/stride_core.dart
#                                 -- REQUIRED. ContentId, ResourceNodeDefinition
#                                    and the bootstrap outcome types all come
#                                    through the public barrel.
for module in \
  'package:stride_storage/' \
  'package:stride_core/src/' \
  'package:path_provider/' \
  'package:stride_secure_store/'
do
  scan "^[[:space:]]*(import|export)[[:space:]]+['\"]${module}" \
    "lib/ui must not import storage internals ($module)"
done

# 2. Engine and persistence plumbing, and the concrete command types.
#
# The UI dispatches through StrideSession; it never constructs a command. Word
# anchored so a longer identifier containing one of these does not trip it.
scan "(^|[^A-Za-z0-9_])(GameEngine|GameCommand|SaveRepository|StorageLayout|GatherResource|ReconcileStepSync|AllocateSteps|GrantSyntheticSteps|EquipItem|UnequipItem|EnterLocation|UnlockLocation|StartEncounter|CombatAttack|CombatEat|CombatRetreat)([^A-Za-z0-9_]|$)" \
  "lib/ui must not name the engine, the repository, or a command type"

# 3. Reaching through the session to what it wraps.
scan "\.(engine|runtime|health)([^A-Za-z0-9_]|$)" \
  "lib/ui must not reach through StrideSession to engine, runtime, or health"

scan "(healthKeyingSalt|saltFingerprint|describeBackupExclusion)" \
  "lib/ui must not touch keying material, fingerprints, or save paths (H-7)"

# 4. Direct filesystem access.
scan "(^|[^A-Za-z0-9_])(Directory|File|RandomAccessFile)\(" \
  "lib/ui must not touch the filesystem"

# 5. Inventing a local-day boundary.
#
# The approved Adventure render shows "3,240 walked today" as its hero figure,
# and it is the number an implementer will reach for first. There is no source
# for it: TimeBucket is a UTC hour-granularity span, so deriving "today" needs a
# local-day boundary and a fold over grantedSlices -- a timezone policy AND a
# game rule, invented in a widget, producing a figure that looks plausible and
# disagrees with itself across a DST boundary. See Q-UI-9.
#
# NAMED EXEMPTION, by the rule's owner (DECISIONS/0022, finite background
# activity): the activity subsystem is allowed exactly ONE wall-clock read,
# and it lives in lib/runtime/stride_session.dart as the injectable
# `activityWallClock` seam -- OUTSIDE this guard's lib/ui scope, so nothing
# below is weakened to admit it. lib/ui derives activity progress only from
# differences of that seam against the committed queue anchor, reached through
# the session; `DateTime.now` remains forbidden in lib/ui in full, and a
# second wall-clock read anywhere needs its own decision.
#
# Q-UI-9 itself is ANSWERED, not waived (DECISIONS/0026): the owner asked for
# the step tracker by name, and the local-day fold lives in
# `StrideSession.stepHistory()` -- lib/runtime, behind the session boundary,
# reading the SAME `activityWallClock` seam (a second caller, not a second
# read site). lib/ui renders the projection's figures and computes nothing;
# every pattern below still holds in full.
scan "(grantedSlices|DateTime\.now|\.toLocal\()" \
  "lib/ui must not derive a local-day figure (Q-UI-9)"

# 6. One image site.
#
# Image's default filterQuality is low, which is bilinear -- the single most
# likely way pixel crispness leaks away (ART_DIRECTION L-18). PixelAsset is the
# one place it is set to none.
#
# `DecorationImage` and `paintImage` are caught alongside the `Image.*`
# constructors, and that addition is the whole point of this paragraph. This
# guard used to match the constructors ALONE, which was airtight for as long as
# the only way to draw a picture was to build an `Image` widget. The moment
# `DECISIONS/0029` allowed authored interface art, the obvious way to draw a
# panel frame became a `DecorationImage` inside a `BoxDecoration` -- which never
# touches `Image.asset`, defaults to bilinear like everything else, and would
# have sailed through this check while quietly softening every border in the
# product. A guard with a hole in exactly the shape of the next feature is
# worse than no guard, because it is trusted.
#
# `AssetImage` on its own is deliberately NOT matched: `precacheImage(AssetImage(...))`
# is legitimate and widespread, and banning it would push authors toward
# suppression rather than compliance. What is forbidden is *painting* through a
# path that cannot set filterQuality, not naming an asset.
image_hits=$(
  while IFS= read -r file; do
    case "${file#"$REPO_ROOT/"}" in
      lib/ui/components/pixel_asset.dart) continue ;;
    esac
    stripped=$(sed 's://.*$::' "$file")
    if line=$(printf '%s\n' "$stripped" | grep -nE "Image\.(asset|file|network|memory)|DecorationImage|paintImage" || true); [ -n "$line" ]; then
      printf '%s: %s\n' "${file#"$REPO_ROOT/"}" "$line"
    fi
  done < <(find "$UI_DIR" -name '*.dart')
)
if [ -n "$image_hits" ]; then
  echo "error: every pixel asset must go through PixelAsset" >&2
  printf '%s\n' "$image_hits" >&2
  violations=1
fi

# 7. Startup ordering.
#
# main.dart awaits StrideSession.start() before runApp. A FutureBuilder in the
# app root reintroduces the zero-flash, and one whose future is built in `build`
# additionally re-runs the bootstrap over the same save directory.
scan "(FutureBuilder|StreamBuilder)" \
  "lib/ui must not load asynchronously -- the session is resolved before runApp"

if [ "$violations" -ne 0 ]; then
  cat >&2 <<'EOF'

The product UI reads state through StrideSession and dispatches commands
through it. It does not construct a command, reach the engine, touch the save,
or compute a game rule.

If a screen needs something StrideSession does not expose, add a projection to
StrideSession -- not a reach from the widget. See the "UI read model" section
in lib/runtime/stride_session.dart.

RULES.md E-2, E-3, H-3, H-7. Diagnostics only; this guard changes nothing.
EOF
  exit 1
fi

echo "ui-boundary: OK"
echo "  product UI sources scanned : $file_count Dart"
echo "  scope                      : lib/ui (lib/debug is deliberately exempt)"
exit 0
