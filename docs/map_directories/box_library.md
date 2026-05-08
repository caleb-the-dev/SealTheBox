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
classic,Classic,1;2;3;4;5;6;7;8;9,15,easy,
low_evens,Low Evens,2;3;4;5;6;7;8,13,easy,
high_odds,High Odds,3;5;7;9;11,13,medium,
compressed,Compressed,2;4;5;6;8,10,hard,
stairs,Stairs,1;3;5;6;7;9,12,medium,
source_devil,the Pact,1;2;3;4;5;6;7;8;9,14,boss,diabolic
source_cosmic,the Veil,2;3;4;5;6;7;8;9;10,15,boss,cosmic
source_ghost,the Anchor,1;3;5;6;7;8;9;11;13,17,boss,ethereal
```
Thresholds reflect 2026-05-08 playtest tuning (50% cut from previous values). Boss boxes use tier="boss" rather than tier="hard" so they never appear in the regular hard-tier draw.
First four columns are required (`row.size() < 4` rows are skipped). Column 5 (`tier`) optional; column 6 (`source_for`) optional — if absent, defaults to `""`. `win_threshold` is parsed as int and stored directly on BoxDefinition.

## Dependencies
- `BoxDefinition` — instantiated per CSV row

## Gotchas
- **No `class_name`** — adding `class_name BoxLibrary` causes a Godot parse error ("hides an autoload singleton"). Follow the same pattern as AbilityLibrary (no class_name declaration).
- Access via `Engine.get_singleton("BoxLibrary")` in scripts and tests. Bare global name works only in scene context.
- Tests must manually instantiate and register: `Engine.register_singleton("BoxLibrary", box_lib)` before any code that calls `Engine.get_singleton("BoxLibrary")`.
- **`get_by_tier("hard")` returns only Compressed** (the one regular hard box). Source boxes are tier="boss", not "hard", so they never pollute the hard pool.
- **`get_by_tier("boss")` returns the 3 Source boxes.** CaseManager calls this and shuffles the result to assign boss matches 9, 21, 27 without repeats.
- **`get_random_source()` is a convenience wrapper** — calls `get_by_tier("boss")` and picks randomly. Not used by CaseManager (which needs deterministic assignment per run), but available for ad-hoc use.
- **`get_source(entity_id)` is legacy** — still in code from the entity-types slice, but entity types were cut for prototyping. Not called by any active code path.

## Recent Changes
| Date | Change |
|------|--------|
| 2026-05-08 | Playtest refactor: Source box tier changed from "hard" to "boss" in boxes.csv. `get_by_tier()` simplified — no longer filters by source_for (boss tier is self-excluding). Added `get_random_source()`. All thresholds cut 50% (Classic 20→15, Low Evens 17→13, High Odds 17→13, Stairs 15→12, Compressed 13→10, boss boxes 18/20/22→14/15/17). |
| 2026-05-07 | feature/source-boxes: Added source_for column, get_source(entity_id), get_by_tier() source exclusion, three Source box rows. |
| 2026-05-07 | Added `tier` column (index 4) parsing (optional — skipped if row.size() < 5). Added `get_by_tier(tier)` — filters all boxes whose `tier` field matches. Used by CaseManager to build per-act pools. |
| 2026-05-04 | Added `win_threshold` column (index 3) parsing. Row size check updated from `< 3` to `< 4`. |
| 2026-05-02 | Created. |
