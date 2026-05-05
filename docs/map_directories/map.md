# Map Directory — Seal the Box
*Read this file at the start of every session to orient yourself before touching code.*

## What This Is
A living index of every system in the codebase. Each bucket file documents one system: what it does, where it lives, its public API, and known issues. Keep entries current — stale docs are worse than no docs.

---

## Meta
| Field | Value |
|-------|-------|
| Last groomed | 2026-05-02 |
| Sessions since groom | 5 |
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
    abilities.csv          # ability definitions (15 abilities; 6 in rotation pool with charges 1–3)
    boxes.csv              # box definitions (3 boxes: classic, low_evens, high_odds)
    powers.csv             # power definitions (8 powers: lighter_box, eager, tab_9_bounty, bonus_seal, box_shutter, phoenix_down, coffee_break, survivor)
  resources/
    ability_data.gd        # AbilityData Resource subclass
    box_definition.gd      # BoxDefinition Resource subclass (class_name BoxDefinition)
    power_data.gd          # PowerData Resource subclass (class_name PowerData)
  scripts/
    globals/
      ability_library.gd   # Autoload: AbilityLibrary
      box_library.gd       # Autoload: BoxLibrary (no class_name — conflicts with autoload name)
      game_state.gd        # Autoload: GameState
      power_library.gd     # Autoload: PowerLibrary (no class_name — conflicts with autoload name)
    match/
      match.gd             # Root scene controller — all UI built here
      round_manager.gd     # Match-level orchestration + power effect hooks
      tab_board.gd         # Tab sealing logic
      dice_pool.gd         # Dice draw/roll/discard
    run/
      run_manager.gd       # Series sequencing; power offer + rotation after critical wins
      power_manager.gd     # Autoload: PowerManager — applies power effects (no class_name)
  scenes/
    match/
      match.tscn           # Main scene (script: match.gd)
  tests/
    test_run_manager.gd    # Tests for GameState + RunManager + PowerLibrary (headless) — 30 tests
    test_power_effects.gd  # Tests for all 8 power effects via PowerManager (headless) — 30 tests
    test_box_definition.gd # Tests for BoxDefinition formulas (headless)
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

**Critical:** Autoload scripts that are also registered as singletons must NOT have a `class_name` declaration — GDScript will raise "Class hides an autoload singleton" parse error. Affected files: box_library.gd, power_library.gd, power_manager.gd.

---

## Session Log
| Date | Summary |
|------|---------|
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
