Build feature/boxes-tab-behavior — Slice 6 of the Box Design Backlog.

CONTEXT

The full design lives at docs/superpowers/specs/2026-05-07-box-design-backlog.md.
Read Axis 2 (Tab Behavior Over Time) before starting. Re-read CLAUDE.md.

This is slice 6 of 7. Adds 9 boxes whose tabs change during play — the
biggest hook-system addition so far. Schedule it after the lighter slices
(2-5) so the registry/dispatcher pattern is mature first.

This slice introduces the "tab tick" hook system that future per-tab
features (Tab Types) will likely reuse. Spend time on the API surface.

BOXES TO ADD (9)

  regrowing, rising_tide, shuffler, clock_tabs, growing_pillars,
  revenant_tabs, fading_decoys, mitosis, moving_targets

KEY ARCHITECTURE QUESTIONS — RESOLVE AT START

  - **Hook timing.** What hooks does this axis need? At minimum:
      * on_round_start (regrowing, shuffler, moving_targets)
      * on_round_end (rising_tide, growing_pillars, clock_tabs)
      * on_seal (mitosis, fading_decoys reveal trigger)
      * on_round_end_no_seal (revenant_tabs)
    These should be discrete dispatch points in RoundManager / TabBoard,
    callable by box-registered handlers.

  - **Tab mutation API.** TabBoard currently treats tabs as a static
    `Array[int]`. Mutating mid-match needs:
      * add_tab(value) — for regrowing, mitosis, revenant_tabs
      * change_tab_value(index, new_value) — for rising_tide, shuffler,
        clock_tabs, moving_targets
      * remove_tab(index) — for fading_decoys vanish
    Each emits a signal so UI can re-render.

  - **Phantom / decoy tabs.** fading_decoys needs tabs flagged as "decoy"
    that don't count toward win threshold. Cleanest: add an `is_decoy`
    property to a Tab data type (rather than the current Array[int]).
    This is a structural change — consider whether to do it here or as
    its own pre-slice. Recommendation: pre-slice if it sprawls.

  - **moving_targets state.** Cycling tab values per round is a per-box
    rule, not a generic API. Implement as a per-round-index lookup in the
    box's behavior handler.

  - **mitosis recursion.** When sealing a tab spawns a half-value tab, the
    spawned tab is itself sealable next round. Halve repeatedly: 12 → 6 → 3
    (sealable) → halved would be 1 → 0 (auto-vanish? fully seal?). Pick a
    rule. Suggested: when a tab would spawn at value < 1, it just seals.

CHANGES (high-level order — pin specifics after architecture session)

1. Decide API surface: single dispatcher with named hook points vs. per-hook
   registries. Probably one dispatcher.
2. Refactor TabBoard tabs from Array[int] to Array[TabData] (or add a
   parallel array of metadata). Required for fading_decoys.
3. Add hook dispatch points in RoundManager: round_start, round_end,
   round_end_no_seal, on_seal.
4. Implement each box's behavior handler. Several reuse the same hook
   (rising_tide and growing_pillars both use round_end +1; one handler with
   parameter `tab_increment` could cover both).
5. Add tests for each behavior.
6. Update UI to react to tab signals (mutation, decoy reveal, etc.).
7. Manual playtest.
8. Update CLAUDE.md.

PROTOTYPING DISCIPLINE

  - For early playtest, ship 2-3 of the 9 boxes first (suggest: regrowing,
    rising_tide, fading_decoys for varied flavors). Validate the hook system
    on those before implementing the rest.
  - mitosis is the most complex; ship it last in the slice.
  - moving_targets UI: just relabel the tabs at round start. No animation.

OUT OF SCOPE

  - Per-tab special types (Tab Types feature — separate)
  - BHV × TOPO composition (multi-board behavior rules — out)

WORKFLOW

  - Branch from master, implement, commit incrementally per box.
  - Mid-slice QA pass: after the first 2-3 boxes, get Caleb to sanity-check
    the hook system before shipping all 9.
  - Final QA, /wrapup.

THE QUESTION THIS SLICE IS TESTING

Does mid-match tab mutation produce strategic depth or chaos?
  - Which 2-3 boxes feel best? Which feel like noise?
  - Does the hook system extend cleanly to Tab Types when that feature lands?
  - Is mitosis fun or frustrating? (Likely the litmus test for whether the
    "high-cognitive-load" boxes belong in the game.)
