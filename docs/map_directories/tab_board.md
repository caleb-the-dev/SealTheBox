# Tab Board
*Manages the set of unsealed tabs for the current match.*

## Location
`scripts/match/tab_board.gd`

## Responsibility
Track which tabs are sealed/unsealed. Validate seal attempts. Check win condition.
Does NOT know about dice or AP — it only knows about tab values.

## Public API
```gdscript
func seal_tab(value: int) -> void
func get_remaining() -> Array[int]
func get_sum() -> int
func check_win(threshold: int) -> bool    # sum <= threshold
func check_critical_win() -> bool         # sum == 0
func reset(tab_range: Array[int]) -> void
```

## Dependencies
- `GameState` — reads win_threshold, writes tabs[]

## Data
Tab range hardcoded [1–9] in vertical slice. Future: driven by match config.

## Known Issues / TODOs
- [ ] Implement (not yet built)

## Last Updated
2026-05-01
