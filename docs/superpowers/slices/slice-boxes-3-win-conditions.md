Build feature/boxes-win-conditions — Slice 3 of the Box Design Backlog.

CONTEXT

The full design lives at docs/superpowers/specs/2026-05-07-box-design-backlog.md.
Read Axis 7 (Win Condition Twists) before starting. Re-read CLAUDE.md.

This is slice 3 of 7. Only 2 boxes, both modifying win/threshold logic.
Small slice on purpose — gets the win-override hook into the codebase
cheaply, available for any future WIN-domain box.

BOXES TO ADD (2)

  crit_only — threshold win disabled; must shut the box
  escalating_threshold — threshold drops each round (R1 ≤30, R2 ≤25, R3 ≤20, R4 ≤15)

KEY ARCHITECTURE QUESTIONS

  - **Where does the win-condition override hook live?** Options:
    1. Registry: scripts/match/box_win_conditions.gd mapping box_id → Callable.
       Callable returns: `null` (no override; use default), `true` (win),
       `false` (not yet), or a numeric threshold override.
    2. Resource subclass per condition.

    Recommendation: option 1 (registry pattern, same as slice 2's roll mods).

  - **escalating_threshold needs round-tick state.** The threshold per round is
    the same per round-index across runs (R1=30, R2=25, etc.). It can be a
    pure function of round_index, no per-box state needed beyond what
    RoundManager already exposes.

  - **crit_only changes the "Continue →" button behavior.** When threshold is
    met but not shut, the button should NOT appear. Need a flag on the box
    (or the registry callable returning `false` for threshold-only state)
    that the UI listens to.

CHANGES (in order)

1. Create scripts/match/box_win_conditions.gd registry stub.
2. Wire the registry into TabBoard.check_win() / RoundManager so:
     * If box has no entry → use default check (remaining sum ≤ threshold).
     * If box has entry → callable decides win/lose/threshold-override.
3. Implement crit_only:
     * Returns `false` for threshold checks (only true on tab_count == 0).
     * UI: hide "Continue →" button when threshold met but tabs remain.
4. Implement escalating_threshold:
     * Returns dynamic threshold based on current round index (1-indexed).
     * UI: threshold label updates each round-start.
5. Add 2 boxes to boxes.csv. (escalating_threshold's csv threshold is the
   round-1 value; the modifier reduces it dynamically.)
6. Add tests/test_box_win_conditions.gd:
     * crit_only: threshold check fails when tabs remain; passes only when
       all tabs sealed.
     * escalating_threshold: threshold value matches expected curve per round.
7. Dev-menu add: a "Force Round X" shortcut to test escalating_threshold's
   per-round behavior without playing 4 rounds.
8. Manual playtest both boxes.
9. Update CLAUDE.md "Current Build State".

PROTOTYPING DISCIPLINE

  - escalating_threshold UI: just update the existing threshold label. No
    animation, no "threshold dropping!" callout.
  - crit_only UI: simply hide the Continue button; no "must shut the box!"
    explanatory text.

OUT OF SCOPE

  - Other Axis 7 boxes (cut from this slice's scope)
  - Match-objective system (deferred Match Objectives feature)
  - Custom win-condition tooltips

WORKFLOW

  - Branch from master: git checkout master && git checkout -b feature/boxes-win-conditions
  - Implement, commit, QA handoff, /wrapup.

THE QUESTION THIS SLICE IS TESTING

Do alternate win conditions produce real tension, or just frustration?
  - Does crit_only feel like a high-stakes match or an unfair one?
  - Does escalating_threshold create round-1 panic, and is that fun or stressful?
  - Is the win-condition registry pattern clean enough to extend, or does it
    become a tangle when paired with other domain hooks?
