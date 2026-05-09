# Box Library
*Autoload singleton — parses boxes.csv and exposes BoxDefinition resources.*

## Location
`scripts/globals/box_library.gd` (Autoload: `BoxLibrary`)
`data/boxes.csv` (source data)

## Responsibility
Parse boxes.csv once at _ready(). Index by id. Maintain insertion order.
Does NOT decide which boxes a run uses — that's CaseManager (uses `get_by_tier()`).

## Public API
```gdscript
func get_box(id: String) -> BoxDefinition          # returns null if not found
func get_all() -> Array                            # unordered — includes Source boxes; use get_by_tier() for regular pools
func get_ordered() -> Array                        # CSV row order (used rarely — CaseManager drives selection)
func get_by_tier(tier: String) -> Array            # filters boxes by tier field — no exclusions; "boss" tier returns the 3 Source boxes
func get_random_source() -> BoxDefinition          # returns a random boss-tier box; push_error if boss pool is empty
func get_source(entity_id: String) -> BoxDefinition # legacy — returns Source box matching entity_id's source_for field; null if empty/missing
```

## CSV Format
```
id,name,tabs,win_threshold,tier,source_for
```
20 boxes total (7 easy / 5 medium / 5 hard / 3 boss). All columns required except tier (col 5) and source_for (col 6) which default to `""` if absent. `win_threshold` is parsed as int.

**Current pool (2026-05-08):**
- easy (7): classic, low_evens, stairs, easy_starter, crowded_low, compressed, source_cosmic (the Veil)
- medium (5): lopsided_giant, cluster_of_twos, triple_triplets, mirror_ladder, avalanche
- hard (5): high_odds, high_wall, exact_evens, prime_pyramid, the_long_count
- boss (3): source_devil (the Pact, mid-boss), source_ghost (the Anchor, mid-boss), den_of_sevens (final boss, source_for="final")

**source_for values in use:**
- `""` — regular box; appears only in its tier draw
- `"diabolic"` / `"cosmic"` / `"ethereal"` — legacy entity-type markers; no longer used by any active code path
- `"final"` — marks the box as the fixed match-27 final boss; CaseManager routes it to slot 27 always

## Dependencies
- `BoxDefinition` — instantiated per CSV row

## Gotchas
- **No `class_name`** — adding `class_name BoxLibrary` causes a Godot parse error ("hides an autoload singleton"). Follow the same pattern as AbilityLibrary (no class_name declaration).
- Access via `Engine.get_singleton("BoxLibrary")` in scripts and tests. Bare global name works only in scene context.
- Tests must manually instantiate and register: `Engine.register_singleton("BoxLibrary", box_lib)` before any code that calls `Engine.get_singleton("BoxLibrary")`.
- **`get_by_tier()` does not filter on source_for.** All boxes with matching `tier` are returned, including those with non-empty `source_for`. CaseManager is responsible for further partitioning (e.g., separating source_for=="final" from the boss pool).
- **`get_by_tier("boss")` returns all 3 boss-tier boxes.** CaseManager partitions these into final_boss (source_for=="final") and mid_boss.
- **`get_random_source()` is a convenience wrapper** — calls `get_by_tier("boss")` and picks randomly. Not used by CaseManager (which needs deterministic assignment). Available for ad-hoc use.
- **`get_source(entity_id)` is legacy** — from the entity-types slice; entity types were cut. Not called by any active code path.

## Recent Changes
| Date | Change |
|------|--------|
| 2026-05-08 | Slice 1 playtest: pool expanded to 20 boxes (was 8). Five Nines and Ten Pillars dropped (unplayable). Two new source_for values in use: "final" (Den of Sevens — fixed match-27 boss). Thresholds retuned across multiple playtest rounds. source_cosmic (the Veil) moved to easy tier. Pool now 7 easy / 5 medium / 5 hard / 3 boss. |
| 2026-05-08 | Playtest refactor: Source box tier changed from "hard" to "boss" in boxes.csv. `get_by_tier()` simplified — no longer filters by source_for (boss tier is self-excluding). Added `get_random_source()`. All thresholds cut 50% (Classic 20→15, Low Evens 17→13, High Odds 17→13, Stairs 15→12, Compressed 13→10, boss boxes 18/20/22→14/15/17). |
| 2026-05-07 | feature/source-boxes: Added source_for column, get_source(entity_id), get_by_tier() source exclusion, three Source box rows. |
| 2026-05-07 | Added `tier` column (index 4) parsing (optional — skipped if row.size() < 5). Added `get_by_tier(tier)` — filters all boxes whose `tier` field matches. Used by CaseManager to build per-act pools. |
| 2026-05-04 | Added `win_threshold` column (index 3) parsing. Row size check updated from `< 3` to `< 4`. |
| 2026-05-02 | Created. |
