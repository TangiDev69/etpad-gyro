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

## 2026-11-16 — Shared SDL controller layers

Context: Upstream already polls SDL GameController but disables controllers and analog mapping by default, has no complete ET layout, no pitch-bind-to-axis translation and no reconnection routing. Decision: retain SDL's Apple GameController backend and add small Apple-only hooks with implementation under apple/shared. LB selects utility/quick-chat keys; RB selects weapons. Store each pressed key's bank until release and release held actions/axes on detach. Load versioned defaults once so later player remapping persists. Default movement uses normalized analog range; right-stick yaw/pitch have separate rates. No reference code copied. TribesPad quick chat is a conceptual reference only; its current commit is listed above. Evidence: controller-test.log and CONTROLS.md, macOS build script succeeds. Physical-controller play and native mapping/prompts are unverified. Reversal: real-controller play reveals a specific binding/reach/dead-zone issue or SDL provides equivalent upstream behavior.

## 2026-11-16 — Preserve unsigned UDP download sequence numbers

Context: Public Legacy server 144.76.234.9:27980 sends legacy_v2.84.0.pk3 via UDP. At 32 MiB the client expects block 32768 but MSG_ReadShort sign-extends received blocks, and the file stalls. Decision: compare the wire counter's low 16 bits to the full local counter, retain the full acknowledgement sequence, restrict HTTP redirect sentinel to the start, and distinguish first file-size header from rollover block zero. Preserve first-block retry parsing before the first rollover. Check for a truncated header. Evidence: ignored launch.log has exact repeated error; live corrected build completed the 32.71 MiB download, restarted and loaded Oasis on the pure server (udp-download.log). Reversal: upstream adopts an equivalent fix or protocol changes the sequence field width.

## 2026-11-16 — Enable native macOS Omni-bot integration

Context: Upstream macOS defaults disable the Omni-bot interface even though the official runtime includes arm64. Decision: force the source-built Legacy server module's existing Omni-bot interface on macOS. Keep official Omni-bot 0.93 optional and local under build/omnibot-runtime, with archive SHA-256 7c4a3c1b6f185e48267764b3fc5ffcee6c7b61cec2505d5b6b38847f92502313. Download URL: https://mirror.etlegacy.com/omnibot/omnibot-macos-0.93.tar.gz (latest archive was initially inspected, then version pin verified). No bot core or assets are committed or included in the app package. Evidence: source-built qagame loads native arm64 bot core, initializes Omni-bot 0.93 and fills local Oasis with three bots plus player. Bot core itself is prebuilt; engine, renderer and Legacy modules are source-built. Reversal: upstream default enables equivalent integration, or source-built/static bot core is required on iOS.

## 2026-11-16 — iOS engine frameworks and Metal translation

Context: upstream's Apple path assumes macOS/Cocoa; the GLES renderer uses ES 1.x, while ANGLE exposes ES 2/3. Static linking all Legacy modules also collides on common VM symbols.

Decision: isolate iOS CMake additions in apple/ios, build the client/renderer/cgame/ui/qagame as embedded frameworks with separate symbol namespaces, and whitelist their bundle paths in the iOS loader. Use GL4ES before ANGLE's Metal backend. Module extraction from downloaded pk3 files is bypassed on iOS. The host must embed/sign these frameworks. No launch acceptance is claimed from compilation alone.

Copied/adapted components from read-only TribesPad commit `3f033e4c4b6a620e8a3cd905565b087adbd2bd0a`:
- `scripts/build-gl4es-mobile.py` → `scripts/build-gl4es.py`: same pinned GL4ES source and Darwin alias/client-active-texture patches; ETPad build paths, SDK selection and half-core job limit.
- `scripts/angle_backend_inputs.py` → same ETPad script name: pinned download/hash/source receipt, own build dependency directory. ANGLE license downloaded alongside the inputs.
- `port/apple/angle_sdl.c` and `.h` → `apple/ios/angle_sdl.c` and `.h`: SDL2 conventions, one engine context, native Metal view.
- `port/apple/gl4es_context.c` → minimal lifecycle in `apple/ios/gl4es_context.c`; streaming optimizations deferred until measured.

GL4ES source pin: `ec16bedd8819c475326f4f1a3063772c6d986e06`; its license remains in the ignored source/build artifacts and must ship with the app. ANGLE distributor/zip/hash/reported source commit are recorded by the dependency helper; this is a hash-verified distributor binary, not a local ANGLE source build. Framework signatures will be validated at app packaging.

Evidence: simulator GL4ES archive built, root iOS configure passed, all five engine/Legacy frameworks linked (`build/ios-engine-sim/build-angle2.log`). Fixes needed: Cocoa→UIKit platform split; forward SDK/system/CPU to dependency builds; clean only stale JPEG CMake cache; allow dependency discovery of the locally installed Ogg prefix; link SDL's required iOS system frameworks. Pristine libs gitlink retained. External process launching is disabled on iOS. macOS shared-code regression check is still due before accepting these changes.

Reversal condition: failed simulator rendering or unacceptable measured frame times; evaluate Vulkan/MoltenVK next. Native loader and host changes remain experimental until actual app launch and gameplay.

## 2026-11-16 — UIKit frame ownership and native data acquisition

Context: a non-returning engine main loop prevents UIKit transactions/menu animations from completing reliably. Darwin GL4ES lacks public GNU symbol aliases, so ordinary GLES symbols resolve to ANGLE and fail ES1 drawing.

Decision: iOS engine entry initializes and returns; CADisplayLink runs Com_Frame on the main thread, pausing on system inactivity. Redirect the GLES renderer's direct calls to GL4ES's private exported entry points. The initial Legacy main menu now renders via GL4ES on ANGLE Metal and the native menu opens. Landscape alignment remains blocked after three attempts, recorded with screenshots/errors in HANDOFF.md. macOS entry/loop remain unchanged behind ETPAD_IOS guards; current source build plus Oasis native-bot gameplay/respawn/intermission regression pass (ios-regression.log/png).

Native host AppDelegate/SceneDelegate and window ownership adapt UTP `Sources/UT99Host/AppDelegate.swift`, `SceneDelegate.swift`, and `GameViewController.swift` at `a9313911efcf044fd66f9a679af53e55e255a8b4`. Acquisition architecture is informed by `UT99GameDataAcquisition.swift` at that commit, but the official ZIP/Makeself/gzip-tar reader is ETPad-specific. It extracts only fixed pak names without running installer code; standalone extraction verifies all three SHA-256 values. The Swift acquisition UI remains untested/unwired at this checkpoint.

Build driver uses only Apple Python 3.9, serial external dependency builds and half-core inner build limits. Simulator app packaging deeply verifies ad hoc signatures, includes GPL/GL4ES/ANGLE notices and excludes original media. Device packaging is unsigned until a signing identity is available; no install claim.

Reversal condition: native frame scheduling breaks network/engine timing or measured performance requires a different cadence. Keep UIKit ownership and framework loader restrictions in any replacement.

## 2026-11-16 — Native controls, reports and pure-server metadata

Context: the host must own touch and preserve native menus while the engine renders. Decision: adapt UTP `Sources/UT99Host/GoldenPadTouchOverlay.swift`, `UT99TouchConfiguration.swift` and `GameViewController.swift` at a9313911efcf044fd66f9a679af53e55e255a8b4 into ETPad's overlay/configuration, surface-pointer and keyboard fallback. Tablet thumb-arc geometry follows GoldenPad `Sources/TouchLayout.swift` at 54474a40e93b77259d10c7594919e6a05f5e276d. Report question/preview flow follows SunPad `SunPadGameOverlay.mm` at e43f0ea6b797e5110787171957c9dc3c6213269c. GPL notices remain in adapted source. ETPad's menu/settings/remapping code is native UIKit; reports include only bounded text logs/device info and user answers, with explicit share-sheet review. No automatic posting.

Evidence: actual native acquisition/import/removal; settings persistence/readback, report preview and real Oasis round in HANDOFF.md. Sensor orientation corrected the earlier layout blocker. com_maxfps 250 avoids upstream's 20 FPS clamp for zero; 60 Hz display link paces frames. Measured steady simulator CPU frame averages 4.4–5.6 ms, p95 5.8–6.9 ms at 1280×882; not physical device performance.

Pure-server accounting: embedded frameworks provide all executable code; opening/closing a matching PK3 native entry only marks its containing archive as referenced, without reading/extracting/loading that entry. This preserves ET's cross-platform cgame/ui pure checksum accounting. Public interoperability with this path is still pending. Reject non-Legacy fs_game before server-state mutation. Reversal: upstream exposes a metadata-only reference API or wire compatibility requires a reviewed change. Never load downloaded native code.

Packaging now collects upstream and bundled dependency notices, including GL4ES, ANGLE, SDL, IJG JPEG acknowledgment and MiniZip. No original media ships. Reversal: replace adapted UI only for a measured usability issue, preserving the user's explicit vocabulary/style and native ownership.

## 2026-11-16 — Preserve native crash diagnostics and isolate retained cgame state

Context: repeated public disconnect/reconnect exited in cgame initialization; desktop fatal-signal cleanup suppressed Apple's crash report. Decision: iOS leaves SIGILL/FPE/SEGV to UIKit/OS reporting while desktop retains upstream handlers. The resulting sanitized stack locates a NULL glyph callback in the loading screen before new font registration. iOS framework globals can survive dlclose. Reset the cgame display context and load-screen flag before reinitializing cgame. Evidence: reconnect-crash-stack.txt and public-session-attempt2.log. The third test passed the earlier fault but exited later during Railgun graphics loading; reconnect remains blocked after three attempts. This narrow reset is not claimed as full lifecycle acceptance. Reversal: complete framework/module reinitialization or upstream equivalent with live reconnect evidence.

Native-only mod restriction now runtime-verified against Jaymod 185.216.147.189:27960: clear unsupported-mod error, no downloaded native code load. Existing Legacy pure-server join/gameplay succeeds. Unsigned device packaging passes arm64 IOS/IPA integrity/media exclusion checks. Native surface-resolution correction verified on real Oasis at 960×662 and a live main-menu 960→1280×882 restart (resolution-fixed-*.png, resolution-final.log): ANGLE Metal calculates framebuffer size from CAMetalLayer bounds times contentsScale; direct drawableSize assignments alone are overwritten. Source inspected at the pinned ANGLE commit: https://github.com/google/angle/blob/d2e5e488da0c6215f8276e5b8d992a4a6ec20c32/src/libANGLE/renderer/metal/SurfaceMtl.mm. Keep UIKit presentation size independent of render pixels.
