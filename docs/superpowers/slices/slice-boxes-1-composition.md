Build feature/boxes-composition — Slice 1 of the Box Design Backlog.

CONTEXT

The full design lives at docs/superpowers/specs/2026-05-07-box-design-backlog.md.
Read it first, especially the "Slice Plan" and Axis 1 box specs.
Also re-read CLAUDE.md (project root) for vertical-slice discipline and
the dev workflow.

This is slice 1 of 7. It adds 14 new boxes that vary only in tab composition —
no new game logic, no new domain hooks. Pure CSV rows plus a validation test.
Slices 2–7 add boxes that require new hook systems; this slice deliberately
ships nothing that touches RoundManager, DicePool, or TabBoard logic beyond
existing CSV-loading paths.

DESIGN RATIONALE

  - Cheapest possible expansion of the box pool — validates that more variety
    *in tab values alone* improves replayability before we invest in the
    expensive domain hooks (BHV, TOPO).
  - 14 boxes is enough to feel meaningfully different match-to-match without
    being so many that playtest tuning becomes unmanageable.
  - Each box's tier hint is documented but NOT yet wired into a tier-based
    selection system — that is the Game Flow feature's concern. For this slice,
    new boxes simply join the existing cycle.

BOXES TO ADD (14)

See specs doc Axis 1 for full table. IDs only:
  cluster_of_fours, five_nines, high_wall, exact_evens, lopsided_giant,
  easy_starter, triple_triplets, mirror_ladder, prime_pyramid, crowded_low,
  the_long_count, avalanche, ten_pillars, den_of_sevens

CHANGES (in order)

1. Add 14 rows to seal-the-box/data/boxes.csv with the tab specs and thresholds
   from the design doc. Use the exact ID names from the doc (snake_case).
   Threshold guidance: aim for ~40-50% of tab_sum (rounded to a clean number);
   adjust per-box per the doc's tier hint (Easy = generous threshold,
   Hard = tighter).

2. Verify BoxLibrary auto-loads the new rows via existing CSV parsing — no
   loader changes needed. Confirm by running headless and checking
   BoxLibrary.boxes.size() == 19.

3. Update the existing match cycle so all 19 boxes (5 existing + 14 new) appear
   in the rotation. If RunManager hardcodes the original 5-box order, refactor
   it to use BoxLibrary.get_ordered() (already exists). Random pick OR cycle
   through all 19 — pick whichever matches current behavior.

4. Add tests/test_box_definitions.gd (headless GDScript test):
     * BoxLibrary loads all 19 boxes without errors.
     * Each box's tab_sum is positive.
     * Each box's win_threshold is between 0 and tab_sum.
     * Each box's round_limit (ceili(tab_sum/15)+1) is at least 2.
     * Each box has at least 5 tabs (the design floor).
     * No two boxes share an id.

5. Run the existing test suite (test_run_manager.gd, test_power_effects.gd,
   test_ability_library.gd) to confirm nothing regresses. The match cycle
   refactor in step 3 might touch run_manager logic — verify run flow still
   works end-to-end.

6. Manual playtest pass (Caleb):
     * Win a match with ~5 of the new boxes from the dev-menu shortcut.
     * Confirm thresholds feel earned — flag any box that's trivially won
       on round 1 or impossible by round 4.

7. Update CLAUDE.md "Current Build State":
     * Replace "Boxes: 5 boxes cycling..." with "Boxes: 19 boxes; cycle
       (or random selection) ..." reflecting actual implementation.

PROTOTYPING DISCIPLINE

  - Tab specs and thresholds in the doc are starting points. If a box plays
    badly in step 6, tune the threshold inline — don't redesign tabs.
  - No fancy box selection logic. Just append to the existing cycle.
  - No tier wiring. That's Game Flow's job.
  - If a box is so broken in playtest that it can't be tuned by threshold
    alone, cut it from this slice and note it in CLAUDE.md as a deferred
    follow-up. Better to ship 12 good boxes than 14 mixed ones.

OUT OF SCOPE

  - Tier column on boxes.csv (Game Flow feature)
  - Tier-based pool selection (Game Flow feature)
  - Any domain hooks for BHV/TOPO/DICE/ROLL/WIN/ENTRY (slices 2–7)
  - New abilities or powers
  - UI tweaks beyond what's needed to display 19 boxes in the cycle UI

WORKFLOW

  - Branch from master: git checkout master && git checkout -b feature/boxes-composition
  - Implement, commit incrementally on the branch.
  - When done, give Caleb a QA checklist (per CLAUDE.md feedback_post_feature_checklist):
      * Bugs to look for (e.g., threshold parsing, missing tabs, dev menu mismatch)
      * Fun/playability questions ("which 3 of the 14 felt most distinct? worst?")
  - Caleb playtests. Once approved, use the /wrapup skill to merge to master.

THE QUESTION THIS SLICE IS TESTING

Does adding 14 tab-composition boxes to the rotation pool make the game feel
meaningfully more varied — or does the underlying partition mechanic feel
identical regardless of which box is up?

Specifically:
  - Are 3+ of the new boxes immediately memorable ("oh, the all-9s one"
    or "the doubled ladder")?
  - Do thresholds feel right out of the box, or does most of the playtest
    surface as "this is too easy / too hard"?
  - Does the 19-box rotation feel rich enough to defer slices 2–7, or does
    Caleb still feel "every match plays the same" because composition alone
    isn't enough?

If yes/yes/rich-enough — the COMP axis carries enough weight to play with
for a while; slices 2–7 can wait for stronger demand. If the answer is
"composition alone is bland" — prioritize slice 2 (ROLL mods) next, since
it's the next-cheapest axis to add real mechanical variety.
