# hwn_event_handler

> Handle mod events and activate target.

### PARAMS
| Param      | Description        | Type   | Default Value |
|------------|--------------------|--------|---------------|
| targetname | event name         | string |               |
| target     | target to activate | string |               |


### EVENTS
| Event               | Description                   |
|---------------------|-------------------------------|
| new_round           | New round.                    |
| round_start         | Round start.                  |
| round_end           | Round end.                    |
| boss_spawn          | Boss spawned.                 |
| boss_remove         | Boss entity removed.          |
| boss_kill Boss      | killed.                       |
| boss_escape         | Boss escaped.                 |
| boss_teleport       | Boss teleport to spawn.       |
| boss_winner         | For each boss winner.         |
| teampoints_team1    | Terrorist team collect point. |
| teampoints_team2    | CT team collect point.        |
| playerpoints        | Player collect point.         |
| spell_cast          | Player cast spell.            |
| wof_roll_start      | Wheel of Fate roll start.     |
| wof_roll_end        | Wheel of Fate roll end.       |
| wof_effect_start    | Wheel of Fate effect start.   |
| wof_effect_end      | Wheel of Fate effect end.     |
| wof_effect_invoke   | Wheel of Fate invoke.         |
| wof_effect_revoke   | Wheel of Fate revoke          |
| wof_abort           | Wheel of Fate abort           |