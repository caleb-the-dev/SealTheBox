# Map Directory — Seal the Box
*Read this file at the start of every session to orient yourself before touching code.*

## What This Is
A living index of every system in the codebase. Each bucket file documents one system: what it does, where it lives, its public API, and known issues. Keep entries current — stale docs are worse than no docs.

---

## Meta
| Field | Value |
|-------|-------|
| Last groomed | 2026-05-02 |
| Sessions since groom | 2 |
| Groom trigger | 10 sessions |

---

## Bucket Files

| System | File | Status |
|--------|------|--------|
| Game State (autoload) | [game_state.md](game_state.md) | Active |
| Ability Library (autoload) | [ability_library.md](ability_library.md) | Active |
| Box Library (autoload) | [box_library.md](box_library.md) | Active |
| Box Definition (Resource) | [box_definition.md](box_definition.md) | Active |
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
  resources/
    ability_data.gd        # AbilityData Resource subclass
    box_definition.gd      # BoxDefinition Resource subclass (class_name BoxDefinition)
  scripts/
    globals/
      ability_library.gd   # Autoload: AbilityLibrary
      box_library.gd       # Autoload: BoxLibrary (no class_name — conflicts with autoload name)
      game_state.gd        # Autoload: GameState
    match/
      match.gd             # Root scene controller — all UI built here
      round_manager.gd     # Match-level orchestration
      tab_board.gd         # Tab sealing logic
      dice_pool.gd         # Dice draw/roll/discard
    run/
      run_manager.gd       # Series sequencing (3 boxes per run)
  scenes/
    match/
      match.tscn           # Main scene (script: match.gd)
  tests/
    test_run_manager.gd    # Tests for GameState + RunManager (headless)
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
Same pattern for BoxLibrary and GameState.

---

## Session Log
| Date | Summary |
|------|---------|
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
