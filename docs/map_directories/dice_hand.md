# Dice Hand (UI)
*Renders the 3 drawn dice for the current round; handles roll selection.*

## Location
`scripts/ui/dice_hand.gd` / `scenes/match/match.tscn` (CanvasLayer child)

## Responsibility
Show the 3 drawn dice. Let player select which to roll (highlighted). Show rolled values after commit.
Shows face size (e.g. "d6") before rolling, numeric value after.
Designed for replacement: when 3D physics dice arrive, this node shows their results instead of driving them.

## Public API
```gdscript
func show_hand(dice: Array[Die]) -> void
func get_selected() -> Array[Die]
func lock_rolled() -> void     # prevent re-selection after roll committed
func clear() -> void
```

## Dependencies
- `RoundManager` — calls commit_roll() with selected dice
- `DicePool` — reads Die objects

## Known Issues / TODOs
- [ ] Implement (not yet built)
- [ ] Future: replace with 3D dice result reader

## Last Updated
2026-05-01
