# Box Dice Access
*Static registry of DICE-axis box modifiers: pool overrides, round-end hooks, and entry powers.*

## Location
`scripts/match/box_dice_access.gd` (class_name BoxDiceAccess, extends RefCounted — static class, never instantiated)

## Responsibility
Map box_ids to Callable pool-override functions that return a modified die array for a single match,
and expose hook queries (has_tax, has_forced_commit, has_entry_power) for RoundManager to apply
round-end or entry effects. Also owns human-readable descriptions for the [!] badge tooltip.

## Callable Contract (pool overrides)
```
func override_name(pool: Array) -> Array
  - pool: the persistent dice pool (Array of Die objects)
  - Returns a NEW array of Die objects for this match only.
  - The persistent pool is NEVER modified.
```

## Public API
```gdscript
static func has_override(box_id: String) -> bool
    # Returns true if a pool-override callable is registered for this box_id.

static func get_active_pool(box_id: String, persistent_pool: Array) -> Array
    # Returns the active pool for the match. If a pool override is registered, calls it and
    # returns the new array. Otherwise returns a shallow duplicate of persistent_pool.
    # Persistent pool is always untouched.

static func has_description(box_id: String) -> bool
    # Returns true if a one-line [!] tooltip description exists for this box_id.

static func get_description(box_id: String) -> String
    # Returns the one-line description for the [!] hover tooltip, or "" if none.

static func has_tax(box_id: String) -> bool
    # Returns true if this box imposes -1 HP per round after Round 1.
    # Currently: returns true only for "tax_per_roll" (no active box; infrastructure only).

static func has_forced_commit(box_id: String) -> bool
    # Returns true if this box requires all rolled pips to be committed.
    # Currently: returns true only for "forced_full_commit" (no active box; infrastructure only).

static func has_entry_power(box_id: String) -> bool
    # Returns true if this box grants a fixed power on first entry per run.
    # Currently: returns true only for "bounty_box" (no active box; infrastructure only).
```

## Active Pool Overrides (3 boxes)
| box_id | Behavior |
|--------|----------|
| single_die | Returns exactly 1 randomly-chosen die from the persistent pool |
| locked_d8 | Returns pool with all d8s removed |
| locked_d4 | Returns pool with all d4s removed |

## Inactive Hook Infrastructure (no matching boxes in CSV as of 2026-05-09)
| Hook | box_id it checks | Effect if matched |
|------|-----------------|-------------------|
| has_tax | "tax_per_roll" | -1 HP per round after Round 1 |
| has_forced_commit | "forced_full_commit" | Damage = leftover rolled pips at round end |
| has_entry_power | "bounty_box" | Grant phoenix_down once per run |

These hooks remain in the code for when the corresponding boxes return. No active box currently triggers them — has_tax("quick_seal") returns false, etc.

## Key Constants
```gdscript
const BOUNTY_BOX_POWER_ID := "phoenix_down"
    # The power granted by bounty_box on first entry. Used by RoundManager._grant_bounty_box_power().
```

## Key Internal State
```gdscript
static var _registry: Dictionary          # box_id → Callable (pool overrides only)
static var _initialized: bool             # guards _ensure_init()
static var _descriptions: Dictionary      # box_id → human-readable tooltip string (3 entries)
```

`_initialized` is a static bool — registry built once per Godot session, like BoxRollModifiers.

## Dependencies
- None (static class; Die objects are passed in by RoundManager; no direct imports)

## Depended On By
- `RoundManager` — calls `get_active_pool()` in `start_match()`; calls `has_entry_power()` and
  `has_tax()` and `has_forced_commit()` in `end_round()`/`start_match()`
- `match.gd` — calls `has_description()` and `get_description()` for the [!] badge tooltip (lowest priority after ROLL → WIN)

## Gotchas
- **Pool override returns a new array — never mutates the persistent pool.** The pool passed in is the `GameState.dice_pool`. Returning a filtered copy ensures the next match starts fresh. Never return the input array or a slice of it directly.
- **single_die picks from the SAME die object references** as the persistent pool. Die objects are shared; calling `randi() % pool.size()` and returning `[pool[idx]]` means the active pool contains the actual persistent die — it is not duplicated. This is fine because mutations during the match (roll, reroll) modify the die in place, and `DicePool.discard_hand()` resets it afterward.
- **has_tax / has_forced_commit / has_entry_power are string comparisons to dropped box ids.** As of 2026-05-09, no active box matches these. The infrastructure is intentionally left intact so the mechanics can be reactivated by adding the box back to boxes.csv. Do not remove the functions without removing the callers in RoundManager as well.
- **Descriptions dict controls [!] badge visibility** for DICE boxes. If a box has no entry in _descriptions, it gets no badge. The three active DICE boxes (single_die, locked_d8, locked_d4) all have descriptions. Dropped boxes (bounty_box, tax_per_roll, forced_full_commit) were removed from the dict.
- **_registry only contains pool-override boxes** (single_die, locked_d8, locked_d4). has_tax / has_forced_commit / has_entry_power are NOT in the registry — they are separate hardcoded string checks. Don't confuse the two systems.

## Recent Changes
| Date | Change |
|------|--------|
| 2026-05-09 | Playtest feedback: bounty_box, forced_full_commit, tax_per_roll removed from _descriptions (their boxes were dropped from boxes.csv or stripped of mechanics). Active descriptions now only 3 (single_die, locked_d8, locked_d4). Pool override registry unchanged (still 3 entries). |
| 2026-05-09 | Created (slice-boxes-4-dice-access). Pool overrides for single_die, locked_d8, locked_d4. Round-end hooks: has_tax() (-1 HP after R1), has_forced_commit() (leftover pip damage). Entry power: has_entry_power() / BOUNTY_BOX_POWER_ID ("phoenix_down"). Descriptions for all 6 DICE boxes. test_dice_access.gd: 20 tests covering pool overrides, immutability, round-end hooks, entry power, and CaseManager marquee dedup. |
