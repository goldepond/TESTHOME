#!/usr/bin/env bash
# check_user_copy.sh — MyHome v1.3 P1-1 Copy Doctrine Gate
#
# Scans `lib/screens/**` and `lib/widgets/**` for raw user-facing strings that
# contain forbidden words ("우선권 / 매칭 / 점수 / 가중치 / 활동률 / Tier").
#
# Whitelist:
#   - lib/screens/admin/**            (operator screens — copy-deck §6)
#   - lib/utils/admin_*.dart          (operator utilities)
#   - lib/screens/**/*audit*          (operator audit screens)
#
# Identifier exceptions (do NOT count, even on user screens):
#   - auditEventLabel                 (copy-deck §5: 매도자 사실 통지)
#   - participationHolderBadge        (copy-deck §5: 매도자 보유자 강조)
#
# Exit codes:
#   0 — pass (no violations)
#   1 — violations found (lines printed to stdout)
#
# Usage:
#   bash tools/check_user_copy.sh                  # scan tracked files
#   bash tools/check_user_copy.sh path/to/file ... # scan specific files

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# ---------------------------------------------------------------------------
# Forbidden words (raw user-facing strings only)
# ---------------------------------------------------------------------------
# Pattern matches Flutter copy positions:
#   Text('...word...')          Text("...word...")
#   title: '...word...'         title: "...word..."
#   label: '...word...'         label: "...word..."
#   labelText: '...word...'     hintText: '...word...'
#   subtitle: '...word...'      tooltip: '...word...'
#   helperText: '...word...'    errorText: '...word...'
#   semanticsLabel: '...word...'
#
# Identifiers (auditEventLabel / participationHolderBadge) and any reference to
# `GrantMessages.*` constants pass automatically because they are not raw quoted
# strings — they are property accesses.

FORBIDDEN='(우선권|매칭|점수|가중치|활동률|Tier)'

# Build the regex pattern. We anchor on a Flutter widget/parameter slot that
# accepts a raw quoted user-facing string.
#
# Key rule: the forbidden word MUST appear inside the quoted literal, NOT as
# part of an identifier like `releaseTier` (which is a Dart property, not a
# Text() argument).
PATTERN_TEXT='Text\((\s*const\s+)?["'\''][^"'\'']*'"$FORBIDDEN"'[^"'\'']*["'\'']'
PATTERN_PARAM='(title|label|labelText|hintText|subtitle|tooltip|helperText|errorText|semanticsLabel|message)\s*:\s*(\s*const\s+)?["'\''][^"'\'']*'"$FORBIDDEN"'[^"'\'']*["'\'']'

# ---------------------------------------------------------------------------
# Whitelist: paths to skip entirely
# ---------------------------------------------------------------------------
is_whitelisted() {
  local f="$1"
  # admin screens
  case "$f" in
    lib/screens/admin/*) return 0 ;;
    lib/utils/admin_*.dart) return 0 ;;
    *audit*) return 0 ;;
  esac
  return 1
}

# ---------------------------------------------------------------------------
# Files to scan
# ---------------------------------------------------------------------------
declare -a TARGETS=()

if [ "$#" -gt 0 ]; then
  for arg in "$@"; do
    TARGETS+=("$arg")
  done
else
  # Default: every tracked .dart file under lib/screens/** and lib/widgets/**
  while IFS= read -r line; do
    TARGETS+=("$line")
  done < <(git ls-files 'lib/screens/*.dart' 'lib/screens/**/*.dart' 'lib/widgets/*.dart' 'lib/widgets/**/*.dart' 2>/dev/null)
fi

if [ "${#TARGETS[@]}" -eq 0 ]; then
  echo "check_user_copy: no target files found — nothing to do."
  exit 0
fi

# ---------------------------------------------------------------------------
# Scan
# ---------------------------------------------------------------------------
violations=0
violation_log=""

for f in "${TARGETS[@]}"; do
  # Only Dart files
  case "$f" in
    *.dart) ;;
    *) continue ;;
  esac

  [ -f "$f" ] || continue
  is_whitelisted "$f" && continue

  # grep -nE returns matching lines with line numbers; combine both patterns.
  matches="$(grep -nE "$PATTERN_TEXT|$PATTERN_PARAM" "$f" || true)"
  if [ -n "$matches" ]; then
    while IFS= read -r m; do
      violations=$((violations + 1))
      violation_log="${violation_log}${f}:${m}"$'\n'
    done <<< "$matches"
  fi
done

# ---------------------------------------------------------------------------
# Optional: simplicity-checklist anchor presence (advisory)
# ---------------------------------------------------------------------------
checklist_path="docs/common/simplicity-checklist.md"
if [ -f "$checklist_path" ]; then
  if ! grep -qE '자가 점검|21항목|80세' "$checklist_path"; then
    echo "::warning::simplicity-checklist.md missing expected anchors (자가 점검 / 21항목 / 80세)"
  fi
fi

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------
if [ "$violations" -gt 0 ]; then
  echo "Copy Doctrine Gate: FAIL ($violations violation(s))"
  echo ""
  echo "Forbidden raw user-facing strings detected. See copy-deck.md §1.1 / §5."
  echo "Use GrantMessages.* constants instead of raw Text('...우선권...')."
  echo ""
  echo "Violations:"
  printf '%s' "$violation_log"
  exit 1
fi

echo "Copy Doctrine Gate: PASS (${#TARGETS[@]} file(s) scanned, 0 violations)"
exit 0
