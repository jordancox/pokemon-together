#!/bin/bash
# On the cloud Mac: installs the simulator build on an iPad simulator and takes screenshots of each screen (-demo sets
# one up), then lets two random Pokémon play whole games by themselves (-auto -fast: the lines go to the log, not the
# speaker). The app's own messages ("[insieme] …", every line it says included) go to ios/build/shots/*.log.
# Pattern from flashcards/ios/ci/sim-shots.sh.
set -euo pipefail
cd "$(dirname "$0")/../.."
APP=ios/build/dd/Build/Products/Debug-iphonesimulator/Insieme.app
ID=org.jordancox.insieme
OUT=$PWD/ios/build/shots; mkdir -p "$OUT" # absolute: the simulator opens the log files itself
# An 11-inch iPad Air (his is an 11-inch iPad Pro), else any iPad
UDID=$(xcrun simctl list -j devices available | python3 -c '
import json, sys
d = json.load(sys.stdin)["devices"]
sims = [x for k, v in d.items() if "iOS" in k for x in v if x["name"].startswith("iPad")]
pick = sorted([x for x in sims if "Air" in x["name"] and "11" in x["name"]] or sims, key=lambda x: x["name"])
print(pick[-1]["udid"] if pick else "")')
[ -n "$UDID" ] || { echo "no iPad simulator"; xcrun simctl list devices available; exit 1; }
xcrun simctl list devices | grep "$UDID"
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
plutil -p "$APP/Info.plist" > "$OUT/info.txt" 2>&1 || true
ls -R "$APP" | head -80 > "$OUT/bundle.txt" 2>&1 || true
xcrun simctl install "$UDID" "$APP"
shot() { xcrun simctl io "$UDID" screenshot "$OUT/$1.png" >/dev/null 2>&1; echo "shot $1"; }
run() { # name, seconds before each shot…, launch arguments after --
  local name=$1; shift; local waits=(); while [ "$1" != "--" ]; do waits+=("$1"); shift; done; shift
  xcrun simctl launch --terminate-running-process --stdout="$OUT/$name.log" --stderr="$OUT/$name.log" "$UDID" "$ID" "$@" >/dev/null
  local k=1; for w in "${waits[@]}"; do sleep "$w"; shot "$name-$k"; k=$((k + 1)); done
}
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
run add-search 10 -- -demo add -query fuecoco -lang it
run added 15 -- -add sv01-038,sv01-036,me01-001,sv01-037 -demo pick -lang it -quiet NO
run add-list 6 -- -demo add -lang en
xcrun simctl terminate "$UDID" "$ID" || true
