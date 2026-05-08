# Map Directory — Seal the Box
*Read this file at the start of every session to orient yourself before touching code.*

## What This Is
A living index of every system in the codebase. Each bucket file documents one system: what it does, where it lives, its public API, and known issues. Keep entries current — stale docs are worse than no docs.

---

## Meta
| Field | Value |
|-------|-------|
| Last groomed | 2026-05-02 |
| Sessions since groom | 12 |
| Groom trigger | 10 sessions |

---

## Bucket Files

| System | File | Status |
|--------|------|--------|
| Game State (autoload) | [game_state.md](game_state.md) | Active |
| Ability Library (autoload) | [ability_library.md](ability_library.md) | Active |
| Box Library (autoload) | [box_library.md](box_library.md) | Active |
| Power Library (autoload) | [power_library.md](power_library.md) | Active |
| Power Manager (autoload) | [power_manager.md](power_manager.md) | Active |
| Box Definition (Resource) | [box_definition.md](box_definition.md) | Active |
| Power Data (Resource) | [power_data.md](power_data.md) | Active |
| Case Manager (autoload) | [case_manager.md](case_manager.md) | Active |
| Entity Library (autoload) | [entity_library.md](entity_library.md) | Active |
| Vignette Library (autoload) | [vignette_library.md](vignette_library.md) | Active |
| Event Library (autoload) | [event_library.md](event_library.md) | Active |
| Texture Roller (static class) | [texture_roller.md](texture_roller.md) | Active |
| Entity Data (Resource) | [entity_data.md](entity_data.md) | Active |
| Vignette Overlay (UI) | [vignette_overlay.md](vignette_overlay.md) | Active |
| Event Overlay (UI) | [event_overlay.md](event_overlay.md) | Active |
| Run Manager | [run_manager.md](run_manager.md) | Active |
| Tab Board | [tab_board.md](tab_board.md) | Active |
| Dice Pool | [dice_pool.md](dice_pool.md) | Active |
| Round Manager | [round_manager.md](round_manager.md) | Active |
| Match Scene + HUD | [match_scene.md](match_scene.md) | Active |
| HUD detail | [hud.md](hud.md) | Active |
| Ability Hand (UI) | [ability_hand.md](ability_hand.md) | Active |
| Dice Hand (UI) | [dice_hand.md](dice_hand.md) | Planned |
| Tab Display (UI) | [tab_display.md](tab_display.md) | Planned |

---

## Key File Locations
```
seal-the-box/
  project.godot
  data/
    abilities.csv          # ability definitions (22 abilities; 14 in rotation pool with charges 1–3)
    boxes.csv              # box definitions (5 boxes: classic, low_evens, high_odds, compressed, stairs)
    powers.csv             # power definitions (11 powers: lighter_box, eager, tab_9_bounty, bonus_seal, box_shutter, phoenix_down, coffee_break, survivor, tax_collector, diabolic_pact, tab_counter)
    entities.csv           # entity definitions (3 rows: diabolic, cosmic, ethereal; location_names semicolon-separated)
    vignettes.csv          # vignette definitions (3 default + 2 per entity = 9 total; pools: default, vig_diabolic, vig_cosmic, vig_ethereal)
    events.csv             # event definitions (1 default + 1 per entity = 4 total; pools: default, evt_diabolic, evt_cosmic, evt_ethereal)
  resources/
    ability_data.gd        # AbilityData Resource subclass
    box_definition.gd      # BoxDefinition Resource subclass (class_name BoxDefinition)
    power_data.gd          # PowerData Resource subclass (class_name PowerData)
    entity_data.gd         # EntityData Resource subclass (class_name EntityData): id, display_name, location_names[3], vignette_pool_id, event_pool_id
    vignette_data.gd       # VignetteData Resource subclass (class_name VignetteData): id, pool_id, text
    event_data.gd          # EventData Resource subclass (class_name EventData): id, pool_id, prompt, option_a/b labels + effects
  scripts/
    globals/
      ability_library.gd   # Autoload: AbilityLibrary
      box_library.gd       # Autoload: BoxLibrary (no class_name — conflicts with autoload name)
      game_state.gd        # Autoload: GameState
      power_library.gd     # Autoload: PowerLibrary (no class_name — conflicts with autoload name)
      entity_library.gd    # Autoload: EntityLibrary — parses entities.csv; get_entity(id), get_all(), get_random()
      vignette_library.gd  # Autoload: VignetteLibrary — parses vignettes.csv; get_pool(pool_id) -> Array
      event_library.gd     # Autoload: EventLibrary — parses events.csv; get_pool(pool_id) -> Array
    match/
      match.gd             # Root scene controller — all UI built here
      round_manager.gd     # Match-level orchestration + power effect hooks
      tab_board.gd         # Tab sealing logic
      dice_pool.gd         # Dice draw/roll/discard
      die.gd               # Die class (class_name Die) — single die object with faces, value, rolled, dropped
    run/
      case_manager.gd      # Autoload: CaseManager — 27-match Case sequence, run_won signal
      run_manager.gd       # Series sequencing; power offer + rotation + texture beat after each match
      power_manager.gd     # Autoload: PowerManager — applies power effects (no class_name)
      texture_roller.gd    # Static class: TextureRoller — rolls 50/30/20 beat (silent/vignette/event)
    ui/
      tooltip_button.gd    # TooltipButton class — custom Button with hover tooltip; used for ability and power pills
      vignette_overlay.gd  # VignetteOverlay — opaque overlay; shows vignette text; click to dismiss; emits dismissed
      event_overlay.gd     # EventOverlay — opaque overlay; shows event prompt + two buttons; applies effect DSL; emits resolved(option)
  scenes/
    match/
      match.tscn           # Main scene (script: match.gd)
    ui/
      vignette_overlay.tscn  # Minimal scene for VignetteOverlay (all UI in script _ready())
      event_overlay.tscn     # Minimal scene for EventOverlay (all UI in script _ready())
  tests/
    test_run_manager.gd    # Tests for GameState + RunManager + PowerLibrary (headless) — 46 tests
    test_power_effects.gd  # Tests for all 8 power effects via PowerManager (headless) — 30 tests
    test_box_definition.gd # Tests for BoxDefinition formulas (headless)
    test_case_manager.gd   # Tests for CaseManager (headless) — 10 tests
    test_crossroads.gd     # Tests for crossroads signal timing, HP cap, Whetstone die-swap, periodic swap removal (headless) — 8 tests
    test_entity.gd         # Tests for EntityLibrary, EntityData, entity variety in reset_run(), get_location_name(), TextureRoller entity-pool integration (headless) — 9 tests
    test_texture_roller.gd # Tests for TextureRoller distribution + empty-pool fallback + effect-string DSL parser (headless) — 9 tests
    test_tab_board.gd      # Tests for TabBoard sealing logic (headless)
    test_dice_pool.gd      # Tests for DicePool draw/roll/discard (headless)
```

---

## Singleton Access Pattern
All autoloads must be accessed via `Engine.get_singleton("Name")`. Bare global names work only in scene context and break in headless `--script` tests. In tests, register singletons manually:
```gdscript
var lib = load("res://scripts/globals/ability_library.gd").new()
lib._ready()
Engine.register_singleton("AbilityLibrary", lib)
```
Same pattern for BoxLibrary, GameState, PowerLibrary. PowerManager needs no `_ready()` call.

**Critical:** Autoload scripts that are also registered as singletons must NOT have a `class_name` declaration — GDScript will raise "Class hides an autoload singleton" parse error. Affected files: box_library.gd, power_library.gd, power_manager.gd, case_manager.gd.

**Critical:** Autoload scripts without `class_name` are NOT auto-registered as engine singletons — `Engine.has_singleton()` returns false for them unless `match.gd._ready()` explicitly calls `Engine.register_singleton()`. Omitting this causes a modulo-by-zero crash in `RunManager._start_next_match()` (the `_boxes` fallback array is empty). All 9 autoloads are registered in match.gd._ready() (AbilityLibrary, BoxLibrary, GameState, PowerLibrary, PowerManager, CaseManager, VignetteLibrary, EventLibrary, EntityLibrary).

---

## Session Log
| Date | Summary |
|------|---------|
| 2026-05-07 | feature/entity-types (slice 4 of the Case meta-flow). Three entity types (Diabolic, Cosmic, Ethereal) randomized per run. New: EntityData resource (id, display_name, location_names[3], vignette_pool_id, event_pool_id); EntityLibrary autoload (parses entities.csv, get_entity/get_all/get_random); data/entities.csv (3 rows, location_names semicolon-separated). Content: 2 vignettes per entity (6 new entries: v_sulfur_1/2, v_deep_1/2, v_echo_1/2) + 1 event per entity (e_brand, e_whisper, e_cold_room) in per-entity pool_ids. CaseManager.reset_run() now picks a random entity and writes GameState.entity_id; get_location_name(act) added. TextureRoller._get_pool_ids() added — reads entity from GameState instead of using caller-supplied pool_id param. match.gd: registered EntityLibrary (now 9 singletons); _location_label now shows entity-themed name via CaseManager.get_location_name(); _case_label added ("Case: [display_name]"); _run_won_title_label field added, _on_run_won() sets "[display_name] is sealed". GameState: entity_id field added, reset_run() clears it. New bucket files: entity_library.md, entity_data.md. test_entity.gd: 9 tests. test_texture_roller.gd: updated empty-pool-fallback test for entity-based pool resolution. |
| 2026-05-07 | feature/within-act-texture (slice 3 of the Case meta-flow). Between-match texture beat system: TextureRoller (static class) rolls 50% silent / 30% vignette / 20% event using VignetteLibrary and EventLibrary (both new autoloads). New resources: VignetteData (id, pool_id, text), EventData (id, pool_id, prompt, option_a/b_label/effect). New CSVs: vignettes.csv (3 entries: v_fog, v_bell, v_cold), events.csv (1 entry: e_coin — hp-1;charge_random+1 / none). New overlays: VignetteOverlay (click-to-dismiss), EventOverlay (two-button choice, applies effect DSL). Effect DSL: none, hp±N, charge_random+1; unknowns push_error and skip. Texture fires AFTER rotation/power-offer, BEFORE crossroads (crossroads matches 9 and 21 skip texture entirely). RunManager: added show_texture_beat signal, _do_texture_beat(), handle_texture_done(), dev_skip_texture(). match.gd: registered 2 new singletons (now 8 total), wired show_texture_beat, added overlay instances and handlers, dev "Win Entire Series" skips texture. test_texture_roller.gd: 9 headless tests (distribution, empty-pool fallback, effect DSL). New bucket files: vignette_library.md, event_library.md, texture_roller.md, vignette_overlay.md, event_overlay.md. |
| 2026-05-07 | feature/crossroads (slice 2 of the Case meta-flow). Replaced periodic die swap (every 5 matches) with Crossroads decision at act boundaries: after match 9 and 21 the player picks Rest (+2 HP, capped at MAX_HP=6) or Whetstone (die swap). RunManager: added show_crossroads signal, handle_crossroads_rest(), handle_crossroads_whetstone(), dev_skip_crossroads(). GameState: added MAX_HP=6 const; hp field and reset_run() use MAX_HP. match.gd: added _crossroads_overlay, wired show_crossroads signal, added crossroads button handlers, registered CaseManager singleton in _ready() (fixes launch crash). test_crossroads.gd: 8 new headless tests. 2 stale periodic-swap tests removed from test_run_manager.gd (now 46 tests). Also caught and fixed: CaseManager was never registered as engine singleton in match.gd, causing modulo-by-zero on launch. |
| 2026-05-07 | feature/case-shape (slice 1 of the Case meta-flow). Replaced infinite match loop with 27-match Case structure: CaseManager autoload builds a 27-match list (9 easy / 12 medium / 6 hard via BoxLibrary.get_by_tier()); GameState gains case_match_index, run_won, act (computed), location_index; RunManager defers box selection to CaseManager and emits CaseManager.run_won after match 27 via notify_run_won(); match.gd top bar now shows "Match N / 27", "Act N", "Location N"; run_won_overlay added ("the entity is sealed" + "Begin a new case"). Periodic die swap every 5 matches still present (removed in slice 2). test_case_manager.gd: 10 new headless tests. |
| 2026-05-06 | Implemented 8 new canonical abilities: Auto-Seal Highest, Auto-Seal Lowest (fire immediately, no die click; Non-Final; trigger power hooks), Multiply x2 (no ceiling, 1 charge), Set to Max, Set to Min, Reroll Lucky, Reroll Unlucky, Drop Die (dropped die shows [X], excluded from total + sealing, can't be targeted). Empower/Empower II now refuse to fire if die.value >= die.faces (prevents multiply-then-empower shrink). Die class gained dropped: bool. ABILITY_POOL_IDS expanded from 6 to 14. Give Ability dev menu added. All 14 abilities appear in rotation pool. test_ability_library.gd updated to 22 abilities. |
| 2026-05-06 | Three new counter powers: Tax Collector (3 critical wins → +1 HP), Diabolic Pact (7 d12 rolls → +1 HP), Tab Counter (5 tab seals → +1 charge to highest-charge ability). All counters changed to start at 0 (was 1) for consistent behavior. PowerManager: on_critical_win(), on_die_rolled(), on_tabs_sealed(), _apply_tab_counter_charge() added; apply_eager() now calls on_die_rolled(). RunManager: on_critical_win() called from handle_match_won(true). RoundManager: commit_roll() and use_ability() call on_die_rolled(); attempt_seal() calls on_tabs_sealed(). match.gd: "Switch Dice →" dev menu button added (mid-match pool swap, no match transition; uses stored index, not find()); _refresh_powers_panel() now fires immediately after rolling (commit_roll and reroll ability paths). Powers.csv: 8→11 powers. Tests: 48 (11 new). |
| 2026-05-05 | Counter infrastructure + Bonus Seal conversion. GameState: added power_counters Dictionary. PowerData: added counter_target field. powers.csv: 5th column counter_target (bonus_seal=3, all others=0). PowerManager: add_power() as unified acquisition entry point (initializes counter to 1); on_round_end() ticks bonus_seal counter each round; on_match_end() resets to 0; get_bonus_seals_if_ready() fires only when counter==target. RoundManager: on_round_end() hook in end_round(); on_match_end() at all 5 match-end paths. RunManager: handle_power_offer_accepted routes through PowerManager.add_power(). match.gd: powers panel shows "Name X/Y" for counter powers; _on_round_ended calls _refresh_powers_panel(). Counter starts at 1 (fires on round 3, then every 3 rounds). Tests: test_run_manager at 37 (7 new counter tests). |
| 2026-05-05 | Power balance + 3-offer + 3 new powers. Lighter Box tuned: +1/copy (was +3). Box Shutter tuned: +2/copy (was +5). powers.csv expanded to 8: added phoenix_down (failsafe, self-consumes), coffee_break (round-1 charge refill, capped at max), survivor (win-at-1HP heal). Power offer rebuilt as 1-of-3 card selection (highlight + Confirm/Skip). RunManager: show_power_offer now emits Array[PowerData]; apply_survivor() on every win; try_phoenix_down() intercept on loss. PowerLibrary: added get_random_unowned_multiple(). Dev menu: scrollable panels (ScrollContainer), expanded to 5–95% height, 8 powers in Give Power submenu. Powers panel: deduplicates stacked powers, shows count badge bottom-right. Coffee Break: only targets abilities below max_charges, caps addition at max. Tests: both suites at 30 tests each. |
| 2026-05-04 | First Powers slice. New systems: PowerData resource, PowerLibrary autoload, PowerManager autoload, data/powers.csv (5 powers). GameState: added owned_powers (persists across matches, cleared on reset_run) and pending_threshold_bonus (Box Shutter buffer). Dice pool bumped from 5 to 7 (1d4+4d6+2d8). RunManager: replaced dice reward with power offer (show_power_offer signal, Accept/Skip flow, Box Shutter hook). RoundManager: Lighter Box + pending bonus in start_match; Eager pre-roll in start_round round 1; Bonus Seal + Tab 9 Bounty in attempt_seal; dev_critical_win() added. match.gd: replaced reward overlay with power offer overlay; added right-side powers panel; dev menu additions (Shut the Box, Give Power submenu, Restart Run); fixed dice highlight to not grey unrolled dice in roll phase. Tests: test_power_effects.gd (18 tests); test_run_manager.gd updated (17 tests). |
| 2026-05-04 | Removed AP system entirely: dropped ap var, spend_ap(), ap_cost field from AbilityData + CSV, AP spend from commit_roll/start_round, AP badge from HUD. Rolling is now free. Updated all tests, docs, CLAUDE.md, GAME_BIBLE, and all map_directories bucket files. UI redesign: dice hand and abilities split into separate sub-panels (2/3 + 1/3); draw/discard pile counts moved into dice panel header with hover tooltips; Roll All + Roll Selected merged into single "Roll Dice (All/N)" button with "Select dice to roll" hint label above it; button becomes "Commit & End Round" in act phase. |
| 2026-05-04 | Ability rotation + charges system. Abilities now have charges (1–3); 3-slot fixed hand rotates after every match (slot 0 discarded, slots shift, player picks 1 of 3 new abilities into slot 3). Run starts with 1 random ability in slot 2. Critical wins: dice reward then rotation. Threshold wins: rotation only. Replaced ability-offer overlay with rotation overlay. Ability buttons show charges [N/M], orange tint on slot 0, grey-out at 0 charges. Die face label ("d6" etc.) appears bottom-right of die buttons after rolling. Continue button disabled during seal phase. Test suite rewritten: 15 tests. |
| 2026-05-04 | Replaced 3-match run with infinite match loop (boxes cycle: Classic → Low Evens → High Odds → repeat). Threshold wins no longer auto-end the match — a "Continue →" button appears and animates once when threshold is first breached; player decides when to advance. Only critical wins (shut the box) trigger the dice reward + ability offer flow. Removed run-won state and win overlay. Match label simplified to "Match: N". win_threshold moved from computed formula to explicit CSV column (Classic 20, Low Evens 17, High Odds 17). round_limit formula loosened by +1 (all boxes now 4 rounds before overtime). Reward dice pool restricted to standard faces [2,4,6,8,10,12]. |
| 2026-05-02 | Built series-based match structure: BoxDefinition Resource, BoxLibrary autoload, data/boxes.csv with 3 boxes. RunManager redesigned: box sequencing, reward only after final match, handle_reward_picked replaces advance_to_next_match. RoundManager.start_match() accepts BoxDefinition. match.gd: dynamic tab buttons, box label, remaining-sum counter, win threshold label, BoxLibrary singleton registration. Fixed synchronous-signal bug causing match 2 to start on round 2. Fixed win threshold display direction (remaining ≤ N, not sealed ≥ N). Updated test_run_manager.gd; added test_box_definition.gd. |
| 2026-05-01 | Initial build: full match loop, 3-match run structure, reward screen, win/over overlays, all UI in code. |

---

## System Template
See `docs/system_template.md` for the standard format for new bucket files.

---

## Grooming Notes
- Increment `sessions_since_groom` each session in wrapup.
- When `sessions_since_groom` reaches `groom_trigger`, run `/map-audit`.
- Mark a system **Stale** when its file no longer matches the code; mark **Active** once up to date.
