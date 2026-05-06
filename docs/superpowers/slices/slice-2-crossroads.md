Build feature/crossroads — Slice 2 of the Case meta-flow.

CONTEXT

The full design lives at docs/superpowers/specs/2026-05-06-game-flow-design.md.
Read it first — the "Prototyping Discipline" section near the top is load-bearing.
Also re-read CLAUDE.md (project root) for the vertical-slice discipline rules and
the dev workflow.

This is slice 2 of 5. Slice 1 (feature/case-shape) is already shipped — the run
is now a 27-match Case with 3 acts of 9 / 12 / 6, win on match 27, and a
run-won overlay. The periodic every-5-matches die swap is still in place from
before; this slice REPLACES it with a between-act crossroads choice.

This slice adds the meaningful between-act decision point and removes the old
periodic die swap. No texture (vignettes / events) yet — that's slice 3. No
entity types yet — that's slice 4. No themed Source — that's slice 5.

DESIGN RATIONALE

  - Act boundaries currently feel invisible (slice 1's open question). The
    crossroads gives them weight: a forced choice that changes the run state.
  - Reducing from "free die swap every 5 matches" to "1 die swap option at most
    twice per run" creates real opportunity cost between healing and tooling.
    Players have to pick what they need most at this moment.
  - Binary Rest / Whetstone is intentionally minimal — we want to feel whether
    the structural beat works before designing more options. Reliquary,
    Provisions, Press On are all in the spec but deferred until we know the
    base rhythm is fun.

CHANGES (in order)

1. Create scripts/run/crossroads_controller.gd:
     - Public method: show_crossroads(after_match: int) — opens overlay.
     - Emits crossroads_resolved signal when player picks an option.
     - Resolves choice:
         * Rest      → GameState.hp = min(hp + 2, max_hp). Close overlay.
         * Whetstone → trigger the existing die-swap-offer flow once.
                        After swap completes (or skip), close overlay.

2. Create scripts/ui/crossroads_overlay.gd + scenes/ui/crossroads_overlay.tscn:
     - Opaque black background (per Prototyping UI Rule).
     - Header text: "Crossroads" (placeholder copy is fine).
     - Two big buttons:
         * Rest        — subtitle: "+2 HP"
         * Whetstone   — subtitle: "swap one die"
     - Reuse the visual pattern from the existing power-offer overlay or
       run-won overlay — copy and modify, don't design fresh.

3. Wire CaseManager (or RunManager — whichever drives between-match flow):
     - After match 9 ends and existing reward beats (rotation pick, power offer
       if critical) resolve, fire CrossroadsController.show_crossroads(9)
       BEFORE proceeding to match 10.
     - Same after match 21, before proceeding to match 22.
     - Wait for crossroads_resolved before advancing.

4. Remove the periodic every-5-matches die swap entirely:
     - Delete the trigger logic.
     - Remove any related state (counter, flags) from GameState if no longer
       used.
     - Remove its UI overlay/trigger if it had one separate from the generic
       die-swap-offer flow. The die-swap-offer flow itself stays — Whetstone
       reuses it.

5. Tests — extend tests/test_case_manager.gd or create tests/test_crossroads.gd:
     - Crossroads fires after match 9 and after match 21, NOT at any other
       boundary.
     - Rest applies +2 HP, capped at max_hp.
     - Whetstone triggers exactly one die-swap-offer flow.
     - crossroads_resolved fires exactly once per shown crossroads.
     - Periodic die swap (every 5 matches) no longer fires anywhere in a run.

6. Update CLAUDE.md "Current Build State":
     - Add: crossroads system (Rest / Whetstone) replaces periodic die swap;
       fires after match 9 and match 21.
     - Remove the bullet about "die swap offered every 5 matches" if present.

PROTOTYPING DISCIPLINE (re-emphasized — see spec section)

  - "Crossroads" as a header is fine — no per-act themed copy yet.
  - Plain button labels with one-line subtitles.
  - No animations, no transitions, instant overlay show/hide.
  - Reuse the existing power-offer or run-won overlay structure as a starting
    point — same opaque background, same button style.
  - If the die-swap-offer flow is awkward to call as a sub-flow from Whetstone
    (e.g., it expects to be the top-level overlay), flag it instead of
    refactoring deeply. A quick wrapper is fine.

OUT OF SCOPE (explicitly — slices 3–5 and beyond)

  - Reliquary, Provisions, Press On (and any other crossroads options beyond
    Rest / Whetstone) — deferred from the spec menu intentionally
  - Themed transition narration ("you travel three days through the moor...")
    — slice 3 territory, when text content infrastructure exists
  - Vignettes / events / texture roller (slice 3)
  - Entity types and entity-themed crossroads copy (slice 4)
  - Source boxes (slice 5)

WORKFLOW

  - Branch from master: git checkout master && git checkout -b feature/crossroads
  - Implement, commit incrementally on the branch.
  - When done, give me a QA checklist (bugs + fun/playability questions).
  - I'll playtest. Once approved, use the /wrapup skill to merge to master.

THE QUESTION THIS SLICE IS TESTING

Does a forced binary choice at act boundaries make those boundaries feel
weighty? Specifically:
  - Does the choice feel meaningful, or is one option always obviously better?
    (If Rest always wins, Whetstone needs more value. If Whetstone always wins,
    Rest needs more value or HP recovery needs to be tighter elsewhere.)
  - Is +2 HP the right amount for Rest? Should it be +1, +3, or something more
    interesting (e.g., heal to full)?
  - Does losing the periodic die swap feel painful, or does it free up the
    pacing?
  - Is twice per run enough crossroads, or does the middle act feel too
    crossroads-deprived?

If "yes / yes / freeing / about right", structure is validated. Otherwise,
revisit the spec's crossroads menu.
