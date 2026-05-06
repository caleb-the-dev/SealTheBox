Build feature/within-act-texture — Slice 3 of the Case meta-flow.

CONTEXT

The full design lives at docs/superpowers/specs/2026-05-06-game-flow-design.md.
Read it first — the "Prototyping Discipline" section near the top is load-bearing.
Also re-read CLAUDE.md (project root) for the vertical-slice discipline rules and
the dev workflow.

This is slice 3 of 5. Slices 1 and 2 are shipped — runs are 27 matches in a 9/12/6
shape, with a Rest/Whetstone crossroads after match 9 and match 21. This slice
adds the texture *within* an act: between most matches, draw a beat from a
weighted table — silent, vignette, or small event.

No entity types yet — pools are entity-agnostic. That's slice 4.

DESIGN RATIONALE

  - Slice 1 confirmed (or denied — check playtest notes) that 27 matches feels
    right. Slice 2 added weight to act boundaries. This slice adds the in-act
    texture: a sense that the world is real between matches without slowing the
    math.
  - 50% silent / 30% vignette / 20% small event is the design's starting point.
    Math game first; texture appears, doesn't dominate.
  - Vignettes are pure flavor (one line, click-to-dismiss). Events are tiny
    Reigns-style two-button choices with mechanical effects.
  - We need infrastructure (data libraries, overlays, effect-string DSL) before
    we add lots of content. This slice ships *enough content to playtest the
    system*, not a full deck.

CHANGES (in order)

1. Create resources/vignette_data.gd:
     - id: String
     - pool_id: String          # for now, all vignettes use pool_id "default"
     - text: String

2. Create resources/event_data.gd:
     - id: String
     - pool_id: String          # for now, all events use pool_id "default"
     - prompt: String
     - option_a_label: String
     - option_a_effect: String  # effect-string DSL — see step 5
     - option_b_label: String
     - option_b_effect: String

3. Create data/vignettes.csv with ~3 entries (placeholder copy is fine):
     id,pool_id,text
     v_fog,default,"the fog thickens — you cannot see ten paces ahead"
     v_bell,default,"a bell tolls in the distance, slow and wrong"
     v_cold,default,"the air goes cold for no reason you can name"

4. Create data/events.csv with ~1 entry to prove the system:
     id,pool_id,prompt,option_a_label,option_a_effect,option_b_label,option_b_effect
     e_coin,default,"a stranger offers a cursed coin","Accept","hp-1;charge_random+1","Refuse","none"

   The effect column packs multiple effects with semicolons.

5. Create scripts/globals/vignette_library.gd and event_library.gd autoloads:
     - Standard CSV-parser pattern matching AbilityLibrary / BoxLibrary.
     - Public API: get_pool(pool_id: String) -> Array[VignetteData]
       (or EventData) — returns all entries with that pool_id.

6. Implement effect-string parser (in event_overlay.gd or a small helper):
     - Parses semicolon-separated effects from a single string.
     - Supported effects for this slice:
         * none                 → no-op (used for Refuse buttons)
         * hp+N / hp-N          → modify HP (capped at max for +, min 1 for −;
                                  HP=0 from − triggers existing run-loss path)
         * charge_random+1      → +1 charge to a random non-null ability in
                                  hand (cap at ability max)
     - Unknown effect strings → push_error and apply nothing.
     - Other DSL effects from the spec (max_hp+1, charge_all+1, power_random,
       die_swap_offer) — STUB ONLY for this slice. Add them in later slices
       when an event needs them. Don't build unused effects now.

7. Create scripts/run/texture_roller.gd:
     - Public method: roll(pool_id: String) -> Dictionary
     - Returns one of:
         { type: "silent" }                          (50% probability)
         { type: "vignette", vignette: VignetteData } (30%; random pick from pool)
         { type: "event",    event: EventData      } (20%; random pick from pool)
     - Probabilities live as module-level constants for one-line tuning.
     - If pool is empty for chosen type, fall back to "silent".

8. Create scripts/ui/vignette_overlay.gd + scenes/ui/vignette_overlay.tscn:
     - Opaque black background (Prototyping UI Rule).
     - Centered single-line text from VignetteData.text.
     - Click anywhere to dismiss; emit dismissed signal.

9. Create scripts/ui/event_overlay.gd + scenes/ui/event_overlay.tscn:
     - Opaque black background.
     - Centered prompt text from EventData.prompt.
     - Two buttons below — option_a and option_b labels.
     - On click → parse and apply the chosen effect string → emit
       resolved(option: String) signal → close.

10. Wire TextureRoller into the between-match flow:
    - After each match ends and existing reward beats (rotation pick, power
      offer if critical) resolve, AND BEFORE crossroads check (so crossroads
      preempts texture):
        * If next-match index is a crossroads point (10 or 22), skip texture
          (slice 2's crossroads runs instead).
        * Otherwise, call TextureRoller.roll("default").
        * Show the appropriate overlay (or nothing if silent).
        * Wait for overlay's dismissed/resolved signal before advancing.

11. Tests — create tests/test_texture_roller.gd:
    - Distribution sanity: roll 1000 times, assert each type appears roughly
      proportional to its constant (within reasonable tolerance — e.g.
      ±5 percentage points).
    - Empty-pool fallback: with empty vignette pool, roll never returns a
      vignette type.
    - Effect-string parser unit tests:
        * "none" → no state change.
        * "hp-1" → HP decreases by 1.
        * "hp+2" → HP increases by 2, capped at max.
        * "charge_random+1" → some ability charge increases (or no-op if all
          null).
        * "hp-1;charge_random+1" → both effects applied.
        * "garbage_effect" → no state change, error logged.

12. Update CLAUDE.md "Current Build State":
    - Add: vignette + event system (texture roller) between matches within an
      act; ~3 vignettes + 1 event in placeholder pool; effect-string DSL
      supports none / hp± / charge_random+1.

PROTOTYPING DISCIPLINE (re-emphasized — see spec section)

  - 3 vignettes and 1 event is the entire content for this slice. Do NOT write
    more. We're testing the system, not the writing.
  - Placeholder copy is fine for everything.
  - No animation on overlay show/hide — instant.
  - Reuse the crossroads/run-won overlay visual pattern. Same opaque background,
    same button style.
  - If overlay nesting (texture overlay between two existing overlays) gets
    complicated, simplify by chaining sequentially rather than stacking.
  - Don't implement effect-DSL features that no event currently uses. Stub
    them with a comment in the parser instead.

OUT OF SCOPE (explicitly — slices 4–5 and beyond)

  - Entity-specific pools (slice 4 splits "default" into per-entity pools)
  - Themed location names (slice 4)
  - Source boxes (slice 5)
  - Event-DSL effects beyond none / hp± / charge_random+1 — add as needed
    when an event uses them
  - Larger content libraries (more vignettes, more events) — separate work
    after the system feels right
  - Per-act vignette/event variation — out unless a playtest demands it
  - Inline animations, transitions, sound

WORKFLOW

  - Branch from master: git checkout master && git checkout -b feature/within-act-texture
  - Implement, commit incrementally on the branch.
  - When done, give me a QA checklist (bugs + fun/playability questions).
  - I'll playtest. Once approved, use the /wrapup skill to merge to master.

THE QUESTION THIS SLICE IS TESTING

Does the texture make the world feel real without slowing the math? Specifically:
  - Is 50/30/20 the right mix? (If vignettes feel rare, raise to 40%; if
    events feel intrusive, drop to 10%.)
  - Are vignettes long enough to land or too short to bother with?
  - Does the one event feel like a meaningful choice, or is one option
    obviously correct?
  - Do the overlays interrupt flow in a bad way, or break it up nicely?
  - Do click-to-dismiss vignettes feel good, or do they need an auto-dismiss?

If "yes / good / meaningful / nicely / good", system is validated and slice 4
splits the pool by entity. Otherwise tune constants and content count first.
