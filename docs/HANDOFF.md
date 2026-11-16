# ETPad handoff — 2026-11-16

## Read first

Phase 1 source/gameplay gates are complete; physical-controller play is blocked by absent hardware and menu-click automation remains experimental. Phase 2 is active. Native arm64 macOS client, Legacy modules and renderer build and run from upstream f49e6db1e54eb292b4abe9e761210bf98522672f. The iOS host, five embedded frameworks and ANGLE/GL4ES now run a real local Oasis round. Full objective: GOAL.md. Only the reserved simulator has booted. One device was reserved through scripts/sim.sh (SIMULATOR.md). No other reference checkout was modified. No push, release, tag or catalog edit occurred.

## Acceptance

| Item | Status and evidence |
| --- | --- |
| macOS source build | **verified** — configure.log, build-result.log; current scripted build includes input/network changes |
| macOS main menu | **verified** — main-menu.png and exported package runtime reaches main menu with locally supplied data. Test profile was prepared on disk; profile/menu-click automation is separately blocked under CUA after three attempts |
| macOS local bot rounds | **verified with injected input** — source-built client/renderer/Legacy game module, native arm64 Omni-bot 0.93, three bots + player. Both Oasis and Goldrush: Allies engineer spawn, move/fire/reload, objective, death/tapout/respawn, timed intermission. Objective travel used devmap/setviewpos, then real triggers. bot-rounds.log, bots-oasis-capture.png, bots-oasis-final.png, bots-goldrush-objective.png, bots-goldrush-final.png. Earlier listen-server evidence retained |
| macOS public session | **verified** — ten-minute Oasis -> Battery session and disconnect/reconnect on 87.116.30.113:27960, public-session.log and screenshots |
| macOS controller | **experimental; physical play blocked: no controller** — shared SDL mapping, analog pitch/movement, utility/weapon layers and reconnect cleanup compile. Real SDL virtual-controller test passes. Runtime reports no joystick available. Native iOS mapping UI and family prompts now exist; macOS uses console bindings |
| iPad simulator | **experimental** — real Oasis listen round: Allied engineer, touch fire/reload, Old City capture, suicide/tapout/respawn, timed intermission; both landscapes and engine suspend/resume verified. Official native download, Files import and confirmed removal/redownload verified. Native settings, presets, remapping, prompts and report preview tested. Bot core and remaining gameplay menu checks pending. Evidence ios-sim/oasis-gameplay.log, oasis-intermission.png, oasis-resumed.png, data-import.png, native-download.log |
| iPad device | **not tested: no device or signing** — devicectl finds no physical device; security reports zero valid signing identities |
| PadMint | **experimental** — manifest passes current local main snapshot 816820206336aefde6de1ada951ff2e0dc438976; macOS script/ZIP passes package integrity/media exclusion checks. Simulator build exports a runnable signed app; device export implementation awaits build verification. No catalog change |
| Physical iPad feel and networking | **unconfirmed until Chris tests** |

## Current process and first next step

Latest simulator build passes (build/ios-engine-sim/build-controller-startup.log). Simulator test block ended and shut down the one saved device, quitting Simulator. Native UI/shared-code macOS regression build passes (build/macos/build-native-ui-regression.log); macOS Oasis bot regression passed with source-built modules, native bots, engineer move/fire/reload/suicide and intermission; togglemenu opened ET menu. Client quit normally (exit 0). Evidence native-ui-regression.log/png. No build is running. The menu-selection test ended; the reserved simulator is shut down.

Next: simulator rebuilt with the newly registered togglemenu command; verify Game Menu + absolute UI touch/keyboard. Then attempt iOS bot integration, public interoperability, unsigned device build and final packaging/manifest checks. Record all limitations explicitly. Latest committed checkpoint is 4f71bd816; native UI/data/settings work is uncommitted pending this regression.

Public acceptance: 87.116.30.113:27960 (/GS/Veterans, Legacy v2.84.0), joined by 16:01:15 UTC, stayed past 16:11:21 through Oasis -> Battery, explicit disconnect/reconnect by 16:12:15. CUA drove gameplay; bot kill/revive/respawn observed. public-session.log and screenshots saved. No chat or admin commands sent. One intermission composer held unsent input; it was never submitted.

Local native bots: scripts/prepare-bots.sh checks official 0.93 archive/hash/arm64. Source-built Legacy server interface enabled by build script. Both two-minute rounds passed after warmup; map scripts reset timelimit at FIGHT, so set the short limit after that restart. This verifies injected-input gameplay, not physical-controller feel.

## What failed and what fixed it

- Source attempt 1: linker `tapi error: malformed file`, `unknown architecture arm64e.x1-macos` from CommandLineTools MacOSX27.2 SDK. Attempt 2: CMAKE_OSX_SYSROOT alone overwritten by upstream. Attempt 3: pin both CMAKE_OSX_SYSROOT and XCODE_SDK_PATH to Xcode SDK; build succeeds. Script also exports SDKROOT now; that follow-up needs next build verification.
- Initial submodule update could not fetch pinned historical commit (`transport file not allowed`). Explicit HTTPS fetch + checkout fixed it; build script now has that fallback and requires clean pinned libs.
- Three profile/menu click attempts: direct click+typeText, click+individual keys, held click+held keys all failed to focus/activate game menus. Console and gameplay keyboard/fire work. Prepared `legacy/profiles/ETPadTest/profile.dat` and `legacy/profiles/defaultprofile.dat`, each containing quoted ETPadTest, then restarted to reach main menu. `cl_profile` is read-only; console set cannot apply it. CUA relative drag and Raise did not fix menu movement; further input investigation remains open.
- `screenshotPNG` unsupported; use `set r_screenshotFormat 2` plus `screenshot NAME`. UI catchers consume F12; console `wait 300; screenshot NAME` then close console captures clean UI.
- First public download: expected block 32768, got negative signed shorts. src/client/cl_parse.c now compares low 16 bits while retaining full ACK counter and distinguishes redirect/start/rollover headers. Source build and local bot rounds now include the duplicate-block-zero refinement.
- Shutdown correction: original client sessions exit code 0 normally. Calling CUA getAXState after Quit silently relaunched the app through its bundle. A process sample showed a newly launched game rendering, not a stalled exit. Terminated those owned relaunched instances. No engine shutdown fix needed. Avoid app-specific observations after Quit; use process/session results or global inventory.
- First simulator type identifier invalid (no device created); installed memory-specific M5 identifier worked. Tracked UDID recovers reservation if build directory is removed, preventing accidental second creation. Initial read-only simulator inventory predated guard; all later sim operations go through it.

## Data, commands and last commit

Original Splash Damage paks and installer remain ignored/local. SHA-256 pins and provenance: GAME_DATA.md. Data-only helper passes Apple Python 3.9.6. Exact build/launch/component-test commands: BUILDING.md. Controller map: CONTROLS.md. Decisions include all adapted reference components and commits.

Last committed checkpoint: 4f71bd816 (UIKit engine host plus macOS bot regression). Current native UI/input/data changes await the next verified checkpoint. Do not commit original data, saves or builds. Build output remains under build/, at half the eight CPU cores. Never build twice in parallel or run simulator alongside game.

## Phase 2 compilation checkpoint

GL4ES simulator archive and five native frameworks now compile/link using ANGLE Metal inputs. No simulator launch yet. Source changes are iOS guarded, but a macOS bot regression check is still due. New apple/ios CMake glue, platform functions, SDL2 ANGLE adapter, GL4ES lifecycle and framework-only module loader are experimental. Do not claim signed app packaging until the host embeds/signs them.

Logs: build/ios-engine-sim/configure-attempt1..3.log, build-attempt1..3.log, build-dependencies4.log and build-angle1..2.log. Initial failures were different dependency/platform issues, repaired as documented in DECISIONS.md. Final build-angle2 succeeds. No simulator was booted and no device/signing became available. Next: native host and actual engine launch, then data acquisition, controls/menu/lifecycle.

## UIKit/renderer host checkpoint (uncommitted)

Simulator app builds and passes deep/strict ad hoc signature verification. `scripts/build-etpad.sh --platform simulator --output DIR` now exports a real app with five signed native frameworks plus ANGLE. Driver stages only Legacy data, controller cfg and notices; original paks remain separate local fixtures in the simulator Documents container. `--platform device` implementation exists but is not yet build-tested or signed. Python helpers compile under Apple Python 3.9.

**Experimental:** engine reaches Legacy main menu through GL4ES/ANGLE Metal. Source/driver logs: build/ios-engine-sim/build-driver1..8.log. Initial black frame fixed by redirecting ES1 calls to GL4ES's private symbols (Darwin omits GNU aliases), then returning from engine initialization and ticking Com_Frame via CADisplayLink so UIKit can animate/commit. Native ellipsis menu opens. Full native menu/controls are still incomplete. Native data manager/extractor compile; host UI is not wired to them yet. A standalone macOS test of the same C extractor reads the official zip without executing installer code; all three extracted pak SHA-256 checks pass (build/data-extract-test/result.log). Files/download native UI acceptance remains untested.

**Blocked after three layout attempts:** iPad landscape/full-window alignment. Initial successful render was a partial 4:3 viewport; (1) copied UTP-style root-view sizing/identity transform plus requested Metal drawable size yielded a rotated narrow renderer; (2) removing manual root sizing/transform did not fix it; (3) attaching SDL's UIWindow to the active host scene immediately after SDL_CreateWindow, before Metal creation, still rotated the game/overlay. Log confirms pre-Metal frame/bounds/root 1210x834, orientation=3, but screenshot remains 90° rotated/narrow. Evidence: ios-sim/main-menu-initial.png and landscape-blocked.png. Stop further layout attempts in this loop and move to independent native acquisition/menu/touch/controller work. No simulator gameplay or landscape acceptance is claimed. Vulkan fallback/performance comparison still pending.

Only simulator UDID 672DC5A6-8C79-465E-8ABC-50E57C8F7B80 was booted, always through scripts/sim.sh; script shuts it down and quits Simulator at block end. `test` optionally stages already hash-checked local original paks (`ETPAD_SIM_DATA_DIR`), captures console/logs/screenshots and permits a bounded interactive block (`ETPAD_SIM_HOLD_SECONDS`, `ETPAD_SIM_VISIBLE`). `capture NAME` uses the same reservation guard. No Mac game ran alongside it.

One stale-app launch was stopped after a Swift recovery-check compile error; it is not counted as validation. Fixed the Swift error and verified build before subsequent launch. Native data download/import still awaits UI wiring and simulator testing. A macOS regression build/test is next before committing shared-code changes.

Mac regression now passes: current source built through the public script; native Omni-bot Oasis round, injected move/fire/reload/death/tapout/respawn and intermission. Evidence ios-regression.log/png. Client stopped after capture; no game/simulator/build is running. Next independent work: wire native acquisition, implement full native menu and touch/controller UI; use a host-only simulator mode while landscape rendering is blocked.

## Native acquisition, controls and gameplay checkpoint

Earlier compilation/host sections above are historical. Native Download Free Game Data completed through URLSession against the official pinned ZIP; all three installed SHA-256 values match. Files picker selected only pak0/1/2, preserved etkey, and verified them (12:04:29). Confirmed Remove Game Data returned to missing-data onboarding; in-app redownload restored all three (12:06:37). Engine-started removal is deferred to next launch. Transaction recovery protects the previous data set. No original data is bundled/committed.

Native menu tests: Show Touch Controls; Auto-Hide; controller mapping A/Cross Jump→Reload, persisted readback, restored defaults; opacity/size sliders and left-hand/Hide with controller toggles; saved/reloaded “ETPad Smoke” layout; Arrange/Done; restore layout; 1280 render preference; FOV page; FPS; player name ETPadTest; favorite 87.116.30.113:27960. Report questions generated a bounded local text report and share-sheet preview, never sent. Slider accessibility needed a value-observing subclass; switch duplicate accessibility entries were removed. Simulator advertises a virtual “Gamepad”, so its prompt screenshot is simulated connection evidence, not a physical-controller test.

**Layout blocker resolved by new simulator-state evidence:** Device→Orientation→Landscape Right actually updates the simulated sensor. Toolbar Rotate had only rotated the displayed frame, including SpringBoard. Both landscape orientations now fill the viewport correctly; raw simctl screenshots can retain a portrait framebuffer with rotated contents. No fourth speculative app-layout change was needed. Earlier blocked screenshots are retained as failure evidence.

**Engine UI timeout resolved:** com_maxfps=0 clamps to 20 and caused ~50 ms NET_Sleep inside every main-thread frame, starving UIKit accessibility. Set 250 while CADisplayLink paces at 60. Real Oasis steady 600-frame windows: CPU average 4.4–5.6 ms, p95 5.8–6.9 ms, display interval ~16.67 ms (simulator, 1280×882, not physical GPU/device measurements). Initial loading window excluded. MoltenVK comparison still pending.

Real signed-framework Oasis session: native Console ran team b 2; forcetapout. Touch FIRE consumed 5 rounds (30→25), RELOAD animation observed and returned to 30. Jump/move smoke taps issued. Assisted setviewpos 3708 7352 -480 0 and forward triggered “Allies capture the Old City!” at game time 121100 (+3 XP). Home background logged lifecycle paused at 12:30:34.950; same PID 21813 resumed and rendered. Both sensor landscapes verified. kill; forcetapout produced suicide at 198300 and respawned engineer; timelimit 3 reached AXIS WIN intermission. This is a listen-server round without bots, not bot-game acceptance. Evidence oasis-gameplay.log, oasis-resumed.png, oasis-intermission.png.

Found unknown cmd togglemenu during touch MENU test. Added Apple-only command under apple/shared that queues the engine Escape down/up path, shared with controller Start and native Game Menu. Build/runtime verification is next. Other gameplay/menu commands were checked against cgame registration. Further shared-code changes include iOS MAX_OSPATH=1024, OS string ios, and early unsupported-mod rejection; all require the current macOS regression before committing.

## Menu selection blocker (three attempts)

Updated togglemenu opens the real ET game menu on both macOS and simulator; native ellipsis remains reachable. Absolute ET menu selection is **blocked/experimental**: (1) touch Limbo at screenshot coordinate 293,252 moved the drawn cursor with an offset but did not activate; (2) 250 ms hold at 305,272 still did not activate; (3) 500 ms Options-area touch at 293,460 ended with `Server Shutdown (Received signal 11)`, black screen and process exit. No OS crash report because upstream handles SIGSEGV and exits. Exact log: ios-sim/menu-pointer-failure.log. Do not claim ET menu touch/trackpad acceptance. Follow user three-attempt rule; move to independent public connection/device packaging. Native controls/settings and direct Console remain usable. Physical-controller menu navigation is untested.
