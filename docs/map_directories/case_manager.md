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
    #   Matches 22–26 → 5 random draws from hard-tier boxes (Source boxes excluded by get_by_tier)
    #   Match   27    → forced to BoxLibrary.get_source(GameState.entity_id) — the entity's Source box
    # Also picks a random entity via EntityLibrary.get_random() and writes its id to
    # GameState.entity_id. If EntityLibrary singleton is missing, entity_id is left unchanged.
    # If the Source box is not found (entity_id empty or missing row), falls back to random hard-tier
    # box with push_error — match 27 will have a hard-tier box but won't be the themed Source.
    # Called by RunManager.start_run() after GameState.reset_run().

func get_box_for_match(idx: int) -> BoxDefinition
    # Returns _case_list[idx - 1]. idx is 1-based (1..27).
    # push_error and returns null if idx is out of range.

func get_act_for_match(idx: int) -> int
    # Returns 1 (idx ≤ 9), 2 (idx ≤ 21), or 3 (idx > 21). Does not require reset_run() first.

func get_location_name(act: int) -> String
    # Returns the entity-themed location name for the given act (1/2/3).
    # Looks up EntityLibrary.get_entity(GameState.entity_id).location_names[act - 1].
    # Fallback to "Location N" if entity_id is empty, EntityLibrary is missing, or entity is null.

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
- `BoxLibrary` — calls `get_by_tier("easy"/"medium"/"hard")` and `get_source(entity_id)` in reset_run()
- `EntityLibrary` — calls `get_random()` in reset_run(); calls `get_entity(entity_id)` in get_location_name()
- `GameState` — reads and writes `entity_id` in reset_run(); reads `entity_id` in get_location_name()

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
- **Box draws are with replacement.** The same box can appear multiple times within an act. With only 1 regular hard-tier box (Compressed), matches 22–26 all use Compressed. High repetition is acknowledged — adding more boxes is deferred.
- **Match 27 is always the entity's Source box.** This is forced in `reset_run()` by calling `BoxLibrary.get_source(GameState.entity_id)` and appending it as the 27th entry. Matches 22–26 draw from `get_by_tier("hard")` which excludes Source boxes.
- **Source box fallback on missing entity.** If `entity_id` is empty (e.g. tests that skip EntityLibrary setup), `get_source()` returns null and `reset_run()` falls back to a random hard-tier box with push_error. Tests registering EntityLibrary will not see this error.
- **`run_won` fires AFTER the rotation pick, not immediately on match win.** RunManager completes the full power-offer → rotation flow before calling `notify_run_won()`. This is intentional: the player gets their end-of-match rewards even on the winning match.
- **`get_act_for_match()` is stateless** — it derives purely from the index, no _case_list needed. Safe to call any time.
- **`get_location_name()` depends on EntityLibrary and GameState singletons.** If EntityLibrary is not registered, it returns the plain "Location N" fallback. Safe to call any time but returns placeholder text if entity_id is "".
- **Entity is picked during `reset_run()`.** GameState.entity_id is set to "" by GameState.reset_run() first, then CaseManager.reset_run() writes the chosen entity id. The order of calls in RunManager.start_run() is GameState.reset_run() then CaseManager.reset_run() — if this order is ever swapped, entity_id will be "" for the entire run and match 27 will fall back to a random hard-tier box.
- **Headless test setup requires CaseManager registration.** Tests calling RunManager.start_run() must register CaseManager. Tests using CaseManager.reset_run() directly should also register EntityLibrary; without it, match 27 falls back with a push_error but all tests still pass.
- **No class_name declaration.** Adding class_name CaseManager would cause "hides an autoload singleton" parse error. Access via `Engine.get_singleton("CaseManager")`.

## Out of Scope (deferred to future slices)
- ~~Forced Source box at match 27 (slice 5)~~ **Implemented (feature/source-boxes)**
- ~~Entity selection (slice 4) — picking Diabolic/Cosmic/Ethereal at run start~~ **Implemented (feature/entity-types)**
- ~~Within-act texture (slice 3) — silent/vignette/event rolls between matches~~ **Implemented (feature/within-act-texture)**
- ~~Crossroads after match 9 and 21 (slice 2) — Rest/Whetstone choice~~ **Implemented (feature/crossroads)**

## Recent Changes
| Date | Change |
|------|--------|
| 2026-05-07 | feature/source-boxes: reset_run() now forces match 27 = BoxLibrary.get_source(GameState.entity_id). The ACT3_SIZE loop changed from 6 iterations to 5 (matches 22–26) + 1 forced Source box (match 27). Added fallback push_error if Source box not found. BoxLibrary dependency expanded to include get_source(). |
| 2026-05-07 | feature/entity-types: reset_run() now also picks a random entity (EntityLibrary.get_random()) and writes entity_id to GameState. Added get_location_name(act) — returns entity's themed location name for the given act, falling back to "Location N" if entity_id is empty or EntityLibrary missing. |
| 2026-05-07 | Created. Implements 27-match Case structure (9 easy / 12 medium / 6 hard). |
