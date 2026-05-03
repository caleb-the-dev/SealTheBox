# Box Library
*Autoload singleton — parses boxes.csv and exposes BoxDefinition resources.*

## Location
`scripts/globals/box_library.gd` (Autoload: `BoxLibrary`)
`data/boxes.csv` (source data)

## Responsibility
Parse boxes.csv once at _ready(). Index by id. Maintain insertion order for run sequencing.
Does NOT decide which boxes a run uses — that's RunManager.

## Public API
```gdscript
func get_box(id: String) -> BoxDefinition   # returns null if not found
func get_all() -> Array                     # unordered
func get_ordered() -> Array                 # CSV row order — used by RunManager for series sequencing
```

## CSV Format
```
id,name,tabs
classic,Classic,1;2;3;4;5;6;7;8;9
low_evens,Low Evens,2;3;4;5;6;7;8
high_odds,High Odds,3;5;7;9;11
```

## Dependencies
- `BoxDefinition` — instantiated per CSV row

## Gotchas
- **No `class_name`** — adding `class_name BoxLibrary` causes a Godot parse error ("hides an autoload singleton"). Follow the same pattern as AbilityLibrary (no class_name declaration).
- Access via `Engine.get_singleton("BoxLibrary")` in scripts and tests. Bare global name works only in scene context.
- Tests must manually instantiate and register: `Engine.register_singleton("BoxLibrary", box_lib)` before any code that calls `Engine.get_singleton("BoxLibrary")`.

## Recent Changes
| Date | Change |
|------|--------|
| 2026-05-02 | Created. |
