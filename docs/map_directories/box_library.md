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
func get_by_tier(tier: String) -> Array            # filters boxes by tier, EXCLUDING Source boxes (source_for != "")
func get_source(entity_id: String) -> BoxDefinition # returns the Source box for a given entity_id; null if id empty or no match found; push_error on missing
```

## CSV Format
```
id,name,tabs,win_threshold,tier,source_for
classic,Classic,1;2;3;4;5;6;7;8;9,20,easy,
low_evens,Low Evens,2;3;4;5;6;7;8,17,easy,
high_odds,High Odds,3;5;7;9;11,17,medium,
compressed,Compressed,2;4;5;6;8,13,hard,
stairs,Stairs,1;3;5;6;7;9,15,medium,
source_devil,the Pact,1;2;3;4;5;6;7;8;9,18,hard,diabolic
source_cosmic,the Veil,2;3;4;5;6;7;8;9;10,20,hard,cosmic
source_ghost,the Anchor,1;3;5;6;7;8;9;11;13,22,hard,ethereal
```
First four columns are required (`row.size() < 4` rows are skipped). Column 5 (`tier`) optional; column 6 (`source_for`) optional — if absent, defaults to `""`. `win_threshold` is parsed as int and stored directly on BoxDefinition.

## Dependencies
- `BoxDefinition` — instantiated per CSV row

## Gotchas
- **No `class_name`** — adding `class_name BoxLibrary` causes a Godot parse error ("hides an autoload singleton"). Follow the same pattern as AbilityLibrary (no class_name declaration).
- Access via `Engine.get_singleton("BoxLibrary")` in scripts and tests. Bare global name works only in scene context.
- Tests must manually instantiate and register: `Engine.register_singleton("BoxLibrary", box_lib)` before any code that calls `Engine.get_singleton("BoxLibrary")`.
- **`get_by_tier()` excludes Source boxes.** This is intentional — Source boxes have `tier="hard"` but must never appear in the regular act-3 pool. Callers that need Source boxes must call `get_source(entity_id)` directly.
- **`get_source()` returns null for empty entity_id** — safe call pattern. Pass `GameState.entity_id`; if it's `""` (pre-reset_run), the method returns null without erroring.
- **`get_source()` logs a push_error and returns null** if a non-empty entity_id has no matching Source box. This indicates a data error in boxes.csv (missing Source row for an entity).

## Recent Changes
| Date | Change |
|------|--------|
| 2026-05-07 | feature/source-boxes: Added `source_for` column (index 5) parsing. Added `get_source(entity_id)` — returns the Source box for a given entity. Updated `get_by_tier()` to exclude Source boxes (`.source_for.is_empty()` filter added). Three new Source box rows in boxes.csv. |
| 2026-05-07 | Added `tier` column (index 4) parsing (optional — skipped if row.size() < 5). Added `get_by_tier(tier)` — filters all boxes whose `tier` field matches. Used by CaseManager to build per-act pools. |
| 2026-05-04 | Added `win_threshold` column (index 3) parsing. Row size check updated from `< 3` to `< 4`. |
| 2026-05-02 | Created. |
