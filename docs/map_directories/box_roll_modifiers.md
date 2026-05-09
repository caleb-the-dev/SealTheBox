# Box Roll Modifiers
*Static registry of per-box dice modifiers applied after every roll commit.*

## Location
`scripts/match/box_roll_modifiers.gd` (class_name BoxRollModifiers, extends RefCounted — static class, never instantiated)

## Responsibility
Map box_ids to modifier Callables. Two modifier types exist:
- **Mutation-type** — mutates `die.value` in-place (heavy_dice, weak_dice, exploding_ones). Returns -1 so caller sums naturally.
- **Total-override type** — does NOT mutate dice; returns a computed total override (halving_box, doubling_box, high_die_doubles). Safe to call multiple times.

Also applies display tags to dice after roll resolution (e.g. `×2` on the highest die for high_die_doubles, `1→N` on exploded dice).

## Public API
```gdscript
static func has_modifier(box_id: String) -> bool
    # Returns true if a modifier is registered for this box_id.

static func is_total_override(box_id: String) -> bool
    # Returns true if the modifier for this box computes a total rather than mutating dice.

static func apply_dice_mutation(box_id: String, dice: Array) -> void
    # Applies the mutation modifier for box_id to the dice array.
    # No-op for total-override boxes (they are pure, applied via compute_total).
    # No-op for unknown box_ids. Call once per roll at commit time.

static func compute_total(box_id: String, dice: Array) -> int
    # For total-override boxes: returns the modifier's computed total.
    # For mutation-type or unknown boxes: returns -1 (caller should sum normally).
    # Safe to call multiple times — does NOT mutate dice.

static func apply_display_tags(box_id: String, dice: Array) -> void
    # Sets die.modifier_tag on the relevant die for display purposes.
    # For high_die_doubles: tags the highest active die with "×2".
    # For exploding_ones: tag is set during mutation (_mod_exploding_ones sets "1→N").
    # Call once per roll after apply_dice_mutation.

static func get_description(box_id: String) -> String
    # Returns a one-line human-readable description of the modifier, or "" if none.
    # Used by match.gd to populate the [!] hover tooltip.
```

## Modifier Registry (6 active modifiers)
| box_id | Type | Rule |
|--------|------|------|
| heavy_dice | mutation | +1 to every die each roll |
| weak_dice | mutation | −1 to every die each roll (min 1) |
| exploding_ones | mutation | Any die showing 1 rerolls and adds; chains on consecutive 1s; cap: 10 deep |
| halving_box | total-override | floor(sum / 2) |
| doubling_box | total-override | sum × 2 |
| high_die_doubles | total-override | highest die counts ×2 toward total (ties: first max wins) |

## Die.modifier_tag Convention
`die.modifier_tag: String` is set by modifiers for display in the die button's bottom-left corner.
- `"1→N"` — exploding_ones: die originally rolled 1 and exploded to N
- `"×2"` — high_die_doubles: this die is the high die counted twice
- `""` — no tag (cleared at start of every `commit_roll` call in RoundManager)

## Gotchas
- **Total-override modifiers are NOT applied during `apply_dice_mutation`.** They are pure functions called separately via `compute_total()`. `RoundManager._compute_roll_total()` handles routing. Never call `apply_dice_mutation` for a total-override box expecting it to do anything — it no-ops.
- **`apply_display_tags` must be called AFTER `apply_dice_mutation`**, not before. For exploding_ones, the tag is set inside the mutation function itself (not in apply_display_tags), so apply_display_tags is effectively a no-op for that box but safe to call.
- **`_initialized` is a static bool** — the registry is built only once per Godot session. In headless tests that import this class, the registry persists across test functions within the same run.
- **`EXPLODING_ONES_MAX_DEPTH = 10`** caps chain depth. A d4 always rolling 1 would produce `die.value = 1 + 10 = 11` at cap.
- **Doubling box total-override means dice display their natural values.** The player sees, e.g., `3 5 4` but the effective sealing total is `(3+5+4) × 2 = 24`. This is intentional — dice show truth; the box rule modifies interpretation.
- **High die doubles: tie-breaking is first-found.** If two dice share the max value, the first in the active array gets `×2`. This is deterministic given array order.
- **Dropped dice are skipped by all modifiers.** The `die.rolled and not die.dropped` guard is present in every modifier function.

## Dependencies
- `Die` — reads and writes `die.value`, `die.rolled`, `die.dropped`, `die.modifier_tag`, `die.faces`

## Depended On By
- `RoundManager` — calls `apply_dice_mutation`, `compute_total`, `apply_display_tags` from `commit_roll()` and `_compute_roll_total()`
- `match.gd` — calls `has_modifier()` and `get_description()` for the [!] badge tooltip

## Recent Changes
| Date | Change |
|------|--------|
| 2026-05-08 | Created (slice-boxes-2-roll-mods). 7 initial modifiers including pair_swallows. pair_swallows immediately dropped on playtest (mechanically invisible — dice always pair). Active registry: 6 modifiers. `apply_display_tags()` added for post-mutation visual tags. `get_description()` added for HUD tooltip. `die.modifier_tag` convention established. |
