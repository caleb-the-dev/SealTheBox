Build feature/boxes-dice-access — Slice 4 of the Box Design Backlog.

CONTEXT

The full design lives at docs/superpowers/specs/2026-05-07-box-design-backlog.md.
Read Axis 4 (Dice Access) before starting. Re-read CLAUDE.md.

This is slice 4 of 7. Adds 6 boxes that modify pool size, die availability,
or impose round-end costs. Heavier than slice 2/3 because boxes here often
combine multiple sub-mechanics (pool change + tab change + entry cost).

BOXES TO ADD (6)

  single_die — only 1 die rolled per round; tabs `1;1;2;3;4;4`
  locked_d8 — d8s disabled this match
  locked_d4 — d4 disabled this match (slightly easier)
  bounty_box — marquee match, once per run, fixed Power on entry, harder tabs
  tax_per_roll — 1 HP loss per round end after R1; tabs `2;3;4;5;6`
  forced_full_commit — must commit all rolled pips; leftover deals damage

KEY ARCHITECTURE QUESTIONS

  - **Per-box pool override.** Need a way for a box to override the dice pool
    for the duration of the match. Cleanest: GameState exposes
    `get_active_pool()` which checks the current box for an override before
    falling back to the persistent pool. Override is read-only — the
    persistent pool is unchanged after the match ends.

  - **bounty_box marquee state.** "Once per run" requires GameState tracking
    of which marquee boxes have appeared. Cheapest: GameState.boxes_seen
    Set[String]; CaseManager / RunManager skips marquee boxes already in the
    set. Reset on reset_run().

  - **bounty_box fixed Power.** Which power? See Open Questions in spec doc;
    this slice should pick one and ship it (placeholder is fine — pick the
    most flavorful surviving power).

  - **forced_full_commit composability.** Confirm with current partition rules
    that "must commit all pips" is even expressible. If the existing UI
    requires the player to drag dice to tabs, "leftover damages you" is
    natural. If the engine auto-partitions, this needs a tweak.

  - **tax_per_roll hooks into round-end damage.** Already similar to existing
    hp tick logic from Phoenix Down / Survivor. Reuse the round-end damage
    pipeline.

CHANGES (in order, after architecture confirms)

1. Add a "dice access modifier" registry similar to slice 2/3.
2. Implement pool-override mechanism in GameState.get_active_pool().
3. Add 6 boxes to boxes.csv.
4. Implement each:
     * single_die: pool override → 1 random die from current pool
     * locked_d8 / locked_d4: pool override filtering out the locked die type
     * bounty_box: on entry, grant Power X (placeholder); track in
       GameState.marquee_seen
     * tax_per_roll: round-end hook deals 1 HP after round 1
     * forced_full_commit: round-end hook checks for leftover pips, deals
       damage equal to leftover
5. Add bounty_box marquee gating to box selection (skip if already seen).
6. Tests for each box's modifier behavior.
7. Dev-menu addition: "Force Bounty Box" and "Reset Marquee Set".
8. Playtest pass.
9. Update CLAUDE.md.

PROTOTYPING DISCIPLINE

  - bounty_box: hardcode the granted Power for now. Refactor to data-driven
    when more marquee boxes ship.
  - single_die's tabs are tight (`1;1;2;3;4;4`, sum 15). Threshold should be
    lenient — aim for ~50% of sum.

OUT OF SCOPE

  - More marquee boxes (bounty_box is the only one in this slice)
  - Per-die-type pool maximums (Game Bible note, future feature)

WORKFLOW

  - Branch from master, implement, QA, /wrapup.

THE QUESTION THIS SLICE IS TESTING

Do dice-access modifiers produce strategic depth, or just unfair-feeling
restrictions?
  - Is single_die the "puzzle box" it's meant to be, or just frustrating?
  - Does bounty_box feel like a marquee match — does the fixed Power offer
    create memorable run moments?
  - Does locked_d8 vs locked_d4 produce different play feel, or do they blur?
