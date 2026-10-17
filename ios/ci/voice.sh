#!/bin/bash
# On the cloud Mac, before a TestFlight build: the app, on the iPad simulator sim-shots.sh left running, makes with
# Kokoro the sentences every game says, in both languages (-prerender). They're copied into ios/build/Voice, which goes
# in the app, so his iPad doesn't have to make them. Never fails the build: without them the iPad makes them itself.
set -uo pipefail
cd "$(dirname "$0")/../.."
ID=org.jordancox.insieme
UDID=$(xcrun simctl list -j devices booted | python3 -c '
import json, sys
d = json.load(sys.stdin)["devices"]
print(next((x["udid"] for v in d.values() for x in v), ""))')
[ -n "$UDID" ] || { echo "no simulator running"; exit 0; }
LOG=$PWD/ios/build/shots/prerender.log
xcrun simctl launch --terminate-running-process --stdout="$LOG" --stderr="$LOG" "$UDID" "$ID" -prerender YES -quiet NO -lang it >/dev/null
for _ in $(seq 1 180); do grep -q "prerender: done" "$LOG" && break; sleep 5; done
xcrun simctl terminate "$UDID" "$ID" || true
DATA=$(xcrun simctl get_app_container "$UDID" "$ID" data)
mkdir -p ios/build/Voice
find "$DATA/Library/Caches/Voice" -name '*.wav' ! -name '*.part.wav' -exec cp {} ios/build/Voice/ \;
echo "$(ls ios/build/Voice | wc -l | tr -d ' ') sentences made ahead ($(du -sh ios/build/Voice | cut -f1)); $(grep -c 'prerender: done' "$LOG") done"
