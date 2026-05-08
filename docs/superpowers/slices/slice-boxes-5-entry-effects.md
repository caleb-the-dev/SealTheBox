Build feature/boxes-entry-effects — Slice 5 of the Box Design Backlog.

CONTEXT

The full design lives at docs/superpowers/specs/2026-05-07-box-design-backlog.md.
Read Axis 8 (Entry / Persistent Effects) before starting. Re-read CLAUDE.md.

This is slice 5 of 7. Adds 3 boxes that fire effects on match entry or
persist throughout the match. (bounty_box, also an entry effect, ships with
slice 4 because of its dice-pool flavor.)

BOXES TO ADD (3)

  storm_box — extra random die for this match only
  cleanse_box — refill all ability charges on entry; harder tabs
  borrowed_time — 1 HP entry cost; +1 round limit. Only spawnable when HP ≥ 3

KEY ARCHITECTURE QUESTIONS

  - **Entry hooks reuse Power patterns.** Powers already have on_match_start
    hooks (e.g., Coffee Break charges an ability). Box entry effects should
    use the same dispatcher rather than building parallel infrastructure.
    Verify by reading scripts/run/power_manager.gd.

  - **Temporary die for storm_box.** GameState.get_active_pool() (introduced
    in slice 4) needs to support transient additions, not just overrides.
    Approach: persistent pool + per-match pool delta. Apply delta during the
    match, discard at match end.

  - **borrowed_time HP gate.** "Only spawnable when HP ≥ 3" lives in the box
    selection layer (RunManager / CaseManager), not in the box itself.
    Selection should filter eligible boxes by current GameState.

CHANGES (in order)

1. Confirm Power on_match_start dispatcher works for box entry effects;
   refactor if needed so both consumers share one hook system.
2. Extend GameState.get_active_pool() to support transient additions.
3. Add 3 boxes to boxes.csv with their tab specs.
4. Implement each:
     * storm_box: on entry, add a random die type to the per-match pool delta
     * cleanse_box: on entry, set every ability's charges to its max
     * borrowed_time: on entry, hp -= 1; round_limit += 1 (single-match
       override, not persistent)
5. Add HP gate filter to box selection: borrowed_time is skipped when HP < 3.
6. Tests for each entry effect.
7. Dev-menu shortcut to force each.
8. Playtest pass.
9. Update CLAUDE.md.

PROTOTYPING DISCIPLINE

  - cleanse_box's "all charges to max" is a single-line reset; no animation.
  - storm_box's bonus die uses the same UI as a normal die slot, just shaded
    or labeled "TEMP" if trivial. If labeling adds work, skip.

OUT OF SCOPE

  - Per-box ENTRY composability (multiple ENTRY effects on the same box)
  - Permanent/run-level effects (everything here is match-scoped)

WORKFLOW

  - Branch from master, implement, QA, /wrapup.

THE QUESTION THIS SLICE IS TESTING

Do entry effects shape the player's match plan from turn 1?
  - Does cleanse_box feel like a "deep breath" beat in the run?
  - Does borrowed_time feel like a fair tradeoff or a tax for ambition?
  - Does storm_box's extra die make the match feel different, or get lost
    in the noise of the regular pool?
