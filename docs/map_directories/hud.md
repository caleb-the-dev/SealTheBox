# HUD
*Displays HP, AP, round counter, and status messages. Read-only UI.*

## Location
`scripts/ui/hud.gd` / `scenes/match/match.tscn` (CanvasLayer child)

## Responsibility
Show HP, AP, current round / round limit, and status text. Respond to GameState changes and RoundManager signals.
Does NOT process input — display only.

## Public API
```gdscript
func update_hp(value: int) -> void
func update_ap(value: int) -> void
func update_round(current: int, limit: int) -> void
func set_status(text: String) -> void
```

## Dependencies
- `RoundManager` signals — updates on phase_changed, round_ended
- `GameState` — reads hp, ap, round

## Known Issues / TODOs
- [ ] Implement (not yet built)

## Last Updated
2026-05-01
