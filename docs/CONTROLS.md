# Apple controls (experimental)

## Controller defaults

SDL GameController supplies family-independent physical positions for Xbox, PlayStation and MFi controllers. \`etpad-controller.cfg\` runs once per profile (\`etpad_bindingsVersion\` 2); every button is one plain key with no hidden layers.

| Input | Action |
| --- | --- |
| Left / right stick | Move / look (analog, see below) |
| RT / LT | Fire / alternate fire or scope |
| A / B / X / Y | Jump / crouch / reload / grenade (weaponbank 4, then RT throws) |
| LB | Use: doors, ladders, objectives (+activate) |
| Hold RB | Quick-chat wheel |
| L3 / R3 | Sprint / prone |
| View / Menu | Scoreboard (hold) / game menu, whose first item is Team & Class |
| D-pad right | Next weapon, cycling everything including tools |
| D-pad left | Last weapon (weaplastused): rifle ↔ pistol, or back from a grenade |
| D-pad up | Class tool, bank 5: syringe, pliers, smoke marker |
| D-pad down | Class item, bank 6: dynamite, health pack, ammo pack, satchel |

Landmines/adrenaline (bank 7) and binoculars (bank 8) are reached with D-pad right, and every button can be reassigned in Settings › Controller › Buttons, which also lists knife, pistol, main weapon, lean, command map and votes. Command map and votes are also in the ••• menu. Version 2 replaced the former hold-LB/hold-RB layers, which players found hard to discover.

The quick-chat wheel holds Medic!, Need Ammo, Need Backup, Need Engineer, Negative, Thanks, Cover Me and Affirmative. Point the right stick (it stops turning the view while the wheel is open) and release RB to send; the center shows whether the team or everyone hears it. On touch, CHAT opens it and one tap sends. Keyboard players keep ET's own V quick-message menu.

The game view controller is a GCEventViewController with controller user interaction disabled, so controller presses no longer reach UIKit, which had highlighted on-screen buttons such as the top-left ••• capsule.

## Keyboard and mouse

ET's default binds apply (checked on the iPad profile): W A S D move, Space jump, C crouch, X prone, Shift sprint, R reload, F use, Q/E lean, 1–0 weapon banks, mouse wheel weapons, Tab scores, V quick messages, Esc menu, ~ console. Left click fires, right click is alternate fire.

## Stick handling (Apple builds)

Both sticks are read directly as analog axes every frame, independent of PAD0 stick binds. A radial dead zone (in_joystickThreshold, default 0.18) keeps diagonals smooth. Movement is linear. Look uses a 1.8 power curve for fine aim near center; full tilt turns about 230°/s horizontally (j_yaw −0.007) and 180°/s vertically (j_pitch 0.0055). Settings › Controller › Look Speed scales both, and Invert Look flips vertical look. While the quick-chat wheel is open, the right stick selects a message instead of looking. Triggers remain keys (RT +attack, LT weapalt).

Earlier builds sent right-stick look from SDL axis events as abs(value/8000) × j_yaw, which truncated to zero and overwrote the polled value, so the right stick did nothing. That path is disabled on Apple builds.

## iPad touch controls

The left thumb drives a floating stick that is invisible at rest and appears wherever the thumb lands on the left half of the screen, disappearing again on release. While moving buttons, its usual starting point is shown as a guide. Pushing well past the rim while mostly forward holds Sprint (the stick turns brass and shows SPRINT); Touch Settings can turn this off. The right thumb looks from anywhere on the right half, scaled by Look Speed.

FIRE is a 104-point red button above-left of ET's ammo and weapon HUD. Holding it fires, and sliding the same finger aims. Two even rings surround it, placed from angles so every gap matches:

| Ring | Buttons (counter-clockwise from upper right) | Size |
| --- | --- | --- |
| Inner (radius 98) | JUMP, RELOAD, ALT, CROUCH | 62 |
| Outer (radius 172) | USE, NEXT, PREV, PRONE | 52 |

Sizes and distances are in points for an 11-inch iPad and scale with the screen the same way ET's 640×480 HUD does (about 1.19× on 12.9-inch). Size multiplies them further. SCORE, MENU and CHAT stay in the fixed top-left column under the ••• capsule. SCORE is a toggle: tap to open the scoreboard and tap again to close it. While the scoreboard is open, the other column buttons and ••• hide and SCORE moves to the bottom-left corner, clear of the tables. MENU opens ET's game menu; a Back capsule beside ••• then closes any ET menu (game menu, Team & Class, console) with Escape, so touch players are never stuck. Left-handed mode mirrors the stick and rings and lifts default combat buttons 150 points above the health HUD; saved custom positions keep their coordinates. Older saved configurations and named layouts load unchanged.

Resting faces are smoked black with a cream ring; pressed buttons turn brass, and FIRE turns oxblood. Opacity changes faces only.

## Switching between touch, controller and keyboard

The input used last decides what is shown. A controller connecting or any of its buttons switches to controller mode. A hardware keyboard or mouse connecting, a key press, mouse or trackpad pointer movement (Apple Pencil hover is ignored) or locked-mouse movement switches to keyboard and mouse mode. The next finger on the screen restores touch controls and is not delivered to the game. With Settings › Touch Controls › Hide While Using a Controller or Keyboard on (the default), touch controls hide in the other two modes. For eight seconds after a switch, a chip under the top edge names that input's key controls.

During play with a mouse or trackpad connected in keyboard and mouse mode, the pointer locks: mouse movement aims, left click fires, right click is alternate fire. ET's own menus then follow the mouse as their cursor.

The quick-chat wheel accepts every input at once: a stick points (right or left), A or releasing RB sends, B cancels, and a tap on a wedge sends. While it is open, new controller presses go to the wheel instead of the game.

On the launcher, a controller's D-pad or left stick moves a brass highlight across Play Online, Practice with Bots and Main Menu; A selects. In Who's Playing Now, up/down selects a server, A joins, Y refreshes and B closes. In ET's own menus the left stick moves the cursor, A clicks and B goes back.

## Typing without a hardware keyboard

When ET is editing one of its own text fields (profile name, chat, server password, search boxes) or the console is open, and no hardware keyboard is connected, ETPad raises the iPad keyboard. Typed characters go straight to the game field. Delete sends both K_BACKSPACE and the Ctrl-H character, because ET's UI text fields delete only on the character (desktop SDL sends both for the same reason). Return and the bar's Done (Enter) and Cancel (Escape) act as keys. Hardware keys reach ET through SDL's GCKeyboard input, so UIKit's copy of the same text is dropped while a hardware key is down. The bar above the keyboard shows the field's current text, because ET's chat box can sit under the keyboard. The keyboard closes when the field loses focus. The UI module answers a private ETPAD_VM_UI_TEXT_EDITING query, so detection follows ET's actual edit state.

## Native three-dot menu

The ••• menu holds actions only. In a match: Team & Class…, Chat ▸ (quick-chat wheel, say to team, say to everyone), Vote ▸, Command Map and Game Menu; then Play Elsewhere ▸ (Find a Server, Practice with Bots, Join by Address), Settings… and Help ▸; and Leave Match alone at the bottom. Outside a match: Find a Server, Practice with Bots ▸ and Join by Address…, then Settings… and Help ▸.

**Settings…** opens one sheet with sections for Touch Controls (show, hide during other input, size, opacity, look speed, push-to-sprint, left-handed, move buttons, saved layouts, restore defaults), Controller (look speed, invert look, buttons), Keyboard and Mouse (sensitivity, invert, key reference), Graphics (resolution, field of view, FPS counter), Player name and Game Data. The section for the input in use comes first.

## Scoreboard and intermission

The new implementation reads actual engine scoreboard/intermission flags through the VM context. Those states hide combat controls and the controller hint, release combat actions and zero movement/look input. SCORE and MENU remain available in the gutter; entering the state does not synthesize `-scores`, so a held SCORE control can receive its normal release. Actual `+scores` state and a 1.5-second native SCORE hold were checked: combat controls and the hint disappear, player columns/headings remain clear, and release closes the scoreboard and restores controls without a stranded score state.

## Verified behavior and limits

The earlier visual-hierarchy design pass verified both landscape directions; first-tap **Team & Class → Allies → engineer → OK** spawn; holding FIRE from 30 to 25 rounds and releasing without continued fire; RELOAD to 30/25; mirrored left-handed layout at Size 0.7; and consistent controller auto-hide switches. Evidence: [active gameplay](evidence/ios-sim/design-after-gameplay.png), [menu](evidence/ios-sim/design-after-menu.png), [Controls submenu](evidence/ios-sim/design-after-controls-menu.png) and [small left-handed layout](evidence/ios-sim/design-left-small.png). Those images show the historical first-pass utility layout, not acceptance of the new HUD-aware defaults. The [design audit](UI-DESIGN.md) records the subsequent live-HUD placement corrections and their accepted screenshot evidence.

The HUD-aware follow-up adds three inspected captures: [normal Oasis layout](evidence/ios-sim/placement-after-live.png), [unobstructed scoreboard](evidence/ios-sim/placement-after-scoreboard.png) and [corrected Size 0.7 left-handed Fuel Dump layout](evidence/ios-sim/placement-after-small-left.png). They show the new USE/weapon arc, gutter anchors, clear killfeed/compass in the normal case, and raised default combat controls clear of the left health/class HUD and two-line killfeed in the small left-handed case. These are acceptance of those observed states, not every ET HUD configuration.

These checks use injected simulator input. Physical controller/keyboard/trackpad feel, simultaneous physical multi-touch, thumb reach, VoiceOver behavior, large-text/localization behavior and contrast across all scenes remain unverified. Arrange mode and saved-layout flows exist; physical dragging and play comfort still need an iPad. No physical-play or accessibility-compliance claim is made.
