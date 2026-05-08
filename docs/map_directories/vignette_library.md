# Vignette Library
*Autoload singleton — parses vignettes.csv into VignetteData objects grouped by pool_id.*

## Location
`scripts/globals/vignette_library.gd` (Autoload: `VignetteLibrary`)

## Responsibility
Load and index all vignette definitions from `data/vignettes.csv` at startup. Expose pool-based access so TextureRoller can randomly draw from a named pool.

## Public API
```gdscript
func get_vignette(id: String) -> VignetteData
    # Returns the VignetteData with the given id, or null if not found.

func get_all() -> Array
    # Returns all VignetteData objects (unordered).

func get_pool(pool_id: String) -> Array
    # Returns all VignetteData objects whose pool_id field matches pool_id.
    # Returns [] if pool_id is unknown.
    # Used by TextureRoller.roll() to pick a random vignette from the "default" pool.
```

## Data File
`data/vignettes.csv` — columns: `id, pool_id, text`

Current entries (pool_id="default"):
| id | text |
|----|------|
| v_fog | the fog thickens — you cannot see ten paces ahead |
| v_bell | a bell tolls in the distance, slow and wrong |
| v_cold | the air goes cold for no reason you can name |

## CSV Parsing Pattern
Matches AbilityLibrary / BoxLibrary pattern exactly:
- Opens file with `FileAccess`; skips header row via `get_csv_line()`
- Skips rows with `size() < 3` or empty first column
- Creates `VignetteDataScript.new()` (preloaded script, not class_name) to avoid class-not-found in headless tests before import

## Internal State
```gdscript
var _vignettes: Dictionary   # id -> VignetteData
var _pools: Dictionary       # pool_id -> Array[VignetteData]
```
Both populated once in `_ready()` / `_load_csv()`. Never mutated afterward.

## Singleton Registration
Must be registered explicitly in `match.gd._ready()`:
```gdscript
if not Engine.has_singleton("VignetteLibrary"):
    Engine.register_singleton("VignetteLibrary", VignetteLibrary)
```
Also registered manually in headless tests before use.

## Dependencies
- None (reads CSV directly via FileAccess; no other singleton calls)

## Gotchas
- **No `class_name`** — same pattern as BoxLibrary / PowerLibrary (adding class_name would conflict with the autoload name).
- **`VignetteDataScript` preload** — the script preloads `res://resources/vignette_data.gd` and calls `.new()` on it, so `class_name VignetteData` does not need to be globally registered at parse time. This is what makes headless tests work before `--import` has run.
- **Pool returns empty array (not null)** when pool_id is unknown — always safe to call `.size()` or iterate on the result.

## Recent Changes
| Date | Change |
|------|--------|
| 2026-05-07 | Created (feature/within-act-texture). Parses data/vignettes.csv; 3 entries in "default" pool. |
