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
```

## Computed Getters (no backing storage)
```gdscript
var win_threshold: int   # floori(tab_sum() * 0.30) — remaining sum must be ≤ this to win
var round_limit: int     # ceili(tab_sum() / 15.0)  — rounds before overtime penalty
```

## Methods
```gdscript
func tab_sum() -> int    # sum of all tabs in this box (used by both getters)
```

## Example Values
| Box | tabs | tab_sum | win_threshold | round_limit |
|-----|------|---------|---------------|-------------|
| classic | 1–9 | 45 | 13 | 3 |
| low_evens | 2–8 | 35 | 10 | 3 |
| high_odds | 3,5,7,9,11 | 35 | 10 | 3 |

## Data Source
`data/boxes.csv` — parsed by BoxLibrary at startup. Tabs stored as semicolon-separated ints in the CSV.

## Dependencies
None — pure data object.

## Gotchas
- `win_threshold` means **remaining** sum must be ≤ threshold, not sealed sum ≥ threshold. The values are not interchangeable.
- Tabs can exceed 9 (high_odds has tab 11). UI must rebuild tab buttons dynamically per match, not assume 1–9.
- Assigning a plain `Array` literal to `tabs: Array[int]` raises a SCRIPT ERROR in headless tests. Use `box.tabs.assign([...])` instead.

## Recent Changes
| Date | Change |
|------|--------|
| 2026-05-02 | Created. |
