Build feature/boxes-topology — Slice 7 of the Box Design Backlog.

CONTEXT

The full design lives at docs/superpowers/specs/2026-05-07-box-design-backlog.md.
Read Axis 3 (Board Topology) before starting. Re-read CLAUDE.md.

This is slice 7 of 7 — the most invasive. Adds 7 boxes with multi-board,
locking, or sliding-window structures. Likely needs the largest UI/state
refactor of the slice plan. Schedule LAST.

BOXES TO ADD (7)

  twin_swap, split_focus, stacked_layers, vertical_stack, escape_box,
  linked_pair, relay_rows

KEY ARCHITECTURE QUESTIONS — RESOLVE AT START (this is its own design pass)

  - **Multi-board state.** TabBoard currently models one board. Topology
    boxes need 2+ logical boards with shared or split state. Options:
    1. Refactor TabBoard to be multi-instance, with one TabBoard per logical
       board, owned by an enclosing BoardController.
    2. Keep TabBoard as a single physical state but add per-board groupings
       within it.
    Recommendation: option 1. Cleaner long-term, minimal coupling.

  - **Locking system.** stacked_layers, vertical_stack, relay_rows all need
    per-tab "locked" state that prevents seal selection. Add `is_locked`
    flag to TabData (introduced in slice 6) and a per-box lock-resolver
    that runs whenever board state changes (after round, after seal).

  - **Alternating rounds (twin_swap).** Need active-board concept for the
    current round. UI must clearly show which board is in play, with the
    other dimmed.

  - **Per-board win condition.** When does a multi-board box "win"? Most:
    when all boards meet threshold. escape_box: when board A meets threshold
    AND board B's sum ≤ 15.

  - **escape_box decoy spawn.** Reuses fading_decoys' phantom-tab work from
    slice 6, but with active threat instead of trap. Confirm slice 6's
    TabData.is_decoy generalizes to a "spawn into board B" pattern.

  - **Dice-pool partition across boards.** parallel_split was cut as redundant
    with one big board, but split_focus / twin_swap need per-board partition
    flow. UI work: player's die → which board? In split_focus they pre-pick;
    in twin_swap it's determined by round.

  - **Win-condition registry × topology.** TOPO × WIN was flagged as
    conditional in the overlap matrix. Most TOPO boxes need their own
    win-condition handler that already accounts for "which board" — don't
    try to make WIN-domain boxes (`crit_only`, `escalating_threshold`) work
    cleanly with TOPO in this slice.

CHANGES (high-level — pin after architecture pass)

1. Refactor TabBoard / TabDisplay into a BoardController owning multiple
   TabBoard instances. Single-board boxes are "BoardController with one
   TabBoard inside" — backward compatible.
2. Add per-tab is_locked state and a lock-resolver hook system.
3. Add active-board concept for alternating-round topologies.
4. Wire UI to show multiple boards (stacked, side-by-side, or layered as
   the design requires).
5. Implement each topology one at a time, in this order:
     a. linked_pair (single board, just paired-seal logic — easiest)
     b. stacked_layers (single board, simple layer lock)
     c. vertical_stack (single board, sliding window lock)
     d. relay_rows (two boards, per-tab lock)
     e. twin_swap (two boards, alternating)
     f. split_focus (two boards, player chooses)
     g. escape_box (two boards, asymmetric goals — last because most unique)
6. Tests per box.
7. Manual playtest each in isolation.
8. Update CLAUDE.md.

PROTOTYPING DISCIPLINE

  - This slice is huge. Ship 1-2 topologies first (linked_pair + stacked_layers
    suggested) and playtest before continuing. The architecture choices made
    early will lock in the rest of the slice.
  - UI for multi-board is the largest unknown — start with the simplest
    visual layout (two TabBoards stacked vertically with labels) and refine
    only if it's confusing in playtest.
  - escape_box's threat indicator should be a single number ("Trap: 12/15").
    No animation, no escalating UI alarm.

OUT OF SCOPE

  - TOPO × WIN composability (cut from this slice; not necessary for the
    7 designs)
  - 3+ board topologies (all designs are 1-2 boards)
  - Topology + tab-behavior combinations (deferred until both stabilize)

WORKFLOW

  - Branch from master.
  - Architecture pass first — write a sub-spec at
    docs/superpowers/specs/<date>-board-topology-architecture.md before
    coding. Get Caleb's sign-off before implementation.
  - Implement in the staged order above. Mid-slice QA after items (a)-(c).
  - Final QA, /wrapup.

THE QUESTION THIS SLICE IS TESTING

Is multi-board worth the implementation cost?
  - Do 2-3 of the 7 topology boxes feel like "the most interesting boxes
    in the game" — i.e., is the cost justified?
  - Does the multi-board UI scale or feel cramped?
  - Does anything (especially escape_box, mitosis-paired-with-topology)
    expose the limits of the partition mechanic such that a re-frame is
    needed?
