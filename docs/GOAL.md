User amendment, 2026-11-17: complete another performance pass, refine README/documentation, push changes and integrate into main. Creating main in the existing repository is authorized if absent; no tag, release or PadMint catalog publication.

Follow-up authorization (2026-11-16): test actual public iPad Simulator map rotation and reconnect, fix failures, and push to existing GitHub branch. Rework touch placement using actual gameplay/scoreboard screenshots and HUD clearance; this supersedes the earlier fixed utility-diamond arrangement where necessary. Physical iPad claims still require hardware/signing.

User amendment, 2026-11-16 (design pass): improve the touch-control appearance and organization of the three-dot menu; inspect current native screens, implement, visually verify and push with the ongoing changes.

User amendment, 2026-11-16: continue in parallel, improve README to Kartpad quality, and push changes to the existing GitHub repository. This supersedes the original no-push restriction below for origin/etpad only. No release, tag, new repository, post or PadMint catalog edit is authorized. Parallel source/docs work is allowed; builds remain serial.

GOAL: ETPad (working name). Wolfenstein: Enemy Territory through ET: Legacy, native on macOS and iPad.
Controller first, touch second. Able to join existing PC ET: Legacy servers. Ready for PadMint later.
Work autonomously until every acceptance item below is either done with evidence or documented as
blocked. Do not ask Chris questions. When a choice comes up, choose the simplest option that matches his
other ports, record it in docs/DECISIONS.md (context, decision, evidence, reversal condition), and continue.

MACHINE RULES (MacBook Air: limited memory and cooling)
- Exactly one iOS Simulator at a time, ever. Create one device once and reuse it:
  name "ETPad iPad", an 11-inch M-series iPad on the newest installed iPadOS runtime. Save its UDID in
  docs/SIMULATOR.md.
- Every simulator action goes through scripts/sim.sh (write it first). It runs `xcrun simctl shutdown all`,
  boots only the saved UDID, waits with `simctl bootstatus -b`, installs, launches, takes screenshots, then
  shuts down. It refuses to run if `xcrun simctl list devices booted` shows any other device. Never boot,
  create or clone another simulator. Quit Simulator.app after each test block.
- Never run the simulator and the macOS game at the same time. Never run two builds in parallel.
  Build with half the CPU cores (-j$(( $(sysctl -n hw.ncpu) / 2 ))).
- Keep build output inside the repo's build folders. Remove only ETPad's own DerivedData when disk is low.

REPOSITORY
- Primary checkout: /Users/chrissotraidis/GitHub/etpad. Clone https://github.com/etlegacy/etlegacy
  (master), keep it as remote "upstream", and work on a local branch "etpad". Preserve upstream history
  and GPL-3.0 notices. Apple code goes under apple/ (ios/, macos/, shared/) so upstream merges stay easy.
- Commit locally in small steps with clear messages. No AI co-author or "Generated with" lines.
  Do not create a GitHub repository, push, tag, release, post or edit PadMint's catalog.
- Never commit game files (pak0.pk3, pak1.pk3, pak2.pk3, any downloaded installer), saves or builds.
  Add them to .gitignore first.
- Read, but never modify: /Users/chrissotraidis/GitHub/sunpad, utp, tribespad, goldenpad, padmint.
  When copying a component, cite its source file and commit in DECISIONS.md and keep its notices.

GAME DATA
- Wolfenstein: Enemy Territory is a free release. Download it from the official Splash Damage source,
  extract the etmain pak files, and record their SHA-256 hashes in docs/GAME_DATA.md. The game data stays
  under the original EULA: use it for local testing only, never commit or redistribute it.
- The app gets data the way TribesPad does: an in-app download from the official source with SHA-256
  checks, plus Files import of pak files the player already has. Show a clear message when data is missing.

PHASE 1: macOS (finish before Phase 2)
1. Build ET: Legacy from source for macOS arm64 with the Legacy mod. If the official build already
   works, still make the source build work, because iOS depends on it.
2. Play through it, driving the game with console commands and injected input; if a computer-use tool is
   available, use it to play.
   a) Reach the main menu with the pak files.
   b) Start a local game with bots on Oasis and Goldrush (Omni-bot if it builds; otherwise a listen server).
      Play a full round: spawn, pick a class, fire, reload, take an objective, die, respawn, reach intermission.
   c) Join a public ET: Legacy server running the Legacy mod. Play for at least ten minutes through a map
      change, then disconnect and reconnect. Record the server address and results.
3. Add controller support on macOS through GameController/SDL with the same default bindings Phase 2 uses.
4. Evidence: screenshots and logs in docs/evidence/macos/, exact commands in docs/BUILDING.md.

PHASE 2: iPad (simulator first, then device)
5. App shell: reuse UTP's and TribesPad's iOS host. SDL's window is render-only; the host window and
   overlay own all touches and stay frontmost (UTP DECISIONS, 2026-08-23). Handle suspend, resume and
   rotation, and keep landscape only.
6. Renderer, in order: (a) ET: Legacy's GLES renderer on ANGLE's Metal backend, reusing TribesPad's
   angle_sdl.c/gl4es approach; (b) if that fails or runs badly, the renderer_vk backend on MoltenVK.
   Record frame times for both.
7. Native modules: the client, renderer, cgame, ui and Legacy qagame must load without loading unsigned
   code. Either link them statically and register them in a table, or embed them as signed frameworks in
   the app bundle. Only the built-in Legacy mod is supported. Servers that require other mods' native code
   must give a clear "this server needs a mod ETPad can't run" message. Downloaded maps and other pk3 data
   are fine; downloaded native code is never loaded.
8. Controller first: MFi, Xbox and PlayStation controllers with defaults for every ET action (fire, alt
   fire, reload, jump, crouch, prone, sprint, lean, use, next and previous weapon, weapon slots, scoreboard,
   limbo/class/team menu, map, vote yes/no, vsay quick chat on the D-pad in the style of TribesPad's
   controller quick chat, and the console). On-screen button prompts follow the connected controller.
   Touch controls hide while a controller is in use ("Hide with controller").
9. Touch layout: adapt UTP's GoldenPadTouchOverlay.swift with ET's vocabulary. Use GoldenPad's tablet
   layout, black translucent buttons at rest, a per-action tint only while pressed, and move and look guides
   that are hidden at rest. Left side: movement stick. Right side, the actions used while aiming: FIRE, ALT,
   JUMP, CROUCH, PRONE, RELOAD. A four-direction utility group: SCORE, PREV, NEXT, USE. A separate MENU pill.
   Touch settings use UTP's wording: Opacity, Size, Left-handed, Hide with controller, Arrange Controls,
   Saved Layouts, Restore Default Layout. iPad keyboard (WASD) and trackpad work like TribesPad's.
10. Three-dot menu: a persistent ellipsis like SunPad's and UTP's, always reachable, opening a native dark
   UIMenu titled "ETPad":
   - Controls: Show Touch Controls, Auto-Hide Touch Controls (on/off), Controller Button Mapping…,
     Touch Control Settings…, Arrange Controls
   - Display: Render Resolution, Field of View, Show FPS Counter
   - Online: Player Name…, Favorite Servers
   - Game Data & Saves: Download Free Game Data, Import or Reimport Game Data, Remove Stored Game Data
     (confirm before removing)
   - Report a Problem…: SunPad's flow; logs and device info only, never game files
   Keep ET's own in-game menus reachable with touch, controller and trackpad.
11. Simulator testing through scripts/sim.sh only: data import, main menu, a bot game on Oasis, every
   menu item, touch-control smoke taps, a controller-connected screenshot, and suspend/resume.
   Save screenshots to docs/evidence/ios-sim/.
12. Device: if a physical iPad is connected and a signing identity is available, install and repeat step 11,
   then join the same public server from step 2c. Otherwise stop at the simulator and say so.

PADMINT READINESS (prepare only)
13. Add scripts/build-etpad.sh --platform device|simulator|macos --output DIR [--ipa FILE] [--zip FILE],
   matching TribesPad's script. Any Python helper must run on Apple's Python 3.9.
14. Add padmint.json modeled on TribesPad's: input type official-download, "when": "in-app"; ios and macos
   targets marked "experimental". Validate it with `python3 -m padmint check-manifest
   /Users/chrissotraidis/GitHub/etpad` run from PadMint's current main. Do not add ETPad to PadMint's catalog;
   that needs Chris's explicit go-ahead. player-check.sh comes at release time.

LOOP (repeat until done or blocked)
- Re-read docs/HANDOFF.md and pick the first unmet acceptance item in phase order.
- Make the smallest change that moves it forward, build, then test with one simulator or the macOS game.
- Save evidence, commit, and update docs/HANDOFF.md (what works, what failed, last good commit, next step).
- After three failed attempts on the same item, record the exact error and attempts in HANDOFF.md, mark it
  blocked, and move on to the next item that doesn't depend on it.
- Never bring a platform up by breaking another: rerun the macOS bot-game check after iOS changes that
  touch shared code.

ACCEPTANCE (label each verified, experimental or not yet done, with evidence)
- macOS: source build, bot round, public-server session with map change and reconnect, controller play.
- iPad simulator: launch, data download and import, bot game, three-dot menu complete, touch layout matching
  the GoldenPad/UTP style, controller prompts, suspend/resume, one simulator used throughout.
- iPad device: install, bot game and public-server session, or "not tested: no device or signing".
- PadMint: build script plus a padmint.json that passes check-manifest.
- Physical-iPad play feel and real-server play from the iPad stay unconfirmed until Chris tests them.

DONE WHEN every acceptance item is verified or documented as blocked, docs/HANDOFF.md is current, and the
working tree is clean with everything committed locally.