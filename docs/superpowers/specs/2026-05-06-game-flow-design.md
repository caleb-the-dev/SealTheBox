# Game Flow Design — The Case
*2026-05-06*

## Premise

A **run** is a *Case*: the player — an unseen exorcist-figure — travels to three locations in pursuit of a single dark entity, sealing 27 of its manifestations along the way and finally sealing the **Source** itself. The current infinite-loop model (boxes cycle until HP = 0) is replaced with a finite, three-act structure that has a real win state.

Setting tone: dark, otherworldly, sparse. The game is math first, story second; the world is conveyed through one-line vignettes and short text events between matches, not through cutscenes or dialogue.

---

## Prototyping Discipline (READ FIRST)

> Every slice in this design ships as the **simplest thing that proves the idea works and is fun.** Placeholders are encouraged.

This is a prototype. Each slice is a playtest, not a product. Concretely, while implementing any slice below:

- **Placeholder content beats designed content.** "Vignette 1", "Vignette 2", "Vignette 3" is fine for slice 3. We're testing the *system*, not the writing.
- **One of each, not many.** Slice 3 ships ~3 vignettes and ~1 event, not 10 of each. Slice 4 ships 2–3 vignettes per entity, not full decks.
- **Hardcoded > data-driven where it saves time.** If the CSV-loading pattern is heavy for one row, hardcode it for the slice and convert to CSV later.
- **Reuse existing UI patterns.** The vignette / event / crossroads / win overlays should copy the structure of the current power-offer overlay, not be designed fresh. Same opaque-black background, same button style, same dismiss flow.
- **No animations, no polish.** Static text, static buttons, instant transitions. Polish comes after fun is proven.
- **Skip features that don't change the playtest.** Entity-themed location names (slice 4) can be a single hardcoded string per entity, not a list. The "act label" can be "Act 1/2/3", not "Arrival / Investigation / Confrontation".
- **If a feature is awkward to MVP, flag it instead of building the full thing.** Better to ship a slice with a known stub than a polished slice that takes 3× longer.

**Each slice's success is binary: did it teach us something about whether the design is fun?** That's the only acceptance criterion until we've playtested all five slices. Refinement comes after.

---

## Scope & Boundaries

### In Scope (full design — see "Shipping in slices" below for split)

- **Run shape:** finite *Case* of 27 matches, broken into three acts of 9 / 12 / 6 matches.
- **Locations:** each act takes place at one Location with a difficulty-tiered box pool (easy / medium / hard).
- **Win state:** sealing match 27 (the Source) ends the run with a win screen.
- **Lose state:** HP = 0 at any point ends the run (unchanged from today).
- **Within-act texture:** between matches inside an act, draw a beat from a weighted table — 50% silent, 30% one-line vignette, 20% small-event-with-choice.
- **Between-act crossroads:** after match 9 and match 21, the player picks one of two options — **Rest** (heal +2 HP) or **Whetstone** (swap one die in the pool).
- **Entity types:** at run start, randomly pick one of three entity types — *Diabolic*, *Cosmic*, *Ethereal*. The entity drives content selection (vignette/event deck, location names, Source skin) but has no mechanical asymmetry yet.
- **Box tier system:** existing 5 boxes are assigned to easy/medium/hard tiers; new boxes designed over time fill out the pools.
- **Source boxes:** match 27 of every run is one of three themed *Source* boxes, one per entity type.
- **UI updates:** match counter shows `Match N / 27`, current act, and current location.
- **Game Bible addition:** a "Run Structure" section is added to `CLAUDE.md` codifying the above.

### Out of Scope (Backlog)

- Cross-run / meta-progression (unlocks between runs)
- Branching paths (player picks which location to go to)
- Dice-vs-entity mechanical asymmetry (Diabolic dice doing more vs Devil entity, etc.)
- Boss-style mechanics on Source matches (different rules, scripted interventions)
- Larger between-act interludes (multiple crossroads scenes, shop hub, etc.)
- More events/vignettes/boxes beyond what the slices require
- Entity art, audio, music

---

## Architecture & File Structure

```
seal-the-box/
  data/
    boxes.csv                     # extended: + tier column (easy/medium/hard); + source_for column (diabolic/cosmic/ethereal/<empty>)
    entities.csv                  # NEW: id, display_name, location_names[], source_box_id, vignette_pool_id, event_pool_id
    vignettes.csv                 # NEW: id, pool_id, text
    events.csv                    # NEW: id, pool_id, prompt, option_a_label, option_a_effect, option_b_label, option_b_effect
  resources/
    box_definition.gd             # extended: tier: String, source_for: String
    entity_data.gd                # NEW: id, display_name, location_names[3], source_box_id, vignette_pool_id, event_pool_id
    vignette_data.gd              # NEW: id, pool_id, text
    event_data.gd                 # NEW: id, pool_id, prompt, option_a/b labels + effects
  scripts/
    globals/
      box_library.gd              # extended: get_by_tier(tier), get_source(entity_id)
      entity_library.gd           # NEW autoload: parses entities.csv → Dict[id → EntityData]
      vignette_library.gd         # NEW autoload: parses vignettes.csv into pools
      event_library.gd            # NEW autoload: parses events.csv into pools
      game_state.gd               # extended: case_match_index (1..27), act (1..3), location_index (1..3), entity_id, run_won
    run/
      case_manager.gd             # NEW: orchestrates the case lifecycle — picks entity, picks boxes per act, drives texture beats, fires crossroads, fires win screen
      texture_roller.gd           # NEW: rolls 50/30/20 between-match beat; resolves vignette or event
      crossroads_controller.gd    # NEW: shows Rest/Whetstone choice and applies result
      run_manager.gd              # extended: defers match selection to CaseManager; handles run-over from CaseManager.run_won signal
    ui/
      match_top_bar.gd            # extended: shows "Match N / 27", act label, location label
      vignette_overlay.gd         # NEW: one-line text overlay with click-to-dismiss
      event_overlay.gd            # NEW: prompt + two buttons (option_a, option_b)
      crossroads_overlay.gd       # NEW: Rest vs Whetstone choice screen
      run_won_overlay.gd          # NEW: win screen — "the entity is sealed", "Begin a new case" button
  scenes/
    run/                          # NEW directory
      case.tscn                   # root scene for a Case (replaces direct match.tscn loading)
    ui/
      vignette_overlay.tscn       # NEW
      event_overlay.tscn          # NEW
      crossroads_overlay.tscn     # NEW
      run_won_overlay.tscn        # NEW
  tests/
    test_case_manager.gd          # headless: 27-match progression, act boundaries, entity selection, source assignment, win on match 27
    test_texture_roller.gd        # headless: 50/30/20 distribution sanity, deck filtering by pool_id
    test_crossroads.gd            # headless: Rest applies +2 HP; Whetstone triggers die swap; choice is one-shot
```

---

## Components

### CaseManager (new)

Owner of the run lifecycle. On run start:

1. Picks one entity at random from EntityLibrary; stores `entity_id` on GameState.
2. Builds the per-act match list:
    - Act 1 (matches 1–9): 9 boxes drawn (with replacement) from the **easy** tier pool.
    - Act 2 (matches 10–21): 12 boxes drawn from the **medium** tier pool.
    - Act 3 (matches 22–27): 6 boxes drawn from the **hard** tier pool, where match 27 is *forced* to be the Source box for the picked entity.
3. Drives the run forward: after each match ends and existing reward beats (rotation, power offer) resolve, asks `TextureRoller` for a between-match beat (silent/vignette/event), shows that overlay, then proceeds.
4. After match 9 and match 21, fires `CrossroadsController` instead of the texture roll.
5. After match 27 wins, fires `RunWonOverlay`.

Exposes signals: `match_started(box_id)`, `act_changed(act_index)`, `crossroads_reached(after_match)`, `run_won()`. RunManager listens to these to drive scene transitions.

### TextureRoller (new)

A small stateless helper that, given the current entity's vignette/event pools, returns one of three results:
- `{type: silent}` (50%)
- `{type: vignette, vignette: VignetteData}` (30%, drawn at random from entity's vignette pool)
- `{type: event, event: EventData}` (20%, drawn at random from entity's event pool)

Probabilities live as module-level constants for easy tuning.

### CrossroadsController (new)

Shows the `CrossroadsOverlay`. Two buttons:
- **Rest** → GameState.hp += 2 (capped at max), close overlay, signal `crossroads_resolved`.
- **Whetstone** → trigger the existing die-swap flow (one offer), then signal `crossroads_resolved`.

The current "every-5-matches die swap" is removed. Whetstone is the only path for swapping dice mid-run.

### EntityLibrary, VignetteLibrary, EventLibrary (new autoloads)

Standard CSV-parser singletons matching the existing `AbilityLibrary` / `BoxLibrary` / `PowerLibrary` pattern. Each has `get_by_id(id)` and `get_pool(pool_id)` accessors.

### BoxDefinition extensions

Two new columns on `boxes.csv`:
- `tier` — one of `easy`, `medium`, `hard`. Existing 5 boxes assigned best-fit during slice 1 (see Open Questions).
- `source_for` — one of `diabolic`, `cosmic`, `ethereal`, or empty. Three new Source boxes added (one per entity); existing boxes have empty value.

### GameState extensions

```
case_match_index: int     # 1..27, increments each match
act: int                  # 1..3, derived from case_match_index
location_index: int       # 1..3, same as act for now
entity_id: String         # set at run start
run_won: bool             # set true when match 27 is sealed
```

`reset_run()` resets all of the above and re-rolls entity. `reset_match()` is unchanged.

### UI changes

- **Top bar:** match counter changes from `Match N` to `Match N / 27`. New labels show current act ("Act II — Investigation") and location name ("Bone Catacombs").
- **Vignette overlay:** opaque background (per Prototyping UI Rule), one-line text centered, click anywhere to dismiss.
- **Event overlay:** opaque background, prompt centered, two buttons below labeled with `option_a_label` and `option_b_label`. Effect string parsed and applied on click.
- **Crossroads overlay:** opaque background, location-transition narration (1–2 sentences from entity's deck), two buttons: Rest / Whetstone.
- **Run-won overlay:** opaque background, "the [entity] is sealed" message, "Begin a new case" button → resets run and returns to first match.

---

## Data Flow

```
Run start
  → CaseManager picks entity (Diabolic/Cosmic/Ethereal)
  → CaseManager pre-builds 27-match list (9 easy + 12 medium + 6 hard, last = Source for entity)

For each match:
  → CaseManager hands box_id to RunManager → match runs as today
  → On match end: existing rewards (rotation pick, power offer if critical) run as today
  → If next match is a crossroads point (after 9 or 21):
      → CrossroadsController shows overlay
      → Player picks Rest or Whetstone
      → Effect applies, overlay closes
  → Else if not the run-end:
      → TextureRoller rolls
      → If silent: nothing
      → If vignette: VignetteOverlay shown over next match's setup
      → If event: EventOverlay shown; player picks option; effect applies
  → If match was 27 and player won: RunWonOverlay shown
  → Else: next match begins

Lose path: HP reaches 0 anywhere → existing run-over flow (unchanged).
Win path: match 27 sealed → RunWonOverlay → "Begin a new case" → reset_run() → new entity rolled, new case begins.
```

---

## Event Effect Strings

Events need a small DSL for their option effects so they're data-driven. Proposed format (one effect per option, parsed by EventOverlay):

| String | Meaning |
|---|---|
| `none` | No effect (used for "Refuse" buttons) |
| `hp+1`, `hp-1`, `hp+2`, `hp-2` | Modify HP (capped at max for +, min 1 for −; HP=0 from − triggers run loss) |
| `max_hp+1` | Increase max HP by 1 (also heals to new max) |
| `charge_random+1` | +1 charge to a random non-null ability in hand |
| `charge_all+1` | +1 charge to every ability in hand |
| `power_random` | Grant a random power |
| `die_swap_offer` | Trigger one die-swap offer |

This list grows as new events are designed. Unknown effect strings log an error and apply nothing.

---

## Win, Lose, Restart

- **Win:** match 27 sealed → RunWonOverlay → "Begin a new case" → full reset (HP, dice pool, ability hand, owned powers, counters all reset to defaults; new entity rolled; case_match_index back to 1).
- **Lose:** HP = 0 → existing run-over overlay → "Begin a new case" → same full reset.
- **No meta-progression in this slice.** Wins and losses are mechanically equivalent for what carries forward (nothing).

---

## Shipping in Slices

The full design is large; this section recommends a split. Each slice is independently shippable and produces a more interesting game.

### Slice 1 — `feature/case-shape`
Replace infinite loop with the 27-match Case structure. No texture, no crossroads yet.
- CaseManager with 9/12/6 act sizing
- Existing 5 boxes assigned to easy/medium/hard tiers (spec calls out best-fit; user confirms during implementation)
- One generic Source for match 27 (any hard-tier box; no entity skinning yet)
- Top bar updated: `Match N / 27`, act number, generic location label ("Location 1")
- Win on match 27 → simple win overlay → reset
- Existing periodic die swap **left alone** in this slice (removed in slice 2)
- Game Bible "Run Structure" section added to CLAUDE.md

**Why first:** smallest change that produces the new shape; everything else hangs off it.

### Slice 2 — `feature/crossroads`
Add between-act choice; remove periodic die swap.
- CrossroadsController, CrossroadsOverlay
- Rest (+2 HP) and Whetstone (existing die-swap flow) options
- Periodic die swap (every 5 matches) removed
- Crossroads fires after match 9 and match 21

**Why second:** depends on Slice 1's act boundaries; replaces a system rather than adding alongside, so cleaner not to bundle.

### Slice 3 — `feature/within-act-texture`
Add the silent/vignette/event roller and the data libraries.
- VignetteData, EventData resources; VignetteLibrary, EventLibrary autoloads
- TextureRoller (50/30/20 distribution)
- VignetteOverlay, EventOverlay UI
- Event effect-string DSL parser
- One small starter pool: ~6 vignettes, ~3 events (entity-agnostic for now)
- Pools are entity-agnostic in this slice (one shared pool used regardless of entity)

**Why third:** needs Slice 1's match-to-match hook; doesn't need entities yet.

### Slice 4 — `feature/entity-types`
Three entity types with distinct content per type.
- EntityData, EntityLibrary
- entities.csv with three rows (Diabolic, Cosmic, Ethereal)
- Vignette and event pools split by entity (3 small decks)
- Entity randomized at run start; location names pulled from entity's list
- Top bar shows entity-themed location names
- Win overlay shows the sealed entity's name

**Why fourth:** texture system needs to exist first; this layers entity selection on top.

### Slice 5 — `feature/source-boxes`
Three themed Source boxes, one per entity, used as match 27.
- Three new boxes added to boxes.csv with `source_for` set
- BoxLibrary.get_source(entity_id) helper
- CaseManager forces match 27 to the matching Source

**Why last:** smallest, cosmetic-but-meaningful capstone — the run finale finally feels distinct.

Slices 1 and 2 together produce the structural change. Slices 3–5 layer texture and theme.

---

## Game Bible Addition (for CLAUDE.md)

Proposed new section, to be added under the existing "Game Bible" header:

```markdown
## Game Bible — Run Structure

- **A run is a Case.** The player tracks a single dark entity across three locations and seals 27 of its manifestations on the way to the Source.
- **Length:** 27 matches per run, fixed. Acts of 9 / 12 / 6 (poetics nod — short setup, long middle, short climax). Total play time ~25–35 minutes for a winning run.
- **Win condition:** seal match 27 (the Source). Lose condition: HP = 0 at any point.
- **No branching paths.** Sequence is linear; variety comes from cadence and content, not navigation.
- **Within-act cadence:** between matches, draw 50% silent / 30% vignette / 20% small event. Math game first; texture appears, doesn't dominate.
- **Between-act crossroads:** after match 9 and match 21, player picks Rest (+2 HP) or Whetstone (swap one die). The only mid-run die-swap path.
- **Box tiers:** each act draws from a difficulty tier — Act 1 easy, Act 2 medium, Act 3 hard. Match 27 is always a Source box themed to the run's entity.
- **Entity:** at run start, randomly pick Diabolic / Cosmic / Ethereal. The entity controls flavor only — vignette/event deck, location names, Source skin. No mechanical asymmetry yet (reserved for future dice-vs-entity work).
- **Theme:** dark, otherworldly, sparse. The unseen player-character is an exorcist-like figure traveling to seal what shouldn't be.
- **No meta-progression yet.** Both wins and losses fully reset.
```

---

## Open Questions (resolve during implementation)

- **Easy/medium/hard tier assignment for current 5 boxes.** Caleb to confirm during Slice 1. Initial proposal:
    - Easy: Classic, Low Evens
    - Medium: Stairs, High Odds
    - Hard: Compressed
  (This leaves Act 1 with 2 boxes to repeat across 9 matches and Act 3 with 1 box for 6 — high repetition. Adding new boxes per tier is acknowledged as follow-up work, not in this design.)
- **Vignette / event content.** Slice 3 ships ~6 vignettes + ~3 events to prove the system; Slice 4 expands to per-entity decks. Final content count is tuning, not design.
- **Win-overlay copy** per entity.

---

## Risks

- **Box repetition during Acts 1 and 3** until more boxes are designed. Mitigation: Slice 1 ships even with high repetition; players will see the structure, content thins are acknowledged. Each follow-up that adds a box improves variety without further structural change.
- **Run length feel.** 27 matches is a guess based on current per-match pacing. If matches average significantly longer or shorter than ~50s in playtest, the act sizing should be revisited (could shrink to 6/8/4 = 18 or grow to 12/15/9 = 36). The 9/12/6 ratio should be preserved.
- **Texture density tuning.** 50/30/20 is a starting point. Slice 3 should expose these as constants in one file so post-playtest tuning is a one-line change.
- **Entity content asymmetry.** Three small decks per entity is more content work than one shared deck. Slice 4 should ship even with shallow per-entity decks (3–4 vignettes each) — depth comes later.
