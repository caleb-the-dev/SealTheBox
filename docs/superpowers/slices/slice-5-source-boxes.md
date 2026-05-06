Build feature/source-boxes — Slice 5 of the Case meta-flow.

CONTEXT

The full design lives at docs/superpowers/specs/2026-05-06-game-flow-design.md.
Read it first — the "Prototyping Discipline" section near the top is load-bearing.
Also re-read CLAUDE.md (project root) for the vertical-slice discipline rules and
the dev workflow.

This is slice 5 of 5 — the capstone. Slices 1–4 are shipped — runs are
27-match Cases with crossroads, vignette/event texture, and three randomized
entity types with per-entity content. Match 27 is currently just whatever
random hard-tier box came up. This slice gives match 27 its own themed Source
box per entity, so the finale finally feels distinct.

Smallest, most cosmetic-but-meaningful slice. The point is the run finale.

DESIGN RATIONALE

  - The run currently ends on a hard-tier box that the player has likely seen
    twice already in act 3. The win moment lacks specificity.
  - One Source box per entity (3 new boxes total) gives the finale a distinct
    feel: "the Pact" / "the Veil" / "the Anchor" instead of "another
    Compressed".
  - Source boxes should be the *toughest test of the run*. Tuning will be
    iterative — start somewhere defensible and adjust after playtest.

CHANGES (in order)

1. Extend boxes.csv with a `source_for` column:
     - Values: empty for non-Source boxes; one of diabolic / cosmic / ethereal
       for Source boxes.
     - All existing 5 boxes get empty value (they remain regular pool boxes).

2. Add 3 new rows to boxes.csv — one Source per entity. Suggested starting
   tuning (adjust after playtest):

     id,name,tabs,win_threshold,tier,source_for
     source_devil,"the Pact","1,2,3,4,5,6,7,8,9",18,hard,diabolic
     source_cosmic,"the Veil","2,3,4,5,6,7,8,9,10",20,hard,cosmic
     source_ghost,"the Anchor","1,3,5,6,7,8,9,11,13",22,hard,ethereal

   These are starter values — adjust to land on "noticeably tougher than
   regular hard-tier" without being unwinnable. If they need to be tab-set
   variations of existing boxes for tuning simplicity, that's fine — what
   matters is they have unique names and consistently appear at match 27.

3. Update BoxDefinition resource with the `source_for` field.

4. Update BoxLibrary:
     - get_source(entity_id: String) -> BoxDefinition
     - Helper to filter regular hard-tier boxes (those with empty source_for)
       so CaseManager doesn't accidentally pull a Source for matches 22–26.

5. Update CaseManager:
     - When building the 27-match list, force match 27 = BoxLibrary.get_source(
       GameState.entity_id).
     - Matches 22–26 pull from hard-tier boxes EXCLUDING any with non-empty
       source_for.

6. Update RunWonOverlay (or wherever the win text is composed):
     - Optionally include the Source box name in the message, e.g.
       "the devil is sealed at the Pact". Keep it simple.

7. Tests — extend tests/test_case_manager.gd:
     - Match 27 is always the Source box matching GameState.entity_id.
     - Matches 22–26 never return a Source box.
     - Each entity has exactly one Source defined; BoxLibrary.get_source
       returns it.
     - Run-won overlay text includes the Source box name (if step 6 is done).

8. Update CLAUDE.md "Current Build State":
     - Add: three themed Source boxes (one per entity); match 27 is always
       the Source matching the run's entity; remaining hard-tier boxes
       continue to fill matches 22–26.

PROTOTYPING DISCIPLINE (re-emphasized — see spec section)

  - Source box names ("the Pact" / "the Veil" / "the Anchor") are placeholders
    — fine to keep, fine to rename.
  - Source box mechanics use the existing match system — no special rules,
    no scripted interventions, no boss-fight mechanics. Just a tougher box.
  - If the suggested starter tuning feels wildly off in playtest, prefer
    adjusting numbers in the CSV over redesigning the box concept.
  - No new art, no special intro animation, no music change.

OUT OF SCOPE (explicitly — beyond the slice)

  - Boss-fight mechanics on Source boxes (different rules, scripted
    interventions, multi-stage encounters)
  - Source box art / unique UI styling
  - Cross-run progression (e.g., "you've sealed all 3 entities" achievement)
  - Mechanical asymmetry (still deferred, even though Source boxes would be
    the natural place to introduce it)
  - Tuning passes on the regular hard-tier pool (separate work)

WORKFLOW

  - Branch from master: git checkout master && git checkout -b feature/source-boxes
  - Implement, commit incrementally on the branch.
  - When done, give me a QA checklist (bugs + fun/playability questions).
  - I'll playtest. Once approved, use the /wrapup skill to merge to master.

THE QUESTION THIS SLICE IS TESTING

Does the finale feel like a real ending? Specifically:
  - Does sealing the Source feel like more than "another match" — is there a
    sense of climax?
  - Is the difficulty curve from regular hard boxes (matches 22–26) to the
    Source (match 27) the right shape, or is there a cliff or a flat?
  - Do the Source names land, or are they invisible?
  - Does the win overlay feel like it earns the moment, or does it need more?

If "yes / right shape / land / earns it", the meta-flow design is fully
validated. The next direction (cross-run progression, mechanical asymmetry,
more boxes/entities/events) is its own brainstorm.
