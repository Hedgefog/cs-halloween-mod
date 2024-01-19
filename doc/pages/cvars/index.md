### hwn_bots_cosmetic.amxx
| Cvar | Description | Default Value |
|---------|-------------|---------------|
| hwn_bots_cosmetics | 	Number of cosmetic items for bots | 2

### hwn_bots_spells.amxx
| Cvar | Description | Default Value |
|---------|-------------|---------------|
| hwn_bots_spells | Enable/Disable spells for bots | 1

### hwn_bosses.amxx
| Cvar | Description | Default Value |
|---------|-------------|---------------|
| hwn_boss_spawn_delay | Time before boss will be spawned | 300.0 |
| hwn_boss_life_time | Time to boss escape | 120.0 |
| hwn_boss_min_damage_to_win | Min damage to get reward for boss kill | 300 |
| hwn_boss_pve | Enable/Disable boss pve | 0 |
| hwn_boss_spawn_kill_radius | Radius of kill when boos attacks | 64.0 |


| Command | Description | Default Value |
|---------|-------------|---------------|
| hwn_boss_spawn | Spawn Boss command (Admin Access) | |
| hwn_boss_abort | Despawn Boss command (Admin Access) | |

### hwn_gamemode.amxx
| Cvar | Description | Default Value |
|---------|-------------|---------------|
| hwn_gamemode_respawn_time | Time to respawn in gamemode with player respawn | 5.0 |
| hwn_gamemode_spawn_protection_time | Godmode time after spawn in gamemode with player respawn | 3.0 |

### hwn_spellshop.amxx
| Cvar | Description | Default Value |
|---------|-------------|---------------|
| hwn_spellshop | Enable/Disable spellshop | 1 |
| hwn_spellshop_spell_price | Spell price in the spell shop | 500 |
| hwn_spellshop_spell_price_mult_rare | Price multiplier for rare spells in the shop | 1.5 |
| hwn_spellshop_spell_price_throwable | Throwable spell price in the spell shop | 300 |
| hwn_spellshop_spell_price_applicable | Applicable spell price in the spell shop | 150 |
| hwn_spellshop_spell_price_ability | Ability spell price in the spell shop | 550 |
| hwn_spellshop_spell_price_heal | Heal spell price in the spell shop | 600 |
| hwn_spellshop_spell_price_damage | Damage spell price in the spell shop | 800 |
| hwn_spellshop_spell_price_radius | Radius spell price in the spell shop | 650 |
| hwn_spellshop_spell_price_protection | Protection spell price in the spell shop | 750 |

### hwn_spellshop.amxx
| Cvar | Description | Default Value |
|---------|-------------|---------------|
| hwn_spells_give %targetId% %spellId% %amount% | Give player specific amount of spells |  |

### hwn.amxx
| Cvar | Description | Default Value |
|---------|-------------|---------------|
| hwn_fps | FPS for effects | 25 |
| hwn_npc_fps | FPS for NPC | 25 |
| hwn_enable_particles | Enable/Disable custom particles | 1 |


### entity_hwn_bucket.amxx
| Cvar | Description | Default Value |
|---------|-------------|---------------|
| hwn_bucket_health | Required damage to extract pumpkin from bucket | 300 |
| hwn_bucket_collect_flash | Enable/Disable flash effect on bucket | 1 |
| hwn_bucket_bonus_health | Health bonus on bucket filling | 10 |
| hwn_bucket_bonus_armor | Armor bonus on bucket filling | 10 |
| hwn_bucket_bonus_ammo | Ammo bonus on bucket filling (in ammo boxes) | 1 |
| hwn_bucket_bonus_chance | Chance to drop bonus from the bucket when collecting pumpkin | 5 |

### entity_hwn_item_pumpkin.amxx
| Cvar | Description | Default Value |
|---------|-------------|---------------|
| hwn_pumpkin_pickup_flash | Enable/Disable flash effect on filling the bucket | 1 |


### entity_hwn_item_spellbook.amxx
| Cvar | Description | Default Value |
|---------|-------------|---------------|
| hwn_spellbook_max_spell_count | Max count of spells that are given for spellbook pickup | 3 |
| hwn_spellbook_max_rare_spell_count | Max count of rare spells that are given for spellbook pickup | 1 |
| hwn_spellbook_rare_chance | Chance to spawn rare spell | 30 |

### entity_hwn_npc_hhh.amxx
| Cvar | Description | Default Value |
|---------|-------------|---------------|
| hwn_npc_hhh_use_astar | Use A* algorithm for Horseless Headless Horsemann | 1 |

### entity_hwn_npc_monoculus.amxx
| Cvar | Description | Default Value |
|---------|-------------|---------------|
| hwn_npc_monoculus_angry_time | Time of monoculus angry state | 15.0 |
| hwn_npc_monoculus_dmg_to_stun | Required damage count to stun monoculus | 2000.0 |
| hwn_npc_monoculus_jump_time_min | Min time of monoculus jump interval | 10.0 |
| hwn_npc_monoculus_jump_time_max | Max time of monoculus jump interval | 20.0 |

### entity_hwn_npc_skeleton.amxx
| Cvar | Description | Default Value |
|---------|-------------|---------------|
| hwn_npc_skeleton_use_astar | Enable / Disable Skeletons | 1 |

### entity_hwn_npc_spookypumpkin.amxx
| Cvar | Description | Default Value |
|---------|-------------|---------------|
| hwn_npc_spookypumpkin_use_astar | Enable / Disable Spooky Pumkin | 1 |
| hwn_pumpkin_mutate_chance | Chance mutation pumpkin in a spooky pumpkin | 20.0 |

### hwn_boss_healthbar.amxx
| Cvar | Description | Default Value |
|---------|-------------|---------------|
| hwn_boss_healthbar | Enable/Disable healthbar for bosses | 1 |

### hwn_objective_marks.amxx
| Cvar | Description | Default Value |
|---------|-------------|---------------|
| hwn_objective_marks | Enable / Disable objective marks | 1 |

### hwn_player_highlight.amxx
| Cvar | Description | Default Value |
|---------|-------------|---------------|
| hwn_player_highlight | Enable / Disable player highlight | 1 |
| hwn_player_highlight_primary_brightness | Value of primary player brightness | 80 |
| hwn_player_highlight_secondary_brightness | Value of secondary player brightness | 15 |

### hwn_crits.amxx
| Cvar | Description | Default Value |
|---------|-------------|---------------|
| hwn_crits_damage_multiplier | Crit damage multiplier | 2.2 |
| hwn_crits_effect_trace | Enable/Disable crit trace effect (2 - only on hit) | 1 |
| hwn_crits_effect_splash | Enable/Disable crit splash effect (2 - only on hit) | 1 |
| hwn_crits_effect_flash | Enable/Disable crit flash effect (2 - only on hit) | 1 |
| hwn_crits_sound_use | Enable/Disable crit use sound | 1 |
| hwn_crits_sound_hit | Enable/Disable crit hit sound | 1 |
| hwn_crits_sound_shoot | Enable/Disable crit shoot sound | 1 |
| hwn_crits_random | Enable/Disable random crits | 1 |
| hwn_crits_random_chance_initial | Initial crit chance | 0.0 |
| hwn_crits_random_chance_max | Maximum crit chance | 12.0 |
| hwn_crits_random_chance_bonus | Chance hit bonus | 1.0 |
| hwn_crits_random_chance_penalty | Change miss penalty | 2.0 |

| Command | Description | Default Value |
|---------|-------------|---------------|
| hwn_crits_toggle %targetId% | Enable / Disable crits for player | |

### hwn_gifts.amxx
| Cvar | Description | Default Value |
|---------|-------------|---------------|
| hwn_gifts_spawn_delay | Time before new gift will be spawned | 300.0 |
| hwn_gifts_cosmetic_min_time | Min time of hat from gift | 450.0 |
| hwn_gifts_cosmetic_max_time | Max time of hat from gift | 1200.0 |

### hwn_player_cosmetics.amxx
| Cvar | Description | Default Value |
|---------|-------------|---------------|
| hwn_pcosmetic_menu_preview | Enable/Disable player cosmetic preview | 1 |
| hwn_pcosmetic_menu_preview_light | Enable/Disable light source in player cosmetic preview | 1 |

### hwn_wof.amxx
| Cvar | Description | Default Value |
|---------|-------------|---------------|
| hwn_wof_enabled | Enable / Disable WOF effects | 1 |
| hwn_wof_delay | WOF effects delay | 90.0 |
| hwn_wof_effect_time | Wheel of fate effect time | 20.0 |

| Command | Description | Default Value |
|---------|-------------|---------------|
| hwn_wof_roll | Start roll | |
| hwn_wof_abort | Abort roll | |

### hwn_gamemode_collector.amxx
| Cvar | Description | Default Value |
|---------|-------------|---------------|
| hwn_collector_teampoints_limit | Limit of teampoints in Collector Gamemode | 50 |
| hwn_collector_roundtime | Round time in Collector Gamemode (in minutes) (0 - to disable) | 10 |
| hwn_collector_roundtime_overtime | Overtime time in Collector Gamemode (in seconds) (0 - to disable) | 30 |
| hwn_collector_npc_drop_chance_spell | Chance that NPC drop spellbook on death | 10.0 |
| hwn_collector_teampoints_to_boss_spawn | Total team points to spawn boss (0 - to disable) | 20 |
| hwn_collector_teampoints_reward | Pumpkin collecting reward | 150 |

### hwn_gamemode_default.amxx
| Cvar | Description | Default Value |
|---------|-------------|---------------|
| hwn_gamemode_change_lighting | Enable/Disable custom light in default gamemode | 1 |
| hwn_gamemode_spells_on_spawn | Number of spells on spawn in default gamemode | 1 |
| hwn_gamemode_random_events | Enable/Disable spawn npc/items in default gamemode | 1 |

### hwn_player_highlight.amxx
| Command | Description | Values |
|---------|-------------|---------------|
| hwn_player_effect_set %targetId% %effectId% %value% %duration% | Set effect for player | |


