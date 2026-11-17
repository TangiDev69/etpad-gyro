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

The HUD-aware source update keeps movement on the left and look on the right, removing the former left-side utility diamond. USE now sits beside the right-thumb FIRE group, with PREV/NEXT beside weapon actions. SCORE and MENU occupy a fixed upper-left HUD gutter with the native ellipsis during active play. The resulting normal layout is visually verified in active Oasis gameplay; the corrected small left-handed layout is verified on Fuel Dump.

| Default control | Safe-area placement at normal size |
| --- | --- |
| Native ellipsis during active gameplay | Rectangle x=12–76, y=12–56 |
| SCORE | Center (44, 88), fixed 64×44 points |
| MENU | Center (44, 142), fixed 64×44 points |
| USE | 172 points from the right, 190 from the bottom; 56-point face |
| PREV | 250 from the right, 263 from the bottom; 48-point face |
| NEXT | 250 from the right, 190 from the bottom; 48-point face |

Gameplay positions respond to viewport and Size. Left-handed mode mirrors the combat/movement/look sides, but the **default HUD gutter stays left**, because the game's HUD does not mirror. Default left-handed combat positions also move **180 UIKit points upward** to clear the fixed health/class HUD and two-line killfeed; an initial naive mirror overlapped that HUD and was corrected before acceptance. This lift applies only to defaults. Explicitly saved custom centers retain their chosen coordinates and prior mirroring behavior. Restore Default Layout adopts the new defaults. Rendered ET main/Limbo menus retain the native ellipsis's upper-right anchor.

Controls use SF Symbols with short labels, a larger primary FIRE button and compact secondary/utility buttons. Resting faces are black/translucent; only pressed controls receive action color. Opacity changes the face without fading the white icon/label. Move/look guides appear only during a gesture or Arrange Controls. The implementation clamps final button width/height to at least 44 UIKit points, including at Size 0.7; this is a code property, not physical comfort certification.

Open the white three-dot capsule → **Controls**:

| Item | Behavior |
| --- | --- |
| Show Controls | Show or hide the touch overlay |
| Auto-Hide Controls | Hide touch controls while a controller is connected |
| Touch Settings… | Opacity, size, left-handed mode, controller hiding, saved layouts and defaults |
| Arrange Controls | Enter layout editing; finish with Done Arranging Controls or MENU |
| Button Mapping… | View/edit controller bindings and restore defaults |

**Auto-Hide Controls** and **Touch Settings → Hide with controller** edit one shared preference; their states stay consistent. Touch configuration, named layouts and controller bindings persist. The connected-controller prompt also opens button mapping. Its new gameplay hint lasts eight seconds after connection and hides for scoreboard/intermission; host-only setup keeps the hint available. Button mapping remains accessible from the native menu afterward. The final simulator build renders Button Mapping… and the visibility/touch-setting labels on single lines. Opening Button Mapping… presents the proper mapping sheet; Done returns to the game.

## Native three-dot menu

The menu groups immediate **Play** actions separately from **Settings** and **Tools**:

- Play: Game Menu, Team & Class…, Toggle Map. Team & Class opens ET's Limbo selection directly.
- Settings: Controls, Display, Online, Game Data & Saves.
- Tools: Console and Game Keyboard. Report a Problem remains separately identifiable.

Game Menu opens ET's existing rendered UI; the native menu does not replace it. Native touch/hover pointers enter the built-in UI/cgame frameworks through the engine's VM context. SDL handles GameController keyboard/mouse devices; UIKit hardware-key fallback avoids duplicate delivery when GCKeyboard is present.

## Scoreboard and intermission

The new implementation reads actual engine scoreboard/intermission flags through the VM context. Those states hide combat controls and the controller hint, release combat actions and zero movement/look input. SCORE and MENU remain available in the gutter; entering the state does not synthesize `-scores`, so a held SCORE control can receive its normal release. Actual `+scores` state and a 1.5-second native SCORE hold were checked: combat controls and the hint disappear, player columns/headings remain clear, and release closes the scoreboard and restores controls without a stranded score state.

## Verified behavior and limits

The earlier visual-hierarchy design pass verified both landscape directions; first-tap **Team & Class → Allies → engineer → OK** spawn; holding FIRE from 30 to 25 rounds and releasing without continued fire; RELOAD to 30/25; mirrored left-handed layout at Size 0.7; and consistent controller auto-hide switches. Evidence: [active gameplay](evidence/ios-sim/design-after-gameplay.png), [menu](evidence/ios-sim/design-after-menu.png), [Controls submenu](evidence/ios-sim/design-after-controls-menu.png) and [small left-handed layout](evidence/ios-sim/design-left-small.png). Those images show the historical first-pass utility layout, not acceptance of the new HUD-aware defaults. The [design audit](UI-DESIGN.md) records the subsequent live-HUD placement corrections and their accepted screenshot evidence.

The HUD-aware follow-up adds three inspected captures: [normal Oasis layout](evidence/ios-sim/placement-after-live.png), [unobstructed scoreboard](evidence/ios-sim/placement-after-scoreboard.png) and [corrected Size 0.7 left-handed Fuel Dump layout](evidence/ios-sim/placement-after-small-left.png). They show the new USE/weapon arc, gutter anchors, clear killfeed/compass in the normal case, and raised default combat controls clear of the left health/class HUD and two-line killfeed in the small left-handed case. These are acceptance of those observed states, not every ET HUD configuration.

These checks use injected simulator input. Physical controller/keyboard/trackpad feel, simultaneous physical multi-touch, thumb reach, VoiceOver behavior, large-text/localization behavior and contrast across all scenes remain unverified. Arrange mode and saved-layout flows exist; physical dragging and play comfort still need an iPad. No physical-play or accessibility-compliance claim is made.
