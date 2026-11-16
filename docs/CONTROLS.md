# Controller defaults (experimental)

SDL GameController supplies family-independent physical positions for supported MFi, Xbox and PlayStation controllers. Apple builds enable this by default and execute `etpad-controller.cfg` once per profile (versioned preference). To restore the defaults, execute that file again. Bindings remain editable through ET's console; native mapping UI and family prompts are pending.

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

Letters describe Xbox positions; PlayStation bottom/right/left/top and MFi equivalents use the same actions. Family-specific on-screen prompts are not implemented. Trigger actions remain available while holding a shoulder. A held action releases using its original binding even when the shoulder is released first. Detachment releases held actions and clears movement axes.

Validation: real SDL virtual-controller test passes bank changes, release ordering, disabling the option while held, trigger routing and disconnect cleanup. This is component evidence, not physical-controller play. No controller-connected game screenshot or physical-controller session exists yet.
