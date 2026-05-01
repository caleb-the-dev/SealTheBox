# Round Manager
*Orchestrates match phases and round transitions. The heart of the match loop.*

## Location
`scripts/match/round_manager.gd`

## Responsibility
Own phase transitions (Roll → Act → End Round). Emit signals for UI to react to.
Check win/lose after each seal and at end of round.
Does NOT render anything — all rendering is UI nodes responding to signals.

## Public API
```gdscript
signal phase_changed(phase: String)   # "roll", "act", "end"
signal round_ended(round: int)
signal match_won(critical: bool)
signal match_lost()
signal tab_sealed(value: int)

func start_match() -> void
func start_round() -> void
func commit_roll(dice: Array[Die]) -> void
func attempt_seal(dice: Array[Die], tab: int) -> bool
func use_ability(ability: AbilityData, target_die: Die) -> bool
func end_round() -> void
```

## Dependencies
- `GameState` — reads/writes hp, ap, round, dice_hand, ability_hand
- `TabBoard` — calls seal_tab, check_win
- `DicePool` — calls draw_hand, roll_die, discard_hand
- `AbilityLibrary` — resolves ability effects

## Known Issues / TODOs
- [ ] Implement (not yet built)

## Last Updated
2026-05-01
