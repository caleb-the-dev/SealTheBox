# Power Data
*Resource subclass representing a single power definition loaded from CSV.*

## Location
`resources/power_data.gd` (class_name PowerData, extends Resource)

## Responsibility
Typed container for one power's static data: id, display name, type tag, description. Instances are created by PowerLibrary at startup and stored in its dictionary. They are shared references — the same object may appear multiple times in `GameState.owned_powers` if the player earns the same power more than once.

## Fields
```gdscript
@export var id: String = ""              # CSV key, e.g. "bonus_seal"
@export var name: String = ""            # Display name, e.g. "Bonus Seal"
@export var type: String = ""            # Category tag: "Passive", "Match-Start", "On-Seal", "Critical-Win", "Counter"
@export var description: String = ""     # Player-facing tooltip text
@export var counter_target: int = 0      # For Counter powers: fires when counter reaches this value; 0 = no counter
```

## Current Powers (data/powers.csv)
| id | name | type | counter_target | effect |
|----|------|------|----------------|--------|
| lighter_box | Lighter Box | Passive | 0 | +1 to win_threshold per copy each match |
| eager | Eager | Match-Start | 0 | Pre-rolls one random hand die at max face, round 1 only |
| tab_9_bounty | Tab 9 Bounty | On-Seal | 0 | +1 HP per copy when tab 9 is sealed |
| bonus_seal | Bonus Seal | Counter | 3 | Every 3 rounds, next seal also seals floor(N/2); no cascade |
| box_shutter | Box Shutter | Critical-Win | 0 | Adds +2 per copy to next match's win_threshold |
| phoenix_down | Phoenix Down | Passive | 0 | Intercepts run-over once; sets HP=1, self-consumes |
| coffee_break | Coffee Break | Match-Start | 0 | Round 1: charges one random below-max ability by +1/copy, capped at max |
| survivor | Survivor | Passive | 0 | After any win at exactly HP=1: heal +1 per copy |

## Gotchas
- **No class_name conflict.** power_data.gd has `class_name PowerData`. This does NOT conflict with the autoload name because PowerData is not registered as an autoload.
- **Shared references.** `GameState.owned_powers` stores PowerData object references directly (not duplicates). Owning 2 copies of Lighter Box means the same PowerData object appears twice in the array.
- **PowerLibrary uses `preload`** to resolve the PowerData class in headless mode where the global class cache may not have registered it yet.
- **`counter_target = 0` means no counter.** PowerManager skips counter logic for any power where counter_target <= 0. Only "Counter"-type powers currently use this field.
- **Counter state lives in GameState, not PowerData.** `power_counters[power.id]` holds the runtime value. PowerData only stores the static target.

## Dependencies
- None (pure data container)
- Read by: PowerLibrary (creates instances), PowerManager (reads id for count_owned, counter_target for counter logic)

## Recent Changes
| Date | Change |
|------|--------|
| 2026-05-05 | Added counter_target field. bonus_seal converted to Counter type with counter_target=3. All other powers get counter_target=0. Powers table expanded to all 8 powers with correct types and effects. |
| 2026-05-04 | Created. |
