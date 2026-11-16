# ETPad decisions

## 2026-11-16 — Upstream-first baseline

Context: Empty checkout; macOS must work before iPad. Decision: retain full ET: Legacy master history at f49e6db1e54eb292b4abe9e761210bf98522672f with remote upstream and local branch etpad. Preserve GPL and upstream notices; add Apple integrations under apple/. Evidence: git history and CMakeLists.txt. Reversal: an upstream incompatibility requires a documented pin.

## 2026-11-16 — Reference ports and visual precedence

Context: User specifies GoldenPad/UTP controls although UTP later adopted EctoPad. Decision: follow the user's explicit black translucent resting controls, pressed-only tint and hidden resting guides. Reference checkouts remain read-only. No component copied yet. Read reference commits: sunpad e43f0ea6b797e5110787171957c9dc3c6213269c; utp a9313911efcf044fd66f9a679af53e55e255a8b4; tribespad 3f033e4c4b6a620e8a3cd905565b087adbd2bd0a; goldenpad 54474a40e93b77259d10c7594919e6a05f5e276d; padmint 1d842442a8b309282745531d48c4b8972dd4a6dc. Evidence: UTP docs/DECISIONS.md, TribesPad docs/HANDOFF.md and padmint.json. Reversal: explicit user change or measured physical usability failure.

## 2026-11-16 — One simulator

Context: Memory/thermal constraints. Decision: scripts/sim.sh owns simulator operations, stores one UDID, refuses another booted device, and shuts down after each test. Initialization first attempted a non-existent M5 type (no device created), then selected the installed 16GB identifier. Evidence: docs/SIMULATOR.md. Reversal: only an explicit user change; never create a second ETPad device automatically.

## 2026-11-16 — Pin the SDK in both upstream variables

Context: The first two source builds selected /Library/Developer/CommandLineTools/SDKs/MacOSX27.2.sdk, which Xcode 26.6's linker rejects with `tapi error: malformed file`, `unknown architecture arm64e.x1-macos`. Setting CMAKE_OSX_SYSROOT alone is overwritten by cmake/ETLPlatform.cmake. Decision: pass both CMAKE_OSX_SYSROOT and XCODE_SDK_PATH from `xcrun --sdk macosx --show-sdk-path`. Third build succeeds, with arm64 client, Legacy modules and vanilla renderer. Evidence: docs/evidence/macos/configure.log and build-result.log; full ignored build/macos/build-sdk-pinned.log. Reversal: upstream respects the initial sysroot without override.

## 2026-11-16 — Data-only download helper

Context: Official Linux ZIP contains a Makeself installer with optional key/setup programs. Decision: verify ZIP SHA-256, read only the appended tar payload, extract only original pak0/1/2, verify all three before replacing local data. Never execute installer programs. Implemented independently in scripts/prepare-game-data.py; tested with /usr/bin/python3 (3.9). Evidence: GAME_DATA.md. Reversal: official source changes format or hashes; review provenance before updating pins.

## 2026-11-16 — PadMint validation without modifying reference checkout

Context: PadMint is on codex/tribespad-catalog, not main. Decision: archive its current local main 816820206336aefde6de1ada951ff2e0dc438976 to ignored build/padmint-main and run check-manifest from that snapshot. Manifest uses upstream-engine; both targets remain experimental. In-app acquisition described by manifest is planned, not implemented. Evidence: check-manifest passes. Build interface currently rejects iOS explicitly. No catalog edits. Reversal: iOS integration/package validation is actually implemented and tested.
