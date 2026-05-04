# Power Data
*Resource subclass representing a single power definition loaded from CSV.*

## Location
`resources/power_data.gd` (class_name PowerData, extends Resource)

## Responsibility
Typed container for one power's static data: id, display name, type tag, description. Instances are created by PowerLibrary at startup and stored in its dictionary. They are shared references — the same object may appear multiple times in `GameState.owned_powers` if the player earns the same power more than once.

## Fields
```gdscript
@export var id: String = ""           # CSV key, e.g. "lighter_box"
@export var name: String = ""         # Display name, e.g. "Lighter Box"
@export var type: String = ""         # Category tag: "Passive", "Match-Start", "On-Seal", "Critical-Win"
@export var description: String = ""  # Player-facing tooltip text
```

## Current Powers (data/powers.csv)
| id | name | type | effect |
|----|------|------|--------|
| lighter_box | Lighter Box | Passive | +3 to win_threshold per copy each match |
| eager | Eager | Match-Start | Pre-rolls one random hand die at max face, round 1 only |
| tab_9_bounty | Tab 9 Bounty | On-Seal | +1 HP per copy when tab 9 is sealed |
| bonus_seal | Bonus Seal | On-Seal | Sealing N also seals floor(N/2) if open; no cascade |
| box_shutter | Box Shutter | Critical-Win | Adds +5 per copy to next match's win_threshold |

## Gotchas
- **No class_name conflict.** power_data.gd has `class_name PowerData`. This does NOT conflict with the autoload name because PowerData is not registered as an autoload.
- **Shared references.** `GameState.owned_powers` stores PowerData object references directly (not duplicates). Owning 2 copies of Lighter Box means the same PowerData object appears twice in the array.
- **PowerLibrary uses `preload`** to resolve the PowerData class in headless mode where the global class cache may not have registered it yet.

## Dependencies
- None (pure data container)
- Read by: PowerLibrary (creates instances), PowerManager (reads id for count_owned)

## Recent Changes
| Date | Change |
|------|--------|
| 2026-05-04 | Created. |
