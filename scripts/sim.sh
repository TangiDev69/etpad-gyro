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
  if pgrep -x etl >/dev/null; then echo 'Stop the macOS game first.' >&2; exit 1; fi
  trap 'xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true; osascript -e '\''tell application "Simulator" to quit'\'' >/dev/null 2>&1 || true' EXIT
  xcrun simctl shutdown all
  xcrun simctl boot "$udid"
  xcrun simctl bootstatus "$udid" -b
  xcrun simctl install "$udid" "$2"
  bundle=$3; shift 3
  xcrun simctl launch "$udid" "$bundle" "$@"
  sleep 10
  xcrun simctl io "$udid" screenshot docs/evidence/ios-sim/latest.png;;
 *) echo 'Usage: scripts/sim.sh init | test APP BUNDLE_ID [arguments...]' >&2; exit 2;;
esac
