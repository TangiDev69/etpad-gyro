#!/bin/bash
# Optional local macOS Omni-bot runtime from ET: Legacy's own mirror.
set -euo pipefail
cd "$(dirname "$0")/.."
archive=downloads/omnibot-macos-0.93.tar.gz
expected=7c4a3c1b6f185e48267764b3fc5ffcee6c7b61cec2505d5b6b38847f92502313
mkdir -p downloads build/omnibot-runtime
if [[ ! -f "$archive" ]]; then
 curl -fL --retry 2 https://mirror.etlegacy.com/omnibot/omnibot-macos-0.93.tar.gz -o "$archive.partial"
 actual=$(shasum -a 256 "$archive.partial" | awk '{print $1}')
 [[ "$actual" = "$expected" ]] || { echo 'Omni-bot archive SHA-256 mismatch' >&2; exit 1; }
 mv "$archive.partial" "$archive"
fi
actual=$(shasum -a 256 "$archive" | awk '{print $1}')
[[ "$actual" = "$expected" ]] || { echo 'Omni-bot archive SHA-256 mismatch' >&2; exit 1; }
tar -xzf "$archive" -C build/omnibot-runtime
lipo build/omnibot-runtime/omni-bot/omnibot_et_mac.so -verify_arch arm64
printf 'Local native bot runtime: %s/build/omnibot-runtime/omni-bot\n' "$PWD"
