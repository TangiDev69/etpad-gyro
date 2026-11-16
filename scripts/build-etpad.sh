#!/bin/bash
# Build ETPad: --platform device|simulator|macos --output DIR [--ipa FILE] [--zip FILE]
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
platform=macos
output="$repo/build/output"
ipa=
zip=
while [[ $# -gt 0 ]]; do
 case "$1" in
  --platform|--output|--ipa|--zip)
   [[ $# -ge 2 ]] || { echo "Missing value for $1" >&2; exit 2; }
   case "$1" in --platform) platform=$2;; --output) output=$2;; --ipa) ipa=$2;; --zip) zip=$2;; esac
   shift 2;;
  -h|--help) sed -n '2p' "$0"; exit 0;;
  *) echo "Unknown argument: $1" >&2; exit 2;;
 esac
done
case "$platform" in device|simulator|macos) ;; *) echo 'Invalid platform' >&2; exit 2;; esac
if [[ "$platform" != macos ]]; then
 echo 'ETPad iOS engine integration is not implemented. See docs/HANDOFF.md.' >&2; exit 1
fi
[[ -z "$ipa" ]] || { echo '--ipa requires device platform' >&2; exit 2; }
cd "$repo"
mkdir -p build/macos "$output"
output=$(cd "$output" && pwd)
# Build output always remains in this checkout; --output selects exported artifacts only.
if ! mkdir build/etpad-build-active 2>/dev/null; then
 echo 'Another ETPad build is active (or stale build/etpad-build-active remains).' >&2; exit 1
fi
trap 'rmdir "$repo/build/etpad-build-active"' EXIT
if [[ ! -f libs/CMakeLists.txt ]]; then
 git config submodule.libs.url https://github.com/etlegacy/etlegacy-libs.git
 git submodule update --init libs
fi
sdk=$(xcrun --sdk macosx --show-sdk-path)
cmake -S . -B build/macos -G Ninja -DCMAKE_BUILD_TYPE=Release \
 -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0 \
 -DCMAKE_OSX_SYSROOT="$sdk" -DXCODE_SDK_PATH="$sdk" \
 -DINSTALL_EXTRA=OFF -DFEATURE_AUTOUPDATE=OFF
cmake --build build/macos -j$(( $(sysctl -n hw.ncpu) / 2 ))
stage="$repo/build/package-macos"
mkdir -p "$stage/legacy" "$stage/etmain"
ditto 'build/macos/ET Legacy.app' "$stage/ET Legacy.app"
cp build/macos/legacy/cgame_mac build/macos/legacy/ui_mac build/macos/legacy/qagame_mac "$stage/legacy/"
cp build/macos/legacy/legacy_*.pk3 "$stage/legacy/"
cp build/macos/librenderer_opengl1_mac "$stage/"
cp COPYING.txt "$stage/" 2>/dev/null || cp COPYING "$stage/"
# Original pak0/1/2 and saved profiles are deliberately excluded.
if [[ -n "$zip" ]]; then
 mkdir -p "$(dirname "$zip")"
 ditto -c -k --keepParent "$stage" "$zip"
fi
printf 'Experimental macOS package: %s\n' "$stage"
