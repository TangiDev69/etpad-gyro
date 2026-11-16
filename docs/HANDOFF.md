# ETPad handoff — 2026-11-16

## Read first

Phase 1 source/gameplay gates are complete; physical-controller play is blocked by absent hardware and menu-click automation remains experimental. Phase 2 is next. Native arm64 macOS client, Legacy modules and renderer build and run from upstream f49e6db1e54eb292b4abe9e761210bf98522672f. iOS framework compilation is experimental and now passes; host integration/launch is next. Full objective: GOAL.md. No simulator has booted. One device was reserved through scripts/sim.sh (SIMULATOR.md). No other reference checkout was modified. No push, release, tag or catalog edit occurred.

## Acceptance

| Item | Status and evidence |
| --- | --- |
| macOS source build | **verified** — configure.log, build-result.log; current scripted build includes input/network changes |
| macOS main menu | **verified** — main-menu.png and exported package runtime reaches main menu with locally supplied data. Test profile was prepared on disk; profile/menu-click automation is separately blocked under CUA after three attempts |
| macOS local bot rounds | **verified with injected input** — source-built client/renderer/Legacy game module, native arm64 Omni-bot 0.93, three bots + player. Both Oasis and Goldrush: Allies engineer spawn, move/fire/reload, objective, death/tapout/respawn, timed intermission. Objective travel used devmap/setviewpos, then real triggers. bot-rounds.log, bots-oasis-capture.png, bots-oasis-final.png, bots-goldrush-objective.png, bots-goldrush-final.png. Earlier listen-server evidence retained |
| macOS public session | **verified** — ten-minute Oasis -> Battery session and disconnect/reconnect on 87.116.30.113:27960, public-session.log and screenshots |
| macOS controller | **experimental; physical play blocked: no controller** — shared SDL mapping, analog pitch/movement, utility/weapon layers and reconnect cleanup compile. Real SDL virtual-controller test passes. Runtime reports no joystick available. No native mapping UI or family prompts yet |
| iPad simulator | **not yet done** — launch, download/import, bot game, complete ellipsis menu, touch layout, prompts, suspend/resume all await engine/host integration |
| iPad device | **not tested: no device or signing** — devicectl finds no physical device; security reports zero valid signing identities |
| PadMint | **experimental** — manifest passes current local main snapshot 816820206336aefde6de1ada951ff2e0dc438976; macOS script/ZIP passes package integrity/media exclusion checks. Device/simulator interface fails explicitly pending iOS implementation. No catalog change |
| Physical iPad feel and networking | **unconfirmed until Chris tests** |

## Current process and first next step

No game or simulator is running. Final macOS package rebuild succeeded (build/macos/build-package-final.log); one generated mod pack, ZIP CRCs and original-media exclusion verified. No build is running. It selects the exact generated Legacy pack and removes stale generated pack copies from package staging/exports. Prior exported package launched with its own renderer and modules, with paks supplied by a separate ignored profile (not embedded in package).

Next: begin Phase 2 with the reusable native host plus real engine/renderer feasibility, preserving macOS. Re-read GOAL.md and this handoff each loop. Do not call unfinished iOS shells accepted games.

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

Original Splash Damage paks and installer remain ignored/local. SHA-256 pins and provenance: GAME_DATA.md. Data-only helper passes Apple Python 3.9.6. Exact build/launch/component-test commands: BUILDING.md. Controller map: CONTROLS.md. Decisions include reference commits; no port component has been copied yet.

Last committed checkpoint: 4444d8988 (controller, UDP, package/simulator hardening). Current Omni-bot, package selection and documentation/evidence updates are uncommitted; commit after final ZIP check. Do not commit original data, saves or builds. Build output remains under build/, at half the eight CPU cores. Never build twice in parallel or run simulator alongside game.

## Phase 2 compilation checkpoint

GL4ES simulator archive and five native frameworks now compile/link using ANGLE Metal inputs. No simulator launch yet. Source changes are iOS guarded, but a macOS bot regression check is still due. New apple/ios CMake glue, platform functions, SDL2 ANGLE adapter, GL4ES lifecycle and framework-only module loader are experimental. Do not claim signed app packaging until the host embeds/signs them.

Logs: build/ios-engine-sim/configure-attempt1..3.log, build-attempt1..3.log, build-dependencies4.log and build-angle1..2.log. Initial failures were different dependency/platform issues, repaired as documented in DECISIONS.md. Final build-angle2 succeeds. No simulator was booted and no device/signing became available. Next: native host and actual engine launch, then data acquisition, controls/menu/lifecycle.
