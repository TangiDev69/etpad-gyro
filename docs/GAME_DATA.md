# Local game data

Official source page: https://www.splashdamage.com/games/wolfenstein-enemy-territory/

Download linked by that page (checked 2026-11-16): https://cdn.splashdamage.com/downloads/games/wet/et260b.x86_full.zip

Archive SHA-256: `2a8fef8e8558efffcad658bb9a8b12df8740418b3514142350eba3b7641eb3e0`.

Extracted the ZIP, then used Makeself `--noexec --keep --target downloads/et-linux-extracted`. Did not execute setup.sh, etkey.sh, makekey or bundled binaries. Copied only the three original etmain paks to ignored game-data/etmain for local testing.

| File | SHA-256 |
| --- | --- |
| pak0.pk3 | 712966b20e06523fe81419516500e499c86b2b4fec823856ddbd333fcb3d26e5 |
| pak1.pk3 | 5610fd749024405b4425a7ce6397e58187b941d22092ef11d4844b427df53e5d |
| pak2.pk3 | a48ab749a1a12ab4d9137286b1f23d642c29da59845b2bafc8f64e052cf06f3e |

Game media remains governed by the original EULA (local copy: downloads/et-linux-extracted/Docs/EULA_Wolfenstein_Enemy_Territory.txt), separate from GPL engine source. Never commit or redistribute these media, the installer, saves or builds. Native iPad download and Files import are implemented and simulator-verified. Evidence: ios-sim/native-download.log and data-import.png. Confirmed removal and redownload were also tested; removal after engine startup is deferred to the next launch. The current Python helper and native C extractor read only the fixed installer payload bytes, never run installer/key/setup programs, and verify all three hashes before replacing the installed set. Existing unrelated files such as etkey are retained. Exports contain no original media.
