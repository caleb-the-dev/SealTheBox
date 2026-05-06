Build feature/entity-types — Slice 4 of the Case meta-flow.

CONTEXT

The full design lives at docs/superpowers/specs/2026-05-06-game-flow-design.md.
Read it first — the "Prototyping Discipline" section near the top is load-bearing.
Also re-read CLAUDE.md (project root) for the vertical-slice discipline rules and
the dev workflow.

This is slice 4 of 5. Slices 1–3 are shipped — runs are 27-match Cases with
crossroads at the act boundaries and a vignette/event texture system using a
single shared "default" pool. This slice introduces the three entity types
(Diabolic, Cosmic, Ethereal), randomized per run, with their own vignette and
event pools.

No themed Source boxes yet — that's slice 5. Mechanically the entity is
flavor-only (no asymmetric dice math).

DESIGN RATIONALE

  - The dice taxonomy already names Diabolic / Cosmic / Ethereal. Pulling that
    forward as the entity taxonomy creates resonance with future work where
    matching dice could be more effective vs. matching entities (deferred).
  - Run-to-run variety matters: with no entity, every run feels the same.
    Three entity flavors give players "this is an Ethereal case" framing
    without changing core math.
  - Content is shallow on purpose — 2 vignettes per entity + 1 event per entity
    is enough to feel different, not enough to be production. The system is
    what's being tested.

CHANGES (in order)

1. Create resources/entity_data.gd:
     - id: String                       # diabolic / cosmic / ethereal
     - display_name: String             # "the devil" / "a cosmic horror" /
                                        #   "an apparition" — placeholder copy fine
     - location_names: Array[String]    # length 3, one per act
     - vignette_pool_id: String         # references vignettes.csv pool_id
     - event_pool_id: String            # references events.csv pool_id

2. Create data/entities.csv with 3 rows. Use semicolons inside the
   location_names cell to separate the three location names per row, parsed
   into an array on load. Example shape (placeholder copy):

     id,display_name,location_names,vignette_pool_id,event_pool_id
     diabolic,"the devil","sulfur manor;bone catacombs;pact tower",vig_diabolic,evt_diabolic
     cosmic,"a cosmic horror","wrong-angled house;the deep mine;the silent observatory",vig_cosmic,evt_cosmic
     ethereal,"an apparition","quiet hospice;the drowned chapel;the asylum gallery",vig_ethereal,evt_ethereal

3. Create scripts/globals/entity_library.gd autoload:
     - Standard CSV-parser pattern matching AbilityLibrary / BoxLibrary.
     - Public API:
         * get_entity(id) -> EntityData
         * get_all() -> Array[EntityData]
         * get_random() -> EntityData

4. Update data/vignettes.csv: add ~2 vignettes per entity, using the
   per-entity pool_ids. Keep the existing "default" pool entries alive for
   backward compatibility OR migrate them — your call, simplest path wins.
   Result: ~6 new vignettes (2 × 3 entities). Placeholder copy fine.

5. Update data/events.csv: add 1 event per entity using the per-entity
   pool_ids. Result: ~3 new events. Each event uses only effect-string DSL
   features that already exist (or extend the parser if a clearly-needed
   effect comes up — see slice 3's parser for currently supported set).

6. Update GameState:
     - Add entity_id: String — set at run start.
     - Reset_run() rolls a new entity (EntityLibrary.get_random()) and stores
       its id.

7. Update CaseManager:
     - On reset_run, after picking the entity, store entity_id on GameState.
     - When asked for the location name for an act (1–3), return the matching
       string from entity.location_names.

8. Update TextureRoller:
     - Read entity.vignette_pool_id and entity.event_pool_id from GameState's
       current entity instead of hardcoded "default".

9. Update top bar:
     - Replace "Location 1/2/3" with the entity's themed location name for
       the current act.
     - Optionally add a small "Case: [entity display_name]" indicator
       somewhere unobtrusive — placeholder text fine.

10. Update RunWonOverlay:
    - Replace "the entity is sealed" with "{display_name} is sealed", e.g.
      "the devil is sealed".

11. Tests — extend tests/test_case_manager.gd or add tests/test_entity.gd:
    - Reset_run picks one of the three entities (run reset_run a few times,
      assert the set of entity_ids seen has 3 distinct values within a
      reasonable trial count — or just patch the RNG and verify it picks
      what it's told).
    - TextureRoller uses the current entity's pool ids.
    - Top bar location label matches entity.location_names[act-1].
    - Run-won overlay text contains the entity's display_name.

12. Update CLAUDE.md "Current Build State":
    - Add: three entity types (Diabolic / Cosmic / Ethereal), randomized per
      run; per-entity vignette + event pools; entity-themed location names
      and run-won copy.

PROTOTYPING DISCIPLINE (re-emphasized — see spec section)

  - 2 vignettes + 1 event per entity is the entire content for this slice.
    Do NOT write more.
  - Placeholder copy fine for entity display names and location names.
  - No entity-specific UI styling, no per-entity color palettes, no entity art.
  - No animation on entity reveal — entity just shows in the top bar.
  - If migrating the slice-3 "default" pool entries is awkward, leave them
    in place and use them as a fallback. Only the entity pools need to work.

OUT OF SCOPE (explicitly — slice 5 and beyond)

  - Themed Source boxes per entity (slice 5)
  - Mechanical asymmetry (Diabolic dice doing more vs. devil entity etc.) —
    explicitly deferred per the spec
  - Per-entity color/styling/art
  - Entity art for run-won overlay
  - Player-chosen entity at run start (the spec rejected this option)
  - More than 2 vignettes / 1 event per entity — separate content work later

WORKFLOW

  - Branch from master: git checkout master && git checkout -b feature/entity-types
  - Implement, commit incrementally on the branch.
  - When done, give me a QA checklist (bugs + fun/playability questions).
  - I'll playtest. Once approved, use the /wrapup skill to merge to master.

THE QUESTION THIS SLICE IS TESTING

Does playing different entities feel different, even with mechanical parity?
Specifically:
  - With 2 vignettes and 1 event per entity, do back-to-back runs feel
    distinguishable, or does the lack of mechanical asymmetry make it feel
    cosmetic?
  - Are the location names doing real work, or do players never look at them?
  - Does the entity name in the run-won overlay land emotionally, or feel
    like text on a box?
  - Is one entity already noticeably "favorite" / "least favorite" with this
    little content? (If so, expect that to amplify with more content — note
    which.)

If "yes / yes / yes / not really", entity system is validated and slice 5
adds the themed Source. If "feels cosmetic", flag a need for either more
content per entity or earlier mechanical asymmetry than the spec planned.
