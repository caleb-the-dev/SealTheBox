# Case Manager
*Autoload singleton — owns the 27-match Case sequence and emits run_won when match 27 is sealed.*

## Location
`scripts/run/case_manager.gd` (Autoload: `CaseManager`)

## Responsibility
Build and own the ordered 27-match sequence for the current run. Acts as the data authority for "what box plays next" and "what act are we in." Emits `run_won` when RunManager signals that match 27 is done.

Does NOT drive phase transitions or UI — that's RunManager and match.gd.

## Signals
```gdscript
signal run_won    # emitted by notify_run_won() — no arguments; match.gd listens to show the run_won_overlay
```

## Public API
```gdscript
func reset_run() -> void
    # Builds (or rebuilds) the 27-match list from BoxLibrary tier pools:
    #   Matches  1–9  → 9 random draws (with replacement) from easy-tier boxes
    #   Matches 10–21 → 12 random draws from medium-tier boxes
    #   Matches 22–27 → 6 random draws from hard-tier boxes
    # Called by RunManager.start_run() after GameState.reset_run().

func get_box_for_match(idx: int) -> BoxDefinition
    # Returns _case_list[idx - 1]. idx is 1-based (1..27).
    # push_error and returns null if idx is out of range.

func get_act_for_match(idx: int) -> int
    # Returns 1 (idx ≤ 9), 2 (idx ≤ 21), or 3 (idx > 21). Does not require reset_run() first.

func notify_run_won() -> void
    # Emits run_won. Called by RunManager._start_next_match() when gs.run_won == true.
```

## Constants
```gdscript
const ACT1_SIZE := 9    # matches 1–9
const ACT2_SIZE := 12   # matches 10–21
const ACT3_SIZE := 6    # matches 22–27
```

## Internal State
```gdscript
var _case_list: Array   # Array of BoxDefinition, length 27; built by reset_run(); index 0 = match 1
```

## Dependencies
- `BoxLibrary` — calls `get_by_tier("easy"/"medium"/"hard")` in reset_run()

## How RunManager Uses CaseManager
```
RunManager.start_run()
  → GameState.reset_run()     (resets case_match_index=1, run_won=false)
  → CaseManager.reset_run()   (builds 27-match list)
  → _start_next_match()       (gets match 1 box via get_box_for_match(1))

RunManager.handle_match_won(critical)
  → completed_match = match_number
  → match_number += 1
  → gs.case_match_index = match_number
  → if completed_match == 27: gs.run_won = true
  → [normal power/rotation flow]

RunManager._start_next_match()
  → if gs.run_won: CaseManager.notify_run_won() → run_won signal → match.gd shows overlay; RETURN
  → else: next_box = CaseManager.get_box_for_match(match_number) → next_match_ready.emit(next_box)
```

## Gotchas
- **`reset_run()` must be called before `get_box_for_match()`.** Calling `get_box_for_match()` before `reset_run()` returns null/errors for all indices because `_case_list` is empty.
- **Box draws are with replacement.** The same box can appear multiple times within an act. With only 2 easy-tier boxes, each of the 9 act-1 slots is 50/50 between them. High repetition is acknowledged as acceptable for slice 1 — adding more boxes per tier is deferred.
- **`run_won` fires AFTER the rotation pick, not immediately on match win.** RunManager completes the full power-offer → rotation flow before calling `notify_run_won()`. This is intentional: the player gets their end-of-match rewards even on the winning match.
- **`get_act_for_match()` is stateless** — it derives purely from the index, no _case_list needed. Safe to call any time.
- **Headless test setup requires CaseManager registration.** Tests calling RunManager.start_run() must register CaseManager (see test_run_manager.gd _init() pattern).
- **No class_name declaration.** Adding class_name CaseManager would cause "hides an autoload singleton" parse error. Access via `Engine.get_singleton("CaseManager")`.

## Out of Scope (deferred to future slices)
- Entity selection (slice 4) — picking Diabolic/Cosmic/Ethereal at run start
- Forced Source box at match 27 (slice 5) — currently match 27 is just a random hard-tier box
- Within-act texture (slice 3) — silent/vignette/event rolls between matches
- ~~Crossroads after match 9 and 21 (slice 2) — Rest/Whetstone choice~~ **Implemented (feature/crossroads)**

## Recent Changes
| Date | Change |
|------|--------|
| 2026-05-07 | Created. Implements 27-match Case structure (9 easy / 12 medium / 6 hard). |
