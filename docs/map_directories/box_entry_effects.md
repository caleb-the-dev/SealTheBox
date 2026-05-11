# Box Entry Effects
*Static registry of ENTRY-axis box effects. Fires once per match at the start of `start_match()`.*

## Location
`scripts/match/box_entry_effects.gd` (class_name BoxEntryEffects, static class)

## Responsibility
Register and dispatch per-match entry effects for ENTRY-axis boxes. Called once per match in `RoundManager.start_match()` before the dice pool is built. Effects read/write `GameState` directly — same pattern as PowerManager hooks.

## Registered Boxes
| Box ID | Effect |
|--------|--------|
| storm_box | Adds a d2 and d10 to `GameState.match_pool_delta`; `round_limit -= 1` |
| cleanse_box | Refills all ability charges to `max_charges`; `round_limit -= 2` |
| borrowed_time | `hp -= 1`; `round_limit += 1`; only spawnable when `hp ≥ 3` (HP gate in CaseManager) |

## Public API
```gdscript
static func on_box_entry(box_id: String, gs: Node) -> void
    # Dispatches the entry effect for box_id against gs (GameState).
    # Called once per match in RoundManager.start_match(), before DicePool.setup().
    # No-op if box_id has no registered effect.
    # Must be called BEFORE BoxDiceAccess.get_active_pool() so storm_box can populate
    # match_pool_delta before DicePool.setup() reads it.

static func has_entry_effect(box_id: String) -> bool
    # Returns true if box_id has a registered entry effect.

static func get_description(box_id: String) -> String
    # Returns a human-readable rule description for the [!] badge tooltip.
    # Returns "" if box_id is not an ENTRY box.
    # Used by match.gd — lowest priority in the badge chain: ROLL → WIN → DICE → ENTRY.
```

## Effect Details

### storm_box
Iterates `STORM_DIE_FACES = [2, 10]` and appends one `Die.new(faces)` per entry to `gs.match_pool_delta`, marking each with `storm_temp = true` (informational label for UI). Also reduces `gs.round_limit -= 1` — the two bonus dice come with one fewer safe round. The delta is appended to `BoxDiceAccess.get_active_pool()` in `RoundManager.start_match()`.

### cleanse_box
Iterates `gs.ability_hand`; sets `ability.charges = ability.max_charges` for every non-null slot. Reduces `gs.round_limit -= 2` — the charge windfall is offset by hard time pressure.

### borrowed_time
Costs 1 HP (`gs.hp -= 1`) and grants 1 extra round (`gs.round_limit += 1`). HP gate (hp ≥ 3) is enforced upstream in `CaseManager.get_box_for_match()` which lazily swaps borrowed_time for another medium box when hp < 3. This function applies unconditionally — if the gate is bypassed (dev menu), it can fire at HP = 1 or 2.

## Constants
```gdscript
const STORM_DIE_FACES: Array[int] = [2, 10]
    # Fixed die faces granted by storm_box (d2 and d10).
    # Looped to create one Die per entry appended to match_pool_delta.
```

## Dependencies
- `Die` — constructs bonus Die objects; `storm_temp` field set on storm_box dice
- `GameState` — reads/writes: `ability_hand`, `match_pool_delta`, `hp`, `round_limit`

## Gotchas
- **round_limit modifications layer on top of BoxWinConditions result.** `RoundManager.start_match()` sets `round_limit` via `BoxWinConditions.get_round_limit()` first (line 40), then fires `on_box_entry()` (line 51). So storm_box's `-1` and cleanse_box's `-2` are always relative to the BoxWinConditions-adjusted value, not the raw `box.round_limit`.
- **match_pool_delta is cleared by `reset_match()` inside start_match(), BEFORE entry effects fire.** Entry effects always start from an empty delta. Stale dice from a previous storm_box match never carry forward.
- **borrowed_time HP gate is CaseManager's responsibility, not this class.** If `get_box_for_match()` logic changes, it must continue to gate borrowed_time; this file has no guard.
- **storm_temp is purely informational.** No game logic reads `storm_temp` — it is available for UI code to identify storm bonus dice if needed, but currently nothing uses it.

## Recent Changes
| Date | Change |
|------|--------|
| 2026-05-11 | Playtest tuning: storm_box changed from one random die (d4/d6/d8) to fixed d2+d10; round_limit -= 1 added. cleanse_box: round_limit -= 2 added. STORM_DIE_FACES const updated to [2, 10]. |
| 2026-05-10 | Initial implementation. on_box_entry() dispatcher, has_entry_effect(), get_description() API. 3 ENTRY boxes wired (storm_box random-die variant, cleanse_box, borrowed_time). |
