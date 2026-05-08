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

ARCHITECTURE NOTE — READ BEFORE TOUCHING CODE

All overlays in this project are built entirely in code in match.gd's _setup_ui().
There are NO .tscn files for UI overlays. Do NOT create a crossroads_overlay.tscn.
Do NOT create a CrossroadsController class.

The correct pattern (consistent with run_won_overlay, rotation_overlay, etc.):
  1. RunManager gains a new signal and 2 new public methods (crossroads logic lives here).
  2. match.gd builds the crossroads overlay in _setup_ui(), wires RunManager's new
     signal in _connect_signals(), and calls RunManager's methods on button press.

The existing die-swap overlay + flow is KEPT and reused by Whetstone — only the
periodic trigger is removed. See Change 4 for the exact scope.

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

1. Add crossroads logic to RunManager (scripts/run/run_manager.gd):

   a. Add a new signal:
        signal show_crossroads(after_match: int)

   b. In handle_rotation_pick(), REPLACE the existing periodic die-swap block:
        # match_number is already post-incremented here; condition fires after matches 5, 10, 15, ...
        if (match_number - 1) % 5 == 0:
            var offered: Array = []
            for f in DIE_SWAP_FACES:
                offered.append(Die.new(f))
            show_die_swap.emit(offered)
        else:
            _start_next_match()

      WITH the crossroads trigger:
        var completed := match_number - 1   # match_number was already incremented
        if completed == 9 or completed == 21:
            show_crossroads.emit(completed)
        else:
            _start_next_match()

   c. Add two new public methods:
        func handle_crossroads_rest() -> void:
            var gs = Engine.get_singleton("GameState")
            gs.hp = min(gs.hp + 2, GameState.MAX_HP)  # see GameState change below
            _start_next_match()

        func handle_crossroads_whetstone() -> void:
            var offered: Array = []
            for f in DIE_SWAP_FACES:
                offered.append(Die.new(f))
            show_die_swap.emit(offered)
            # _start_next_match() is called by handle_die_swap_confirm or handle_die_swap_skip

   d. Add dev helper for "Win Entire Series":
        func dev_skip_crossroads() -> void:
            handle_crossroads_rest()   # auto-pick Rest in the dev fast-forward path

2. Add MAX_HP to GameState (scripts/globals/game_state.gd):

   Add one line near the top of the file, alongside the ABILITY_POOL_IDS const:
        const MAX_HP := 6

   This is the cap for Rest. It also establishes the field so future powers that
   raise max HP have a clear place to change. Do NOT add max_hp as a var yet — a
   const is sufficient for this slice.

3. Build crossroads overlay in match.gd (scripts/match/match.gd):

   a. Add field to the state block at the top:
        var _crossroads_overlay: Control

   b. In _setup_ui(), build the overlay following the same pattern as
      _run_won_overlay (opaque black, centered VBoxContainer, buttons):
        - Opaque black background (Color(0, 0, 0, 1.0))
        - Header label: "Crossroads" (font_size 30, centered)
        - Subheader label: "Choose your path" (font_size 16, grey, centered — placeholder copy)
        - HBoxContainer with two big buttons (min size 200×100, font_size 20):
            * "Rest"      — subtitle label below: "+2 HP"
            * "Whetstone" — subtitle label below: "swap one die"
          (Use a VBoxContainer per button: label on top, subtitle below, or
           just put both lines in the button text with \n)
        - No skip / cancel button — player must choose one.

   c. In _connect_signals():
        _run_manager.show_crossroads.connect(_on_show_crossroads)

   d. Add handler:
        func _on_show_crossroads(_after_match: int) -> void:
            _crossroads_overlay.visible = true

   e. Add button handlers:
        func _on_crossroads_rest_pressed() -> void:
            _crossroads_overlay.visible = false
            _run_manager.handle_crossroads_rest()

        func _on_crossroads_whetstone_pressed() -> void:
            _crossroads_overlay.visible = false
            _run_manager.handle_crossroads_whetstone()

   f. In _on_next_match_ready(), add to the existing overlay-hide block:
        if _crossroads_overlay:
            _crossroads_overlay.visible = false

   g. Update the dev "Win Entire Series" button handler (_on_dev_win_series_pressed):
      Add a call to dev_skip_crossroads() in the loop alongside dev_skip_rotation(),
      so the fast-forward path doesn't stall at act boundaries:
        _run_manager.dev_skip_rotation()
        _run_manager.dev_skip_crossroads()   # no-ops unless crossroads is pending

      NOTE: dev_skip_crossroads() calls handle_crossroads_rest() which calls
      _start_next_match() directly — make sure the loop guard (_match_ended check)
      still works correctly after this change.

4. Remove ONLY the periodic die-swap trigger — keep everything else:

   REMOVE from RunManager.handle_rotation_pick():
     - The `if (match_number - 1) % 5 == 0` block and its `else: _start_next_match()`
       (this is fully replaced by change 1b above)

   KEEP (Whetstone reuses all of these):
     - `const DIE_SWAP_FACES`
     - `signal show_die_swap`
     - `handle_die_swap_confirm()`
     - `handle_die_swap_skip()`
     - The die swap overlay in match.gd (_die_swap_overlay, _on_show_die_swap, etc.)
     - The "Switch Dice →" dev menu button (still useful for testing mid-match)

   Nothing in GameState needs removal — there is no die-swap counter or flag there.

5. Tests — create tests/test_crossroads.gd (new file, headless pattern):

   Follow the pattern from tests/test_run_manager.gd. Register: AbilityLibrary,
   BoxLibrary, PowerLibrary, GameState, PowerManager, CaseManager.

   Cover:
     - show_crossroads fires after match 9 (not at match 5, not at match 10).
     - show_crossroads fires after match 21 (not at match 20, not at match 22).
     - show_crossroads does NOT fire after matches 1–8, 10–20, 22–26.
     - handle_crossroads_rest() adds +2 HP, capped at MAX_HP (6).
     - handle_crossroads_rest() at HP == MAX_HP: no change.
     - handle_crossroads_whetstone() emits show_die_swap exactly once.
     - After handle_die_swap_skip(), _start_next_match() fires (next_match_ready emitted).
     - Periodic die swap (every 5 matches) no longer fires anywhere in a run —
       advance 10 matches and confirm show_die_swap was never emitted except via
       Whetstone.

6. Update CLAUDE.md "Current Build State":
     - Replace "die swap offered every 5 matches" bullet with:
       "Crossroads fires after match 9 and match 21: Rest (+2 HP, capped at
       MAX_HP=6) or Whetstone (one die swap). Periodic die swap removed."
     - Add GameState.MAX_HP = 6 to the GameState bullet.

PROTOTYPING DISCIPLINE (re-emphasized — see spec section)

  - "Crossroads" as a header is fine — no per-act themed copy yet.
  - Plain button labels with one-line subtitles.
  - No animations, no transitions, instant overlay show/hide.
  - Reuse the existing run-won / power-offer overlay structure as a starting
    point — same opaque background, same button style.

OUT OF SCOPE (explicitly — slices 3–5 and beyond)

  - Reliquary, Provisions, Press On (and any other crossroads options beyond
    Rest / Whetstone) — deferred from the spec menu intentionally
  - Themed transition narration ("you travel three days through the moor...")
    — slice 3 territory, when text content infrastructure exists
  - Vignettes / events / texture roller (slice 3)
  - Entity types and entity-themed crossroads copy (slice 4)
  - Source boxes (slice 5)
  - Dynamic max_hp (any power that increases max HP — deferred; const is fine for now)

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
