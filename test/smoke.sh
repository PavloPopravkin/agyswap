#!/usr/bin/env bash
# End-to-end smoke test against the stub CLI. No account, no quota, no network.
set -u
cd "$(dirname "$0")/.." || exit 2
ROOT=$PWD
export AGYSWAP_AGY="$ROOT/test/stub-agy"
export AGYSWAP_DIR=$(mktemp -d)
AGY="$ROOT/bin/agyswap"
SLOTS="$AGYSWAP_DIR/slots"
STATE="$AGYSWAP_DIR/state"
fails=0

ok()   { echo "  ok   - $1"; }
bad()  { echo "  FAIL - $1"; fails=$((fails+1)); }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want '$3', got '$2')"; fi; }

for n in 1 2 3; do mkdir -p "$SLOTS/slot$n/.gemini/antigravity-cli"; echo state > "$SLOTS/slot$n/.gemini/antigravity-cli/jetski_state.pbtxt"; done

echo "1. round-robin covers every slot"
out=$(for i in 1 2 3 4 5 6; do "$AGY" hello; done | grep -c 'stub-agy ran')
check "six calls, six runs" "$out" "6"
seen=$(for i in 1 2 3; do "$AGY" hello; done | grep -oE 'slot[0-9]' | sort -u | tr '\n' ' ')
check "three calls hit three accounts" "$seen" "slot1 slot2 slot3 "

echo "2. a quota error walls that account"
STUB_EXHAUSTED=slot2 bash -c 'for i in 1 2 3; do "$0" hello >/dev/null 2>&1; done' "$AGY"
if [ -f "$STATE/wall-2" ]; then ok "wall file written for slot2"; else bad "no wall for slot2"; fi
if [ -f "$STATE/wall-1" ] || [ -f "$STATE/wall-3" ]; then bad "healthy account got walled"; else ok "healthy accounts untouched"; fi

echo "3. a walled account leaves the rotation"
seen=$(for i in 1 2 3 4; do "$AGY" hello; done | grep -oE 'slot[0-9]' | sort -u | tr '\n' ' ')
check "only live accounts are used" "$seen" "slot1 slot3 "

echo "4. the Claude/GPT basket has its own wall"
"$AGY" --model claude-sonnet-4-6 hi >/dev/null 2>&1
seen=$("$AGY" --model claude-sonnet-4-6 hi | grep -oE 'slot[0-9]')
if [ -n "$seen" ]; then ok "Gemini wall does not block a Claude call ($seen served it)"; else bad "Claude call was blocked by the Gemini wall"; fi

echo "5. an answer that merely mentions a rate limit must not wall"
rm -f "$STATE"/wall-*
"$AGY" 'explain the rate limit error and quota handling' >/dev/null 2>&1
if ls "$STATE"/wall-* >/dev/null 2>&1; then bad "answer text triggered a false wall"; else ok "no false wall from answer text"; fi

echo "6. probe walls a spent account and clears a recovered one"
rm -f "$STATE"/wall-*
STUB_QUOTA_slot1="2 90" "$ROOT/bin/agyswap-probe" >/dev/null 2>&1
if [ -f "$STATE/wall-1" ]; then ok "spent Gemini basket walled by probe"; else bad "probe did not wall slot1"; fi
if [ -f "$STATE/wall-cg-1" ]; then bad "full Claude basket walled too"; else ok "full Claude basket left alone"; fi
"$ROOT/bin/agyswap-probe" >/dev/null 2>&1
if [ -f "$STATE/wall-1" ]; then bad "recovered account stayed walled"; else ok "recovered account unwalled by probe"; fi

echo "7. pace budget stops a slot that burned its daily share"
rm -f "$STATE"/wall-* "$STATE/daily.json"
STUB_QUOTA_slot1="90 90" AGYSWAP_DAILY_BUDGET_PCT=10 "$ROOT/bin/agyswap-probe" >/dev/null 2>&1
STUB_QUOTA_slot1="70 90" AGYSWAP_DAILY_BUDGET_PCT=10 "$ROOT/bin/agyswap-probe" >/dev/null 2>&1
if [ -f "$STATE/wall-pace-1" ]; then ok "slot1 paced out after spending 20 points"; else bad "no pace wall after overspend"; fi
seen=$(for i in 1 2 3; do "$AGY" hello; done | grep -oE 'slot[0-9]' | sort -u | tr '\n' ' ')
check "paced slot skipped while others are free" "$seen" "slot2 slot3 "

echo "8. no authenticated slot: stay transparent"
EMPTY=$(mktemp -d)
out=$(AGYSWAP_DIR="$EMPTY" HOME="$EMPTY" "$AGY" hello)
case "$out" in *"stub-agy ran"*) ok "call still reaches the real CLI" ;; *) bad "transparent passthrough broken" ;; esac
rm -rf "$EMPTY"

echo "9. list and which run clean"
"$AGY" list >/dev/null && ok "agyswap list" || bad "agyswap list failed"
"$AGY" which >/dev/null && ok "agyswap which" || bad "agyswap which failed"

rm -rf "$AGYSWAP_DIR"
echo
if [ "$fails" = 0 ]; then echo "all checks passed"; else echo "$fails check(s) failed"; fi
exit $(( fails > 0 ))
