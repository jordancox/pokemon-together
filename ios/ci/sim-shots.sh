#!/bin/bash
# On the cloud Mac: installs the simulator build on an iPad simulator (or an iPhone one: `sim-shots.sh iphone`, a few
# screens with names starting phone-) and takes screenshots of each screen (-demo sets
# one up), then lets two random Pokémon play whole games by themselves (-auto -fast: the lines go to the log, not the
# speaker). The app's own messages ("[insieme] …", every line it says included) go to ios/build/shots/*.log.
# Pattern from flashcards/ios/ci/sim-shots.sh.
set -euo pipefail
cd "$(dirname "$0")/../.."
APP=ios/build/dd/Build/Products/Debug-iphonesimulator/Insieme.app
ID=org.jordancox.insieme
OUT=$PWD/ios/build/shots; mkdir -p "$OUT" # absolute: the simulator opens the log files itself
KIND=${1:-ipad}
# His iPad: an 11-inch iPad Pro from 2018 (834×1194 points, the size the board is drawn at). Made as a simulator if
# Xcode still has that model; else an 11-inch iPad Pro (same width), else any iPad. On a phone run, the plain newest iPhone.
UDID=
if [ "$KIND" = ipad ]; then
  TYPE=$(xcrun simctl list -j devicetypes | python3 -c '
import json, sys
print(next((t["identifier"] for t in json.load(sys.stdin)["devicetypes"] if t["name"] == "iPad Pro (11-inch) (1st generation)"), ""))')
  [ -n "$TYPE" ] && UDID=$(xcrun simctl create "His iPad Pro 11 (2018)" "$TYPE" 2>/dev/null) || UDID=
  echo "his model: ${UDID:-not in this Xcode (${TYPE:-no device type})}"
fi
[ -n "$UDID" ] || UDID=$(xcrun simctl list -j devices available | KIND=$KIND python3 -c '
import json, os, re, sys
d = json.load(sys.stdin)["devices"]
phone = os.environ["KIND"] == "iphone"
sims = [x for k, v in d.items() if "iOS" in k for x in v if x["name"].startswith("iPhone" if phone else "iPad")]
best = [x for x in sims if re.fullmatch(r"iPhone \d+", x["name"])] if phone else [x for x in sims if "Pro" in x["name"] and "11" in x["name"]]
pick = sorted(best or sims, key=lambda x: [int(n) for n in re.findall(r"\d+", x["name"])] or [0])
print(pick[-1]["udid"] if pick else "")')
[ -n "$UDID" ] || { echo "no $KIND simulator"; xcrun simctl list devices available; exit 1; }
xcrun simctl list devices | grep "$UDID"
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
plutil -p "$APP/Info.plist" > "$OUT/info.txt" 2>&1 || true
ls -R "$APP" | head -80 > "$OUT/bundle.txt" 2>&1 || true
xcrun simctl install "$UDID" "$APP"
shot() { xcrun simctl io "$UDID" screenshot "$OUT/$1.png" >/dev/null 2>&1; echo "shot $1"; }
# Kokoro is off (-nokokoro) except for the voice test: making sentences in the background kept the cloud Mac's 3 cores
# busy, so every launch and screenshot crawled (11 minutes for a minute of iPhone screens; build 18's hung). Each run
# says how long it took, and SLOW when that's well over its waits.
run() { # name, seconds before each shot…, launch arguments after --
  local name=$1; shift; local waits=(); while [ "$1" != "--" ]; do waits+=("$1"); shift; done; shift
  # never an empty array: the Mac's bash is 3.2, where "${a[@]}" of an empty one fails under set -u (it did, 18 Oct)
  local args=("$@"); [[ " $* " == *" -voicetest "* ]] || args+=(-nokokoro YES)
  local start=$SECONDS want=0 slack=30
  [ -n "${WARM:-}" ] || slack=150 # the first launch on a just-booted simulator takes about a minute and a half
  WARM=1
  xcrun simctl launch --terminate-running-process --stdout="$OUT/$name.log" --stderr="$OUT/$name.log" "$UDID" "$ID" "${args[@]}" >/dev/null
  local k=1; for w in "${waits[@]}"; do sleep "$w"; want=$((want + w)); shot "$name-$k"; k=$((k + 1)); done
  local took=$((SECONDS - start))
  echo "  $name: ${took}s$([ $took -gt $((want + slack)) ] && echo " SLOW (waits ${want}s)")"
}
if [ "$KIND" = iphone ]; then
  xcrun simctl shutdown all || true # the iPad simulator is done: two at once on 3 cores is too many
  xcrun simctl boot "$UDID" 2>/dev/null || true
  xcrun simctl bootstatus "$UDID" -b >/dev/null
  xcrun simctl install "$UDID" "$APP"
  run phone-empty 5 -- -lang it -quiet NO
  run phone-pick 5 -- -demo pick -lang it -quiet NO
  run phone-battle 5 -- -demo battle -lang it -quiet NO
  run phone-quiet 4 -- -demo battle -lang en -quiet YES
  run phone-zoom 4 -- -demo zoom -lang it -quiet NO
  run phone-over 4 -- -demo over -lang en -quiet NO
  run phone-auto 2 3 4 -- -auto YES -fast YES -lang it -quiet NO
  run phone-add-search 10 -- -demo add -query pikachu -lang it
  run phone-added 15 -- -add sv01-038,sv01-036,me01-001,sv01-037 -demo pick -lang it -quiet NO
  run phone-add-list 6 -- -demo add -lang en
  xcrun simctl terminate "$UDID" "$ID" || true
  xcrun simctl shutdown "$UDID" || true
  exit 0
fi
run empty 5 -- -lang it -quiet NO # a new iPad: none of his cards yet
run pick 5 -- -demo pick -lang it -quiet NO
run battle 5 -- -demo battle -lang it -quiet NO
run battle-en 4 -- -demo battle -lang en -quiet NO
run quiet 4 -- -demo battle -lang it -quiet YES
run zoom 4 -- -demo zoom -lang it -quiet NO
run over 4 -- -demo over -lang en -quiet NO
run auto 2 2 2 3 4 6 -- -auto YES -fast YES -lang it -quiet NO
run auto-en 25 -- -auto YES -fast YES -lang en -quiet NO
run auto-2 25 -- -auto YES -fast YES -lang it -quiet NO
# Kokoro on the simulator: how long it takes to make lines (the log's "kokoro:" lines; the iPad is slower)
run voice 75 -- -voicetest YES -lang it -quiet NO
# Adding cards (no camera on the simulator: the name search, and cards added the way the add screen does). Last, as
# the cards it adds stay in the app's data for any later run.
# The camera, without a camera: one card's frames must be looked up once (build 20's screen flickered)
run scantest 8 -- -scantest YES -lang en
grep -q "scantest: 1 lookup," "$OUT/scantest.log" || { echo "scantest failed:"; grep "scantest" "$OUT/scantest.log"; exit 1; }
grep "scantest" "$OUT/scantest.log"
run add-search 10 -- -demo add -query fuecoco -lang it
run add-number 10 -- -demo add -query 38/198 -lang it
run add-camera 10 -- -demo add -query "HP 60 LA SI 038/198" -lang it # as the camera reads a card: not the old sets HP, LA, SI
run add-code 10 -- -demo add -query "G SVIIT 038/198" -lang en
run add-name 10 -- -demo add -query "pikachu 25" -lang en
run added 15 -- -add sv01-038,sv01-036,me01-001,sv01-037 -demo pick -lang it -quiet NO
run add-list 6 -- -demo add -lang en
xcrun simctl terminate "$UDID" "$ID" || true
