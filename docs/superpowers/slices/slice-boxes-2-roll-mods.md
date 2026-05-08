Build feature/boxes-roll-mods — Slice 2 of the Box Design Backlog.

CONTEXT

The full design lives at docs/superpowers/specs/2026-05-07-box-design-backlog.md.
Read Axis 5 (Roll Modifiers) before starting. Re-read CLAUDE.md.

This is slice 2 of 7. Adds 7 boxes whose mechanic modifies how dice values
or roll totals resolve. All are localized to dice-resolution code — no board
state changes, no tab mutation, no multi-board logic.

Prerequisite: slice 1 (composition) should be merged first so the box pool
is healthy before adding mechanical variants.

DESIGN RATIONALE

  - ROLL mods are the next-cheapest axis after pure composition — each box
    is one localized rule applied during dice resolution.
  - Forces the first "box-specific behavior" hook into the codebase, which
    later slices (DICE, BHV, TOPO) will reuse.

BOXES TO ADD (7)

  heavy_dice, weak_dice, halving_box, doubling_box, exploding_ones,
  pair_swallows, high_die_doubles

Per-box rules in design doc Axis 5.

KEY ARCHITECTURE QUESTIONS (resolve at start of slice)

  - **Where does the modifier live?** Options:
    1. Hardcoded registry: scripts/match/box_roll_modifiers.gd with a Dict
       mapping box_id → Callable that mutates the rolled-dice array.
    2. CSV column on boxes.csv: roll_modifier_id pointing to a known function.
    3. Resource subclass per modifier (RollModifierResource).

    Recommendation: option 1 for prototype. Cheap, easy to extend, no CSV
    schema change. Move to CSV-driven when the registry hits ~20 entries.

  - **When does the modifier fire?** After raw dice rolled, before the player
    sees the rolled values? Or after the player sees the raw and before they
    commit? Recommended: applied during the roll resolution, displayed values
    are post-modifier. (Simpler UX: the box "rolls funny.")

  - **How do modifiers compose with existing abilities (reroll_die, empower,
    weaken)?** Most ROLL mods should compose linearly — the modifier applies
    once at roll time; abilities apply on top. exploding_ones is the messy one:
    if a player's reroll lands on a 1, does it explode? Recommend: yes.

CHANGES (in order, after architecture is locked)

1. Create scripts/match/box_roll_modifiers.gd with the registry pattern and
   one stub modifier (e.g., heavy_dice's `+1 to each die`).
2. Wire the registry into RoundManager.commit_roll (or wherever the rolled
   dice array lives) — call modifier(rolled_dice) with the current box id.
3. Add the 7 boxes to boxes.csv with their tab specs.
4. Implement each modifier function:
     * heavy_dice: `die.value += 1` for each die
     * weak_dice: `die.value = max(1, die.value - 1)`
     * halving_box: `total = floor(total / 2)` (acts on sum, not dice)
     * doubling_box: `total = total * 2`
     * exploding_ones: for each die showing 1, reroll same die type, add result
       (chains; cap chain depth at 10 to prevent infinite loops)
     * pair_swallows: scan rolled dice; for each pair of equal values, replace
       with one die showing the sum
     * high_die_doubles: identify highest face, contribute its value × 2 to total
5. Add tests/test_box_roll_modifiers.gd:
     * Each modifier produces expected output for sample inputs
     * Composition with abilities (reroll, empower) works
     * exploding_ones chain depth caps as expected
6. Manual playtest each modifier from dev menu.
7. Update CLAUDE.md "Current Build State" with the new boxes and the
   roll-modifier registry pattern.

PROTOTYPING DISCIPLINE

  - Display raw modifier output in the dice UI; don't hide what the modifier
    did. Players need to see "die rolled 3, +1 = 4" to understand.
  - No animation polish on roll modifiers. Static "boxed dice show modified
    values" is fine.

OUT OF SCOPE

  - Modifier-stacking across boxes (no two ROLL boxes will be active at once)
  - CSV-driven modifier IDs (deferred until registry grows)
  - UI tooltips explaining the modifier mid-match (a one-line label is fine)

WORKFLOW

  - Branch from master: git checkout master && git checkout -b feature/boxes-roll-mods
  - Implement, commit incrementally.
  - QA handoff with bug + playability checklist.
  - /wrapup to merge.

THE QUESTION THIS SLICE IS TESTING

Does the roll-modifier domain produce meaningfully different play feel,
or do all 7 just feel like "math noise" the player ignores?
  - Which 2-3 are immediately memorable?
  - Does heavy_dice / doubling_box feel like a power-up moment or just a
    threshold inflation?
  - Does exploding_ones feel exciting or just lucky?
