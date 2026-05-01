# Ability Hand (UI)
*Renders ability cards in hand; handles card selection and target selection.*

## Location
`scripts/ui/ability_hand.gd` / `scenes/match/match.tscn` (CanvasLayer child)

## Responsibility
Render ability cards. Dim cards when AP insufficient. Handle click → target die → call RoundManager.use_ability().
Does NOT resolve ability effects — that's RoundManager.

## Public API
```gdscript
func refresh_hand(abilities: Array[AbilityData]) -> void
func set_ap(ap: int) -> void   # dims unaffordable cards
```

## Dependencies
- `RoundManager` — calls use_ability()
- `GameState` — reads ability_hand, ap

## Known Issues / TODOs
- [ ] Implement (not yet built)
- [ ] Targeting flow (click card → click die) needs UX thought

## Last Updated
2026-05-01
