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
    # Builds (or rebuilds) the 27-match list:
    #   Matches  1–8  → 8 random draws (with replacement) from easy-tier boxes
    #   Match    9    → mid-boss slot 0 (the Pact or the Anchor, randomly)
    #   Matches 10–20 → 11 random draws from medium-tier boxes
    #   Match   21    → mid-boss slot 1 (the other of the Pact / Anchor)
    #   Matches 22–26 → 5 random draws from hard-tier boxes
    #   Match   27    → ALWAYS Den of Sevens (source_for == "final")
    # Boss pool is split: boxes with source_for == "final" go to match 27;
    # the rest (mid-boss pool) are shuffled and assigned to matches 9 and 21.
    # After building the list, runs a marquee-dedup pass: walks the list and replaces
    # any second occurrence of a "marquee" box (currently: ["bounty_box"]) with a
    # fresh random draw from the same tier — ensures once-per-run boxes appear at most once.
    # No active box is in the marquee_ids list as of 2026-05-09 (bounty_box dropped from CSV).
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
const ACT1_SIZE := 9    # matches 1–9  (8 easy + boss at position 9)
const ACT2_SIZE := 12   # matches 10–21 (11 medium + boss at position 21)
const ACT3_SIZE := 6    # matches 22–27 (5 hard + boss at position 27)
```

## Internal State
```gdscript
var _case_list: Array   # Array of BoxDefinition, length 27; built by reset_run(); index 0 = match 1
```

## Dependencies
- `BoxLibrary` — calls `get_by_tier("easy"/"medium"/"hard"/"boss")` in reset_run()
- `GameState` — reads `run_won`; `case_match_index` synced by RunManager (CaseManager does not write it)

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
- **Box draws within an act are with replacement.** The same easy/medium/hard box can appear multiple times within that act's range. With only 1 regular hard-tier box (Compressed), matches 22–26 always use Compressed. High repetition acknowledged — more boxes deferred.
- **Match 27 is always Den of Sevens (source_for == "final").** `reset_run()` partitions the boss pool: any box with `source_for == "final"` is extracted as `final_boss` and fixed to slot 27. The remaining boxes (`mid_boss`) are shuffled for slots 9 and 21. Currently: the Pact and the Anchor fill mid_boss; Den of Sevens is final_boss. If no final boss is found, `push_error` fires and the first boss box is used as fallback.
- **Mid-boss pool must have exactly 2 boxes.** Currently satisfied: the Pact + the Anchor. Adding a third mid-boss box would cause `mid_boss[2]` to never be used; removing one would cause an index-out-of-range crash at `mid_boss[1]`.
- **`run_won` fires AFTER the rotation pick, not immediately on match win.** RunManager completes the full power-offer → rotation flow before calling `notify_run_won()`. This is intentional.
- **`get_act_for_match()` is stateless** — it derives purely from the index, no _case_list needed. Safe to call any time.
- **No class_name declaration.** Adding class_name CaseManager would cause "hides an autoload singleton" parse error. Access via `Engine.get_singleton("CaseManager")`.

## Recent Changes
| Date | Change |
|------|--------|
| 2026-05-09 | slice-boxes-4: marquee-dedup pass added to reset_run(). Walks the built list; any second occurrence of a marquee box (currently only "bounty_box" in the ids list) is replaced with a tier-matched non-marquee draw. bounty_box was then dropped from boxes.csv, so the pass is effectively a no-op today but the infrastructure is intact. |
| 2026-05-08 | Slice 1 playtest: final boss separation. Boss pool split into `final_boss` (source_for=="final", always match 27) and `mid_boss` (shuffled, matches 9 and 21). Den of Sevens (all 7s) is the fixed final boss. |
| 2026-05-08 | Playtest refactor: dropped entity selection and get_location_name(). New difficulty structure: 8 easy → boss@9 → 11 medium → boss@21 → 5 hard → boss@27. Boss pool (tier="boss") shuffled once per run; each boss match gets a unique box. EntityLibrary dependency removed. |
| 2026-05-07 | feature/source-boxes: match 27 forced to entity's Source box via BoxLibrary.get_source(). |
| 2026-05-07 | feature/entity-types: reset_run() picked random entity; get_location_name(act) added. |
| 2026-05-07 | Created. 27-match Case structure (9 easy / 12 medium / 6 hard). |
