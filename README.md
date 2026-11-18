# ETPad

<img src="apple/ios/Host/Assets.xcassets/AppIcon.appiconset/icon-1024.png" alt="ETPad wartime poster app icon" width="128" height="128">

**Wolfenstein: Enemy Territory on Apple silicon Mac and iPad, built on ET: Legacy.**

Controller-first play, native iPad touch controls and settings, local bots, and interoperability with existing Legacy servers. ETPad preserves upstream history and adds Apple integration under [`apple/`](apple/).

[Quickstart](#quickstart-on-mac) · [Build targets](#build-targets) · [Game data](#game-data) · [Controls](#controller-and-touch) · [Documentation](#documentation)

![Oasis running in ETPad's native arm64 macOS build](docs/evidence/macos/final-regression-respawn.png)

*Actual macOS Oasis gameplay. Original game media is acquired separately and excluded from the repository and exported apps.*

> **Experimental preview.** Mac, iPad Simulator and a physical iPad Pro have recorded runs. Touch feel, physical controllers, keyboard/trackpad and external displays still need a hands-on pass. Public IPAs are unsigned; personal installs use your own development signing. Local exports are development artifacts, not published release downloads.

## Current status

| Target | Verified scope | Limits |
| --- | --- | --- |
| **macOS · arm64** | Source-built engine/renderer/Legacy modules, Oasis and Goldrush bot rounds, sustained public play with map change and reconnect | Injected gameplay input; physical controller play untested. Optional bot core is a separate prebuilt macOS dependency. |
| **iPad Simulator · arm64** | Native data setup, touch menus, assisted Oasis bot round through intermission, landscape/resume, public map rotations and reconnect | Objective travel used developer positioning and god mode. Physical multi-touch, controller, keyboard and trackpad feel untested. |
| **Physical iPad · arm64** | Development-signed install on iPad Pro 12.9-inch (6th gen): launcher, in-app data detection, bot rounds on Oasis and Goldrush, live server list and a public server join with map download | Touch was checked by screenshot only (no physical tapping); Xbox controller, keyboard/trackpad and external display still need a hands-on pass. |

Exact test procedures, logs, package audits and remaining gates live in [HANDOFF.md](docs/HANDOFF.md). [PadMint preparation](padmint.json) is validated but remains `experimental` / `draft-untested`, without a catalog listing.

## Quickstart on Mac

Use an Apple silicon Mac with full Xcode installed and selected. The recorded environment uses Xcode 26.6; helpers support Apple Python 3.9.

```sh
brew install cmake ninja xcodegen
git clone --branch main https://github.com/chrissotraidis/etpad.git
cd etpad
/usr/bin/python3 scripts/prepare-game-data.py --download
scripts/build-etpad.sh --platform macos --output build/output
```

Supply the verified originals through a separate writable home, then launch the exported app:

```sh
mkdir -p build/profile-macos/etmain
cp game-data/etmain/pak[012].pk3 build/profile-macos/etmain/
'build/output/ETPad-mac/ET Legacy.app/Contents/MacOS/ET Legacy' \
  +set fs_basepath "$PWD/build/output/ETPad-mac" \
  +set fs_homepath "$PWD/build/profile-macos" +set fs_game legacy \
  +set r_fullscreen 0 +set r_mode -1 +set r_customwidth 1024 \
  +set r_customheight 768 +set com_introplayed 1 +set logfile 2
```

The build script initializes and checks the pristine pinned `libs` submodule. See [BUILDING.md](docs/BUILDING.md) for dependency-fetch recovery, optional Mac bots and lower-level commands. Sources, profiles and generated artifacts stay in ignored local directories.

## Build targets

Run builds serially from the repository root:

```sh
# Mac package and optional ZIP
scripts/build-etpad.sh --platform macos --output build/output \
  --zip build/output/ETPad-mac.zip

# iPad Simulator app
scripts/build-etpad.sh --platform simulator --output build/output

# Unsigned physical-device app and optional IPA
scripts/build-etpad.sh --platform device --output build/output \
  --ipa build/output/ETPad-unsigned.ipa
```

| Platform | Exported app/package |
| --- | --- |
| macOS | `build/output/ETPad-mac/ET Legacy.app` plus renderer/modules/notices |
| Simulator | `build/output/ETPad-simulator.app` |
| Device | `build/output/ETPad-device.app` and the requested unsigned IPA |

Build deployment settings are macOS 12.0 / iPadOS 16.0; minimum-OS hardware acceptance is separate. XcodeGen is required for iOS. Use the single reserved simulator through [`scripts/sim.sh`](scripts/sim.sh):

```sh
ETPAD_SIM_VISIBLE=1 ETPAD_SIM_HOLD_SECONDS=1800 \
  scripts/sim.sh test "$PWD/build/output/ETPad-simulator.app" \
  com.etpad.ETPad --etpad-oasis
```

Use `--etpad-host-only` for native setup/settings, or `touch build/simulator-stop` in another terminal to end the bounded run early. Never run the Mac game and Simulator together. [SIMULATOR.md](docs/SIMULATOR.md) explains the reserved device and landscape sensor controls.

ANGLE/GL4ES → Metal is the default iPad renderer. The optional Vulkan → MoltenVK → Metal simulator path also has gameplay acceptance. [Build/launch instructions](docs/BUILDING.md#optional-vulkanmoltenvk-simulator-renderer) and [performance measurements](docs/PERFORMANCE.md) document both; simulator observations do not establish physical-device performance or a controlled backend winner.

## Game data

You need the original **pak0.pk3, pak1.pk3 and pak2.pk3**. These are Wolfenstein: Enemy Territory data, available from [Splash Damage's official free download](https://www.splashdamage.com/games/wolfenstein-enemy-territory/), and remain subject to their original EULA.

On iPad, choose **Download Free Game Data** or import the three files through Files, wait for verification, then Play. On Mac, the quickstart helper downloads to ignored `game-data/etmain`; existing originals can instead be imported with:

```sh
/usr/bin/python3 scripts/prepare-game-data.py --import-from /path/to/etmain
```

Download/import checks SHA-256 before installing the complete set and never runs bundled installer/key programs. Native confirmed removal defers until the next launch if the engine has started. Original media, installers, saves and signing material are excluded from app exports. See [GAME_DATA.md](docs/GAME_DATA.md) for hashes, provenance and the licensing boundary.

## Controller and touch

| Controller input | Default action |
| --- | --- |
| Left / right stick | Analog movement / look |
| RT / LT | Fire / alternate weapon |
| A / B / X / Y | Jump / crouch / reload / use |
| L3 / R3 | Sprint / prone |
| Back / Start | Scoreboard / game menu |
| D-pad up / down / left / right | Map / limbo / previous / next weapon |
| Hold RB | Quick-chat wheel: point the right stick, release to send |
| Hold LB | Lean, votes, console and four quick chats on the D-pad |

Letters describe Xbox positions; PlayStation/MFi equivalents share the actions. Defaults load once per profile, remapping persists, and disconnect clears held inputs. [CONTROLS.md](docs/CONTROLS.md) contains every layer binding, native remapping and validation limits.

On iPad, the left thumb drives a floating movement stick (push it well past the rim, forward, to sprint) and the right thumb looks. FIRE is the large red button; hold it and slide to aim while firing. Jump, Reload, Alt and Crouch form an even inner ring around FIRE, with Use, weapon Next/Prev and Prone on an outer ring, all clear of ET's ammo and health HUD. Controls scale with the screen like ET's HUD. Score and Menu sit in the top-left gutter beside the ••• menu.

Every input works at any time. Touch controls hide while a controller or keyboard is in use and come back on the first touch, which never reaches the game as a shot. During play with a mouse or trackpad attached the pointer locks for mouse look; in menus it clicks normally.

The ••• menu keeps a short top level (match actions in a game, ways to play otherwise) with Settings and Help folders and Leave Match last. In ET menus the left stick moves the cursor, A clicks and B goes back; on the launcher and server list the D-pad moves the highlight. [CONTROLS.md](docs/CONTROLS.md) has the full reference.

## Online and local bots

The launcher's **Play Online** opens **Who's Playing Now**: ETPad asks the official ET masters, probes every server and lists the ET: Legacy ones with human and bot counts, map, version and ping. Tap a server to join (password prompt when needed), swipe to favorite it, or join by address. **iPad supports only the built-in Legacy mod**: executable modules are embedded with the app, and downloaded PK3 files supply data, never downloaded native code. First joins download the server's data packs through ET's own UDP download, limited by each server's rate.

**Practice with Bots** starts an offline round on Oasis, Goldrush, Radar, Battery, Fuel Dump or Rail Gun with 5, 9 or 15 bots, then opens team selection. Mac uses a separately prepared official Omni-bot 0.93 runtime; iPad bundles a source-built pinned bot framework and verified script/navigation data. See [Mac bot setup](docs/BUILDING.md#local-native-bots-macos) or [iPad bot setup](docs/BUILDING.md#local-native-bots-ipad).

## Documentation

| Guide | Contents |
| --- | --- |
| [Building](docs/BUILDING.md) | Build/launch commands, bots, optional Vulkan and package audit |
| [Performance](docs/PERFORMANCE.md) | Profiling method, host overhead measurements and device limits |
| [Game data](docs/GAME_DATA.md) | Official source, SHA-256 pins and EULA |
| [Controls](docs/CONTROLS.md) · [UI design](docs/UI-DESIGN.md) | Bindings, touch/menu behavior and inspected before/after layouts |
| [Handoff](docs/HANDOFF.md) | Current acceptance, evidence and outstanding gates |
| [Decisions](docs/DECISIONS.md) · [Goal](docs/GOAL.md) | Architecture, adaptation provenance and project requirements |

The read-only [`check-apple-package.py`](scripts/check-apple-package.py) audits architecture/platforms, dependencies, runtime paths, signatures and media boundaries. Mac PK3 native entries must match the separately exported own modules byte for byte; iPad Legacy packs are data-only. Dependency notices accompany exports.

For bug reports, include the commit, OS/hardware, settings, exact steps and a small relevant log. Native **Report a Problem** prepares user answers, device information and a bounded log for share-sheet review; it never posts automatically. Keep media, saves, signing material and credentials out of issues. Follow [SECURITY.md](SECURITY.md) for security-sensitive reports and [CONTRIBUTING.md](CONTRIBUTING.md) for upstream development guidance.

## Credits and licensing

ETPad builds on [ET: Legacy](https://github.com/etlegacy/etlegacy), derived from id Software and Splash Damage's Wolfenstein: Enemy Territory. Full upstream history is retained from baseline `f49e6db1e54eb292b4abe9e761210bf98522672f`. Apple integration uses SDL, GL4ES, ANGLE, Omni-bot and optional MoltenVK; adapted components credit UTP, TribesPad, GoldenPad and SunPad, with exact provenance in [DECISIONS.md](docs/DECISIONS.md).

Engine/mod source is GPLv3-or-later with the additional terms and exclusions below; see [COPYING.txt](COPYING.txt). The GPL Legacy mod pack is included, while original game media remains separately licensed and excluded. This does not relicense Wolfenstein: Enemy Territory's original assets.

## LICENSE

### ET: Legacy

Wolfenstein: Enemy Territory GPL Source Code
Copyright (C) 1999-2010 id Software LLC, a ZeniMax Media company.

OpenWolf GPL Source Code
Copyright (C) 2011 Dusan Jocic

XreaL GPL Source Code (renderer2)
Copyright (C) 2010-2011 Robert Beckebans

Quake3e GPL Source Code
Copyright (C) 2016 Eugene

ET: Legacy
Copyright (C) 2012-2024 ET:Legacy Team <mail@etlegacy.com>

  ET: Legacy is free software: you can redistribute it and/or modify it under
  the terms of the GNU General Public License as published by the Free Software
  Foundation, either version 3 of the License, or (at your option) any later
  version.

  ET: Legacy is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
  A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public License along with
  ET: Legacy (see COPYING.txt). If not, see <https://www.gnu.org/licenses/>.

  ADDITIONAL TERMS:  The Wolfenstein: Enemy Territory GPL Source Code is also
  subject to certain additional terms. You should have received a copy of these
  additional terms immediately following the terms and conditions of the GNU GPL
  which accompanied the Wolf ET Source Code.  If not, please request a copy in
  writing from id Software at id Software LLC, c/o ZeniMax Media Inc., Suite 120,
  Rockville, Maryland 20850 USA.

  EXCLUDED CODE:  The code described below and contained in the Wolfenstein:
  Enemy Territory GPL Source Code release is not part of the Program covered by
  the GPL and is expressly excluded from its terms.  You are solely responsible
  for obtaining from the copyright holder a license for such code and complying
  with the applicable license terms.


### MD4 Message-Digest Algorithm

Copyright (C) 1991-1992, RSA Data Security, Inc. Created 1991. All rights reserved.

  License to copy and use this software is granted provided that it is identified
  as the "RSA Data Security, Inc. MD4 Message-Digest Algorithm" in all mater
  ial mentioning or referencing this software or this function.

  License is also granted to make and use derivative works provided that such work
  s are identified as "derived from the RSA Data Security, Inc. MD4 Message-Digest
  Algorithm" in all material mentioning or referencing the derived work.

  RSA Data Security, Inc. makes no representations concerning either the merchanta
  bility of this software or the suitability of this software for any particular p
  urpose. It is provided "as is" without express or implied warranty of any
  kind.


### MD5 Message-Digest Algorithm

The MD5 algorithm was developed by Ron Rivest. The public domain C language
implementation used in this program was written by Colin Plumb in 1993, no copyright
is claimed.

  This software is in the public domain. Permission to use, copy, modify, and
  distribute this software and its documentation for any purpose and without fee is
  hereby granted, without any conditions or restrictions. This software is provided
  "as is" without express or implied warranty.
