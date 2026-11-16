#!/bin/bash
# All ETPad simulator operations go through this single-device guard.
set -euo pipefail
cd "$(dirname "$0")/.."
state=build/simulator-udid
mkdir -p build docs/evidence/ios-sim
other_booted() {
  xcrun simctl list devices booted -j | python3 -c 'import json,sys; d=json.load(sys.stdin); allowed=sys.argv[1]; print("\n".join(x["udid"] for a in d["devices"].values() for x in a if x.get("state")=="Booted" and x["udid"]!=allowed))' "${udid:-}"
}
udid=$(cat "$state" 2>/dev/null || true)
# The tracked reservation survives build-folder cleanup. Never allocate a second device.
if [[ -z "$udid" && -f docs/SIMULATOR.md ]]; then
 udid=$(sed -n 's/^UDID: `\([^`]*\)`.*/\1/p' docs/SIMULATOR.md)
 [[ -n "$udid" ]] || { echo 'Simulator reservation exists but its UDID is unreadable.' >&2; exit 1; }
 printf '%s\n' "$udid" > "$state"
fi
if [[ -n "$(other_booted)" ]]; then echo 'Refusing: another simulator is booted.' >&2; exit 1; fi
case "${1:-}" in
 inventory) xcrun simctl list devicetypes;;
 init)
  if [[ -z "$udid" ]]; then
   udid=$(xcrun simctl create 'ETPad iPad' com.apple.CoreSimulator.SimDeviceType.iPad-Pro-11-inch-M5-16GB com.apple.CoreSimulator.SimRuntime.iOS-26-5)
   printf '%s\n' "$udid" > "$state"
   printf '# ETPad simulator\n\nUDID: `%s`\n\nDevice: iPad Pro 11-inch (M5). Runtime: iOS 26.5 (newest installed at initialization).\n\nUse only `scripts/sim.sh`; never create a replacement.\n' "$udid" > docs/SIMULATOR.md
  fi
  printf '%s\n' "$udid";;
 test)
  [[ -n "$udid" ]] || { echo 'Run scripts/sim.sh init first.' >&2; exit 1; }
  [[ $# -ge 3 ]] || { echo 'Usage: scripts/sim.sh test APP BUNDLE_ID [launch arguments...]' >&2; exit 2; }
  if pgrep -f 'ET Legacy.app/Contents/MacOS/ET Legacy|(^|/)etl($| )' >/dev/null; then echo 'Stop the macOS game first.' >&2; exit 1; fi
  trap 'xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true; osascript -e '\''tell application "Simulator" to quit'\'' >/dev/null 2>&1 || true' EXIT
  xcrun simctl shutdown all
  xcrun simctl boot "$udid"
  xcrun simctl bootstatus "$udid" -b
  xcrun simctl install "$udid" "$2"
  bundle=$3; shift 3
  container=$(xcrun simctl get_app_container "$udid" "$bundle" data)
  printf '%s\n' "$container" > build/simulator-container
  if [[ -n "${ETPAD_SIM_DATA_DIR:-}" ]]; then
   # Local test fixture only: never becomes part of an app/package export.
   /usr/bin/python3 scripts/prepare-game-data.py --import-from "$ETPAD_SIM_DATA_DIR"
   mkdir -p "$container/Documents/ETPad/etmain"
   cp game-data/etmain/pak[012].pk3 "$container/Documents/ETPad/etmain/"
  fi
  if [[ "${ETPAD_SIM_VISIBLE:-0}" = 1 ]]; then open -a Simulator --args -CurrentDeviceUDID "$udid"; fi
  xcrun simctl launch --terminate-running-process --console "$udid" "$bundle" "$@" > build/ios-engine-sim/runtime-console.log 2>&1 &
  console_pid=$!
  duration=${ETPAD_SIM_HOLD_SECONDS:-10}
  [[ "$duration" =~ ^[0-9]+$ && "$duration" -ge 10 && "$duration" -le 1800 ]] || { echo 'Hold must be 10–1800 seconds.' >&2; exit 2; }
  for ((elapsed=0; elapsed<duration; elapsed++)); do
   sleep 1
   if [[ "$elapsed" = 9 ]]; then xcrun simctl io "$udid" screenshot docs/evidence/ios-sim/latest.png; fi
   if [[ -f build/simulator-stop ]]; then python3 -c 'from pathlib import Path;Path("build/simulator-stop").unlink()'; break; fi
  done
  if [[ -f "$container/Documents/ETPad/legacy/etconsole.log" ]]; then cp "$container/Documents/ETPad/legacy/etconsole.log" build/ios-engine-sim/runtime.log; fi
  xcrun simctl io "$udid" screenshot docs/evidence/ios-sim/final.png;;
 capture)
  [[ -n "$udid" && -d build/ios-engine-sim ]] || exit 1
  [[ "${2:-latest}" =~ ^[a-zA-Z0-9_-]+$ ]] || exit 2
  xcrun simctl io "$udid" screenshot "docs/evidence/ios-sim/${2:-latest}.png";;
 *) echo 'Usage: scripts/sim.sh init | test APP BUNDLE_ID [arguments...]' >&2; exit 2;;
esac
