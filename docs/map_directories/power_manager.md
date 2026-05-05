# Power Manager
*Autoload singleton — applies active power effects at the right game moments.*

## Location
`scripts/run/power_manager.gd` (Autoload: `PowerManager`, no class_name — avoids singleton name conflict)

## Responsibility
Expose one method per power effect. Each method reads `GameState.owned_powers`, counts relevant power copies, and applies the effect. Does not own state — it mutates GameState or returns computed values. Called directly by RoundManager and RunManager at the appropriate hooks.

## Public API
```gdscript
func count_owned(power_id: String) -> int
    # Returns how many copies of the given power id are in GameState.owned_powers.
    # Stacked powers (e.g. 2x Lighter Box) return 2.

func get_threshold_bonus() -> int
    # Returns count_owned("lighter_box") — 1 per copy owned.
    # Called by RoundManager.start_match() to inflate win_threshold.

func apply_eager(dice: Array) -> void
    # If eager is owned and dice is non-empty: picks one random die, sets value=die.faces, rolled=true.
    # Called by RoundManager.start_round() on round 1 only, passing the drawn hand Array.

func get_bonus_seals(tab_board: TabBoard, primary_seals: Array) -> Array
    # If bonus_seal is owned: for each tab N in primary_seals where N >= 2,
    #   computes bonus_tab = N / 2 (integer division), adds to result if open in tab_board.
    # Returns empty Array if bonus_seal not owned.
    # Does NOT cascade — caller must not feed results back into this method.

func apply_tab9_bounty(all_sealed_tabs: Array) -> void
    # If tab_9_bounty owned AND 9 is in all_sealed_tabs: GameState.hp += count_owned("tab_9_bounty").

func apply_box_shutter() -> void
    # GameState.pending_threshold_bonus += count_owned("box_shutter") * 2.
    # Called by RunManager.handle_match_won(true). The bonus is consumed in the next start_match().

func apply_coffee_break() -> void
    # Picks a random ability in GameState.ability_hand whose charges < max_charges.
    # Adds count_owned("coffee_break") charges to it, capped at max_charges.
    # Does nothing if all abilities are null or already at max charges.
    # Called by RoundManager.start_round() on round 1 only, AFTER apply_eager().

func apply_survivor() -> void
    # If survivor is owned AND GameState.hp == 1: GameState.hp += count_owned("survivor").
    # Called by RunManager.handle_match_won() on every win (threshold or critical).

func try_phoenix_down() -> bool
    # If phoenix_down is owned: removes one copy from GameState.owned_powers,
    #   sets GameState.hp = 1, returns true.
    # Returns false if no phoenix_down owned (run ends normally).
    # Called by RunManager.handle_match_lost() before emitting run_over.
```

## Hook Map
| Method | Called by | When |
|--------|-----------|------|
| get_threshold_bonus() | RoundManager.start_match() | Every match start |
| apply_eager() | RoundManager.start_round() | Round 1 of every match |
| apply_coffee_break() | RoundManager.start_round() | Round 1 of every match, after apply_eager() |
| get_bonus_seals() | RoundManager.attempt_seal() | After each successful primary seal |
| apply_tab9_bounty() | RoundManager.attempt_seal() | After primary + bonus seals resolved |
| apply_box_shutter() | RunManager.handle_match_won(true) | Critical wins only |
| apply_survivor() | RunManager.handle_match_won() | Every win (before power/rotation offer) |
| try_phoenix_down() | RunManager.handle_match_lost() | On loss, before run_over emits |

## Gotchas
- **No class_name** — starts with `extends Node` only. Adding `class_name PowerManager` causes a "Class hides an autoload singleton" parse error.
- **Stateless.** PowerManager holds no fields. All effect state lives in GameState (owned_powers, hp, pending_threshold_bonus).
- **`get_bonus_seals` receives a post-seal TabBoard.** primary seals have already been applied to tab_board before this is called, so get_remaining() reflects the state after primary seals but before bonus seals. This is intentional — it prevents bonus-sealing a tab that was just primary-sealed.
- **Callers guard with `Engine.has_singleton("PowerManager")`.** If PowerManager is not registered, all power effects are silently skipped. Existing tests without PowerManager registered continue to pass.
- **In headless tests**, register PowerManager manually (no _ready() needed):
  ```gdscript
  var pm = load("res://scripts/run/power_manager.gd").new()
  pm.name = "PowerManager"
  get_root().add_child(pm)
  Engine.register_singleton("PowerManager", pm)
  ```

## Dependencies
- `GameState` — reads owned_powers; writes hp, pending_threshold_bonus
- `TabBoard` — passed to get_bonus_seals() to check remaining tabs

## Recent Changes
| Date | Change |
|------|--------|
| 2026-05-05 | Tuned Lighter Box: get_threshold_bonus() now returns count (was count×3). Tuned Box Shutter: apply_box_shutter() now adds count×2 (was count×5). Added apply_coffee_break() — round-1 hook, charges a random below-max ability, capped at max_charges. Added apply_survivor() — match-win hook, heals at exactly 1 HP. Added try_phoenix_down() — match-loss intercept, consumes itself, sets HP=1. |
| 2026-05-04 | Created. |
