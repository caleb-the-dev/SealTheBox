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
var source_for: String       # loaded from CSV column 6 — one of "diabolic", "cosmic", "ethereal", or "" for normal boxes
                             # Source boxes are exclusively assigned to match 27 and excluded from tier draws
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
| Box | tabs | tab_sum | win_threshold | round_limit | tier | source_for |
|-----|------|---------|---------------|-------------|------|------------|
| classic | 1–9 | 45 | 11 | 4 | easy | |
| low_evens | 2–8 | 35 | 10 | 4 | easy | |
| high_odds | 3,5,7,9,11 | 35 | 10 | 4 | medium | |
| compressed | 2,4,5,6,8 | 25 | 8 | 3 | hard | |
| stairs | 1,3,5,6,7,9 | 31 | 9 | 4 | medium | |
| source_devil | 1–9 | 45 | 11 | 4 | boss | diabolic |
| source_cosmic | 2–10 | 54 | 11 | 4 | boss | cosmic |
| source_ghost | 1,3,5,6,7,8,9,11,13 | 63 | 13 | 5 | boss | ethereal |

## Data Source
`data/boxes.csv` — parsed by BoxLibrary at startup. Columns: `id, name, tabs, win_threshold, tier, source_for`. Tabs are semicolon-separated ints. Column 5 (`tier`) is optional; column 6 (`source_for`) is optional — if absent, defaults to `""`. Source boxes are identified by a non-empty `source_for` value.

## Dependencies
None — pure data object.

## Gotchas
- `win_threshold` means **remaining** sum must be ≤ threshold, not sealed sum ≥ threshold. The values are not interchangeable.
- `win_threshold` is now a plain `var` set by BoxLibrary from CSV — **not a computed getter**. Creating a BoxDefinition in tests without setting `win_threshold` will leave it at 0.
- Tabs can exceed 9 (high_odds has tab 11; source_ghost has tabs 11 and 13). UI must rebuild tab buttons dynamically per match, not assume 1–9.
- Assigning a plain `Array` literal to `tabs: Array[int]` raises a SCRIPT ERROR in headless tests. Use `box.tabs.assign([...])` instead.
- Source boxes (`source_for != ""`) must not appear in regular tier draws. `BoxLibrary.get_by_tier()` automatically filters them out. Do not call `get_all()` and filter by tier manually — you'll include Source boxes.
- `source_for` defaults to `""` (empty string) for all regular boxes. Check with `box.source_for.is_empty()`, not `box.source_for == null`.

## Recent Changes
| Date | Change |
|------|--------|
| 2026-05-08 | All win_thresholds cut 25% (classic 15→11, low_evens 13→10, high_odds 13→10, compressed 10→8, stairs 12→9, source_devil 14→11, source_cosmic 15→11, source_ghost 17→13). Source box tiers corrected to "boss" in docs (was "hard" — docs were stale). |
| 2026-05-08 | Source box tiers set to "boss" (refactored from "hard") so BoxLibrary.get_by_tier("boss") returns them exclusively. |
| 2026-05-07 | feature/source-boxes: Added `source_for: String` field (CSV column 6). Three Source boxes added: source_devil ("the Pact", diabolic), source_cosmic ("the Veil", cosmic), source_ghost ("the Anchor", ethereal). |
| 2026-05-07 | Added `tier: String` field (CSV column 5). Assigned: classic/low_evens=easy, stairs/high_odds=medium, compressed=hard, source boxes=boss. Used by CaseManager.get_by_tier() to build per-act box pools. |
| 2026-05-04 | `win_threshold` changed from computed getter (floori(tab_sum()*0.30)) to stored var loaded from CSV. `round_limit` formula updated to ceili(tab_sum()/15.0)+1. |
| 2026-05-02 | Created. |
