# Apple controls (experimental)

## Controller defaults

SDL GameController supplies family-independent physical positions for supported MFi, Xbox and PlayStation controllers. Apple builds enable this by default and execute `etpad-controller.cfg` once per profile (versioned preference). To restore the defaults, execute that file again. Bindings remain editable through ET's console; iOS offers native button mapping and family prompts; macOS bindings use the console.

| Input | Action |
| --- | --- |
| Left stick | Analog movement |
| Right stick | Analog look |
| RT / LT | Fire / alternate weapon |
| A / B / X / Y | Jump / crouch / reload / use |
| L3 / R3 | Sprint / prone |
| Back / Start | Scoreboard / game menu |
| D-pad up / down / left / right | Map / limbo / previous / next weapon |
| Hold LB + A / B | Lean left / right |
| Hold LB + X / Y | Vote yes / no |
| Hold LB + Back / Start / L3 | Console / team / class menu |
| Hold LB + D-pad up / down / left / right | Medic / need ammo / thanks / affirmative team quick chat |
| Hold RB + L3 / R3 / D-pad up / down | Weapon banks 1 / 2 / 3 / 4 |
| Hold RB + A / B / X / Y / Back / Start | Weapon banks 5 / 6 / 7 / 8 / 9 / 10 |

Letters describe Xbox positions; PlayStation bottom/right/left/top and MFi equivalents use the same actions. iOS prompts distinguish Xbox, PlayStation and generic MFi-style labels. Trigger actions remain available while holding a shoulder. A held action releases using its original binding even when the shoulder is released first. Detachment releases held actions and clears movement axes.

Controller validation: the SDL virtual-controller component test passes bank changes, release ordering, disabling the option while held, trigger routing and disconnect cleanup. This is component evidence, not physical-controller play. Simulator prompts use a virtual Gamepad; no physical MFi/Xbox/PlayStation controller was available.

## iPad touch controls

The left thumb drives a floating stick. Its resting ring sits right of ET's portrait and slot HUD to show where to start; a touch anywhere on the left half moves it under the finger. Pushing well past the rim while mostly forward holds Sprint (the stick turns brass and shows SPRINT); Touch Settings can turn this off. The right thumb looks from anywhere on the right half, scaled by Look Speed.

FIRE is a 104-point red button above-left of ET's ammo and weapon HUD. Holding it fires, and sliding the same finger aims. Two even rings surround it, placed from angles so every gap matches:

| Ring | Buttons (counter-clockwise from upper right) | Size |
| --- | --- | --- |
| Inner (radius 98) | JUMP, RELOAD, ALT, CROUCH | 62 |
| Outer (radius 172) | USE, NEXT, PREV, PRONE | 52 |

Sizes and distances are in points for an 11-inch iPad and scale with the screen the same way ET's 640×480 HUD does (about 1.19× on 12.9-inch). Size multiplies them further. SCORE (hold) and MENU stay in the fixed top-left gutter beside the ••• capsule. Left-handed mode mirrors the stick and rings and lifts default combat buttons 150 points above the health HUD; saved custom positions keep their coordinates. Older saved configurations and named layouts load unchanged.

Resting faces are smoked black with a cream ring; pressed buttons turn brass, and FIRE turns oxblood. Opacity changes faces only.

## Switching between touch, controller and keyboard

The input used last decides whether touch controls show (Settings › Touch Controls › Hide During Controller or Keyboard Play, on by default). Connecting a controller or pressing any of its buttons switches to controller mode; any key or locked-mouse movement switches to keyboard mode; the next finger on the screen restores touch controls and is not delivered to the game. Hiding the overlay releases only commands touch was holding, so the controller press that caused the switch keeps working.

With a mouse or trackpad connected, the pointer locks during play: SDL delivers mouse look, left click fires and right click is alternate fire. In menus, the launcher and native sheets the pointer is unlocked and clicks through UIKit; SDL's duplicate mouse events are ignored then, so one click is one click.

In ET's own menus (main menu, Limbo team/class selection, Host Game, server browser) the left stick moves ET's mouse cursor with a curved speed response, A clicks and B sends Escape to go back. On the launcher, a controller's D-pad or left stick moves a brass highlight across Play Online, Practice with Bots and Main Menu; A selects (Practice starts the last practice map). In Who's Playing Now, up/down selects a server, A joins, Y refreshes and B closes. B also closes guides and settings sheets.

## Native three-dot menu

The top level stays short. In a match it shows Team & Class…, Game Menu, Chat ▸, Vote ▸ and Command Map; elsewhere it shows Find a Server, Practice with Bots ▸ and Join by Address…. Below that come three folders: **Play Elsewhere** (in a match only: Find a Server, Practice, Join by Address), **Settings** (Touch Controls, Controller Buttons, Graphics, Player Name, Game Data) and **Help** (How to Play, Console, Game Keyboard, Report a Problem, GitHub). **Leave Match** sits alone at the bottom with a confirmation.

## Scoreboard and intermission

The new implementation reads actual engine scoreboard/intermission flags through the VM context. Those states hide combat controls and the controller hint, release combat actions and zero movement/look input. SCORE and MENU remain available in the gutter; entering the state does not synthesize `-scores`, so a held SCORE control can receive its normal release. Actual `+scores` state and a 1.5-second native SCORE hold were checked: combat controls and the hint disappear, player columns/headings remain clear, and release closes the scoreboard and restores controls without a stranded score state.

## Verified behavior and limits

The earlier visual-hierarchy design pass verified both landscape directions; first-tap **Team & Class → Allies → engineer → OK** spawn; holding FIRE from 30 to 25 rounds and releasing without continued fire; RELOAD to 30/25; mirrored left-handed layout at Size 0.7; and consistent controller auto-hide switches. Evidence: [active gameplay](evidence/ios-sim/design-after-gameplay.png), [menu](evidence/ios-sim/design-after-menu.png), [Controls submenu](evidence/ios-sim/design-after-controls-menu.png) and [small left-handed layout](evidence/ios-sim/design-left-small.png). Those images show the historical first-pass utility layout, not acceptance of the new HUD-aware defaults. The [design audit](UI-DESIGN.md) records the subsequent live-HUD placement corrections and their accepted screenshot evidence.

The HUD-aware follow-up adds three inspected captures: [normal Oasis layout](evidence/ios-sim/placement-after-live.png), [unobstructed scoreboard](evidence/ios-sim/placement-after-scoreboard.png) and [corrected Size 0.7 left-handed Fuel Dump layout](evidence/ios-sim/placement-after-small-left.png). They show the new USE/weapon arc, gutter anchors, clear killfeed/compass in the normal case, and raised default combat controls clear of the left health/class HUD and two-line killfeed in the small left-handed case. These are acceptance of those observed states, not every ET HUD configuration.

These checks use injected simulator input. Physical controller/keyboard/trackpad feel, simultaneous physical multi-touch, thumb reach, VoiceOver behavior, large-text/localization behavior and contrast across all scenes remain unverified. Arrange mode and saved-layout flows exist; physical dragging and play comfort still need an iPad. No physical-play or accessibility-compliance claim is made.
