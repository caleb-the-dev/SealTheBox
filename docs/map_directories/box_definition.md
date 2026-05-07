# Box Definition
*Resource subclass representing a single box (tab set) configuration.*

## Location
`resources/box_definition.gd` (class_name BoxDefinition, extends Resource)

## Responsibility
Hold the static data for one box: its tab values and derived difficulty parameters.
Does NOT own runtime state — tab sealing happens in TabBoard / GameState.

## Fields
```gdscript
@export var id: String       # matches CSV id column
@export var name: String     # display name (e.g. "Classic")
@export var tabs: Array[int] # tab values (e.g. [1,2,3,4,5,6,7,8,9])
var win_threshold: int       # loaded from CSV column 4 — remaining sum must be ≤ this to win
var tier: String             # loaded from CSV column 5 — "easy", "medium", or "hard"; used by CaseManager to assign boxes to acts
```

## Computed Getter
```gdscript
var round_limit: int     # ceili(tab_sum() / 15.0) + 1 — rounds before overtime penalty
```

## Methods
```gdscript
func tab_sum() -> int    # sum of all tabs in this box
```

## Example Values
| Box | tabs | tab_sum | win_threshold | round_limit | tier |
|-----|------|---------|---------------|-------------|------|
| classic | 1–9 | 45 | 20 | 4 | easy |
| low_evens | 2–8 | 35 | 17 | 4 | easy |
| high_odds | 3,5,7,9,11 | 35 | 17 | 4 | medium |
| compressed | 2,4,5,6,8 | 25 | 13 | 3 | hard |
| stairs | 1,3,5,6,7,9 | 31 | 15 | 4 | medium |

## Data Source
`data/boxes.csv` — parsed by BoxLibrary at startup. Columns: `id, name, tabs, win_threshold, tier`. Tabs are semicolon-separated ints. Column 5 (`tier`) is optional for backward compatibility — older rows without it leave `tier` as `""`.

## Dependencies
None — pure data object.

## Gotchas
- `win_threshold` means **remaining** sum must be ≤ threshold, not sealed sum ≥ threshold. The values are not interchangeable.
- `win_threshold` is now a plain `var` set by BoxLibrary from CSV — **not a computed getter**. Creating a BoxDefinition in tests without setting `win_threshold` will leave it at 0.
- Tabs can exceed 9 (high_odds has tab 11). UI must rebuild tab buttons dynamically per match, not assume 1–9.
- Assigning a plain `Array` literal to `tabs: Array[int]` raises a SCRIPT ERROR in headless tests. Use `box.tabs.assign([...])` instead.

## Recent Changes
| Date | Change |
|------|--------|
| 2026-05-07 | Added `tier: String` field (CSV column 5). Assigned: classic/low_evens=easy, stairs/high_odds=medium, compressed=hard. Used by CaseManager.get_by_tier() to build per-act box pools. |
| 2026-05-04 | `win_threshold` changed from computed getter (floori(tab_sum()*0.30)) to stored var loaded from CSV. Values bumped to 20/17/17. `round_limit` formula updated to ceili(tab_sum()/15.0)+1 — all current boxes now have 4 rounds. |
| 2026-05-02 | Created. |
