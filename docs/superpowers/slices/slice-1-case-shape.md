Build feature/case-shape — Slice 1 of the Case meta-flow.

CONTEXT

The full design lives at docs/superpowers/specs/2026-05-06-game-flow-design.md.
Read it first — the "Prototyping Discipline" section near the top is load-bearing.
Also re-read CLAUDE.md (project root) for the vertical-slice discipline rules and
the dev workflow.

This is slice 1 of 5. It replaces the current infinite match loop with the
27-match Case structure (3 acts of 9 / 12 / 6 matches), wins the run on sealing
match 27, and adds the run-won overlay. Nothing else from the spec ships in
this slice — no crossroads, no vignettes, no events, no entity types, no themed
Source skins. Those are slices 2–5.

DESIGN RATIONALE

  - Smallest change that produces the new shape; everything else hangs off it.
  - 9 / 12 / 6 act sizes are a poetics nod (short setup, long middle, short
    climax). Total = 27 matches, ~25–35 minutes per winning run.
  - We want to playtest whether 27 matches feels right *before* layering content
    on top. If it feels too long or too short, slice 2+ design changes; better
    to learn that now.

CHANGES (in order)

1. Extend boxes.csv with a `tier` column (values: easy / medium / hard).
   Assign existing boxes:
     - Classic   → easy
     - Low Evens → easy
     - Stairs    → medium
     - High Odds → medium
     - Compressed→ hard
   Repetition in acts 1 and 3 is acknowledged and acceptable for the slice.

2. Extend BoxDefinition resource with the `tier` field. Extend BoxLibrary with
   `get_by_tier(tier: String) -> Array[BoxDefinition]`.

3. Extend GameState with:
     - case_match_index: int   # 1..27, increments each match. Reset by reset_run().
     - act: int                # derived: 1 if idx<=9, 2 if <=21, else 3
     - run_won: bool           # set true when match 27 sealed
   reset_run() resets case_match_index to 1 and run_won to false.

4. Create scripts/run/case_manager.gd (autoload):
     - On reset_run, builds the 27-match list:
         * indices  1..9   → random pick from easy tier (with replacement)
         * indices 10..21  → random pick from medium tier (with replacement)
         * indices 22..27  → random pick from hard tier (with replacement)
     - Exposes get_box_for_match(idx: int) -> BoxDefinition
     - Exposes get_act_for_match(idx: int) -> int
     - Emits run_won signal when match 27 is sealed
   MVP NOTE: no source skinning yet. Match 27 is just whatever the random hard
   pull was. The "Source" concept ships in slice 5.

5. Modify RunManager (or wherever the next-box selection currently lives) to
   ask CaseManager for the next box instead of cycling the global 5-box list.
   Increment case_match_index after each completed match.

6. Modify the top bar (scripts/ui/match_top_bar.gd or equivalent) to show:
     - "Match N / 27"   (was "Match N")
     - "Act 1" / "Act 2" / "Act 3"   (new label — plain numerals are fine MVP)
     - "Location 1" / "Location 2" / "Location 3"   (new label — generic strings,
       no entity-themed names yet)

7. Add scripts/ui/run_won_overlay.gd + scenes/ui/run_won_overlay.tscn:
     - Opaque black background (per Prototyping UI Rule).
     - Text: "the entity is sealed" (placeholder copy is fine).
     - One button: "Begin a new case".
     - On click → GameState.reset_run() → returns to first match of new run.
   Reuse the existing run-over overlay structure as a template — copy and
   modify, don't design fresh.

8. Wire CaseManager.run_won signal to show the run_won_overlay in match.gd
   (or wherever overlays are shown today).

9. Leave the existing periodic die-swap-every-5-matches alone in this slice.
   It will be removed in slice 2 when crossroads ships. Do not delete it.

10. Tests:
    - Create tests/test_case_manager.gd with the headless test pattern used by
      tests/test_run_manager.gd. Cover:
        * After reset_run, all 27 boxes are assigned and act boundaries are
          correct (matches 1–9 are easy tier, 10–21 medium, 22–27 hard).
        * case_match_index increments correctly across matches.
        * act value is correct for each match index.
        * run_won fires when match 27 is sealed and not before.
        * Reset_run clears run_won and re-rolls the 27-match list.
    - Run all tests headless and confirm passing before opening for QA.

11. Update CLAUDE.md:
    - Add the "Game Bible — Run Structure" section verbatim from the spec
      (under the Game Bible cluster, after the Dice Pool Rules section).
    - Update the "Current Build State" entry to reflect: infinite match loop
      replaced with 27-match Case (9/12/6 acts), win on match 27, run-won
      overlay added, periodic die swap still in place (will be removed in
      slice 2).

PROTOTYPING DISCIPLINE (re-emphasized — see spec section)

  - Placeholder copy for the win overlay is fine ("the entity is sealed").
  - Plain "Act 1/2/3" and "Location 1/2/3" labels are fine.
  - No animations, no transition polish, no music/sfx.
  - Reuse existing overlay patterns (don't restyle from scratch).
  - If anything turns out to be awkward to MVP, flag it back to me with a
    proposed simpler approach instead of building the full thing.

OUT OF SCOPE (explicitly — these are slices 2–5)

  - Crossroads / Rest / Whetstone (slice 2)
  - Removing the periodic every-5-matches die swap (slice 2)
  - Vignettes, events, the texture roller, event effect-string DSL (slice 3)
  - Entity types, entity randomization, themed location names (slice 4)
  - Themed Source boxes per entity (slice 5)
  - Adding new boxes to thicken the easy/medium/hard pools (separate work)
  - Difficulty rebalancing of existing boxes (separate work)
  - Cross-run / meta-progression of any kind

WORKFLOW

  - Branch from master: git checkout master && git checkout -b feature/case-shape
  - Implement, commit incrementally on the branch.
  - When done, give me a QA checklist (per CLAUDE.md feedback_post_feature_checklist):
    bugs to look for + fun/playability questions to answer during playtest.
  - I'll playtest. Once approved, use the /wrapup skill to merge to master.

THE QUESTION THIS SLICE IS TESTING

Does a 27-match Case (9 / 12 / 6 acts) feel like the right run length and
shape? Specifically:
  - Is the run too long? Too short? Just right?
  - Does the act-boundary moment (entering match 10, entering match 22) feel
    like anything, or is it invisible without crossroads?
  - Does winning by sealing match 27 feel different/more rewarding than just
    "another match", even with placeholder copy?
  - Is box repetition within an act tolerable for MVP, or does it kill the run
    immediately and force an emergency content pass?

If those answers are "yes / yes / yes / tolerable", the structure is validated
and slices 2–5 layer on. If not, we revisit the spec before proceeding.
