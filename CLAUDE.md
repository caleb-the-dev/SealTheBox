# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working in this repository.

## Skill Overrides

- **Do NOT use** `superpowers:finishing-a-development-branch`. Use the `/wrapup` skill instead.
- **Do NOT use** `superpowers:writing-plans` when the user's first message is a large, fully-specified feature slice prompt. Instead, read the relevant files, write the plan directly, and proceed immediately to subagent-driven execution. Only invoke `superpowers:writing-plans` for open-ended or ambiguous tasks that genuinely need a planning pass before the spec exists.

## Project Overview

**Seal the Box** is a roguelike puzzle game built in Godot 4. Core loop: roll dice → play ability cards → put down numbered tabs (1–9, Shut the Box style). Win a match by sealing all tabs; survive a run of matches with powers, events, and rewards between fights.

Data lives in CSVs under `seal-the-box/data/`. Game logic lives in GDScript. The Godot project root is `seal-the-box/`.

## Key Godot Executable

```
C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe
```

Set as `$GODOT` or use the full path. All headless commands reference `seal-the-box` as the project path.

## Common Commands

**Import project (required after adding assets):**
```
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path seal-the-box --import
```

**Run a single test scene:**
```
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path seal-the-box res://tests/<test_name>.tscn
```

**Run a headless GDScript test:**
```
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path seal-the-box --script tests/<test_name>.gd
```

## Architecture

```
seal-the-box/
  project.godot
  data/                  # CSV files loaded at runtime (abilities, powers, etc.)
  resources/             # .gd Resource subclasses (AbilityData, PowerData, etc.)
  scripts/
    globals/             # Autoload singletons (GameState, AbilityLibrary, PowerLibrary)
    match/               # Match loop logic (TabBoard, DicePool, RoundManager)
    run/                 # Run-level logic (RunManager, EventManager, RewardManager)
    ui/                  # UI controllers (HUD, AbilityHand, TabDisplay)
  scenes/
    match/               # Match scene and sub-scenes
    run/                 # Map/event scenes
    ui/                  # Shared UI scenes
  tests/                 # Headless test scenes/scripts
```

**Data flow:** CSVs are parsed once at startup by Library autoloads (e.g., `AbilityLibrary`, `PowerLibrary`) into typed Resource objects. Game logic reads from these libraries; it never re-parses CSVs at runtime.

**Globals / Autoloads:**
- `GameState` — current run state (HP, round, tabs, dice pool, ability hand, current box, case_match_index, run_won, act)
- `AbilityLibrary` — all ability definitions indexed by id
- `BoxLibrary` — all box definitions indexed by id; get_ordered() returns CSV row order; get_by_tier(tier) filters by "easy"/"medium"/"hard"
- `CaseManager` — owns the 27-match run sequence; reset_run() builds the list; get_box_for_match(idx) and get_act_for_match(idx) expose it; emits run_won signal

**Match loop:** `RoundManager` orchestrates each round: roll dice pool → player uses free one-time abilities → player assigns dice to seal tabs → check win/lose. A **run** is a 27-match Case (9 easy / 12 medium / 6 hard) orchestrated by `CaseManager`; boxes are drawn randomly by tier each match. Win by sealing match 27; lose by reaching HP = 0.

**Win condition:** `TabBoard.check_win(threshold)` — remaining tab sum ≤ threshold (not sealed sum ≥ threshold).

## Game Vocabulary (from design docs)

| Term | Meaning |
|------|---------|
| Tab | Numbered tile (1–9) to be sealed |
| Dice Pool | Quantity of dice available each round |
| Match | One Shut-the-Box game (core loop) |
| Run | Series of matches + events |
| Power | Persistent run modifier |
| Event | Between-match situation (Shop, Vignette, etc.) |

**Dice traits:** Greater X / Weaker X (add/subtract), x2, Temporary X, Reroll X
**Ability traits:** Repeatable, Preroll, Non-Final, Cooldown X, Expended, Lost
**Types:** Diabolic (high rolls, max HP), Cosmic (low rolls, healing), Ethereal (rerolls, flexible manipulation), Mundane (baseline)

## Game Bible — Dice Pool Rules

- **Pool size: 5–7 dice.** Default starting pool is 5 (3d6 + 1d4 + 1d8). Hard cap at 7.
- **Per-type max** (TBD as dice types are designed; lower than the 7 global cap for some types). Example placeholder: Diabolic max = 6.
- **No acquisition, only swapping.** Players never accumulate new dice. Reward flows offer a die to swap *into* the pool, replacing one currently in it. Pool size never grows organically.
- **Why 5–7:** Pool > 7 produces dead weight without adding decisions. Mixed distributions (small + medium + large faces) outperform uniform pools — varied probability mass across tab values 1–9 is mathematically better than face concentration.

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

## Prototyping UI Rules

- **All overlay backgrounds must be fully opaque** (`Color(0, 0, 0, 1.0)`). No semi-transparency on any overlay during prototyping — it makes text hard to read against the 3D scene behind it.

## Vertical Slice Discipline — READ THIS FIRST

> **Do not add features before playtesting proves they are fun.**

Before suggesting or implementing anything new, ask: *"Is this needed for the current vertical slice to be testable and fun?"* If no, it goes on the backlog.

- **One vertical slice at a time.** Build it, test it, decide what's fun. Only then plan the next.
- **No new features mid-slice.** If a good idea surfaces, note it in a comment or tell Caleb — don't build it.
- **Data-first for variations.** New dice types, abilities, and powers go in CSVs first. Don't hard-code content.
- **Scope creep signals:** adding new game modes, meta-progression layers, UI polish, or "just one more power type" before the core match loop is playtested. Flag these immediately.
- **Push back explicitly.** If Caleb proposes something that adds scope before the current slice is validated, say so directly: "That's a great idea — let's put it on the backlog and come back after we playtest the current slice."

## Current Build State

**Working (committed to master):**
- Full single-match loop playable end-to-end
- **27-match Case structure** (feature/case-shape): infinite loop replaced with 3-act run (Act 1: 9 easy-tier matches, Act 2: 12 medium-tier, Act 3: 6 hard-tier); win on match 27; run-won overlay ("the entity is sealed" + "Begin a new case" button); Crossroads fires after match 9 and match 21: Rest (+2 HP, capped at MAX_HP=6) or Whetstone (one die swap). Periodic die swap removed.
- BoxDefinition Resource + BoxLibrary autoload parse data/boxes.csv (columns: id, name, tabs, win_threshold, tier); BoxLibrary.get_by_tier(tier) added; boxes assigned tiers: Classic/Low Evens=easy, Stairs/High Odds=medium, Compressed=hard
- CaseManager autoload (scripts/run/case_manager.gd): builds 27-match list on reset_run(); exposes get_box_for_match(idx) and get_act_for_match(idx); emits run_won signal via notify_run_won()
- GameState: case_match_index (1..27, synced by RunManager), run_won (bool), act (derived property: 1/2/3), location_index (same as act for now); all reset by reset_run()
- Top bar: "Match N / 27", "Act N", "Location N" labels (placeholder strings, no entity theming yet)
- win_threshold is explicit per-box in CSV (Classic 20, Low Evens 17, High Odds 17); round_limit = ceili(tab_sum/15)+1 (all boxes: 4 rounds before overtime)
- Abilities have charges; 3 fixed slots rotate after every match — slot 1 discarded, slots shift, player picks 1 of 3 new abilities into slot 3; run starts with 1 random ability in slot 3; rolling dice is free (no AP)
- 14 wired abilities in rotation pool: Reroll (2), Empower (3), Weaken (3), Empower II (2), Weaken II (2), Reroll All (1), Auto-Seal Highest (1), Auto-Seal Lowest (2), Multiply x2 (1, no ceiling), Set to Max (2), Set to Min (3), Reroll Lucky (2), Reroll Unlucky (2), Drop Die (2)
- Empower/Empower II refuse to fire if die.value >= die.faces (prevents multiply-then-empower shrink); Drop Die marks die as excluded from totals and sealing (shown as [X])
- Auto-Seal abilities (Highest/Lowest) fire immediately on click, no die targeting; Non-Final (blocked if only 1 tab remains); trigger Tab 9 Bounty + Tab Counter power hooks
- Threshold win: "Continue →" button appears and animates when remaining sum ≤ threshold; player chooses when to advance, then picks a rotation ability
- Critical win (shut the box): auto-ends match, fires 1-of-3 power card selection overlay (highlight + Confirm/Skip), then rotation ability pick
- Powers: 11 powers in data/powers.csv (Lighter Box +1/copy, Eager, Tab 9 Bounty, Bonus Seal, Box Shutter +2/copy, Phoenix Down, Coffee Break, Survivor, Tax Collector, Diabolic Pact, Tab Counter); PowerData resource, PowerLibrary autoload, PowerManager autoload; owned_powers persist across matches within a run; powers stack (multiple copies show count badge in panel)
- Phoenix Down: intercepts run-over, sets HP=1, self-consumes. Coffee Break: round-1 hook charges a random below-max ability (capped at max). Survivor: win-at-exactly-HP=1 heals +1.
- Counter infrastructure: GameState.power_counters Dictionary; PowerManager.add_power() is the single acquisition entry point (initializes counter to 0 on first acquisition). Bonus Seal (target=3): counter ticks each round end, fires on next seal when counter==3, resets to 0 at match end. Tax Collector (target=3): ticks on critical wins, fires +1 HP, persists across matches. Diabolic Pact (target=7): ticks on every d12 roll (commit_roll, reroll abilities, Eager), fires +1 HP, persists. Tab Counter (target=5): ticks per tab sealed (primary + bonus), fires +1 charge to highest-charge ability, persists. Counter display in powers panel: "Name X/Y".
- GameState: hp=6, MAX_HP=6, starting pool=1d4+4d6+2d8 (7 dice), ability_hand=[null, null, random_ability], owned_powers=[], power_counters={}, pending_threshold_bonus=0
- Dev menu (T key or DEV button): scrollable panels; "Win Current Match" (threshold), "Shut the Box (Critical Win)", "Give Power →" submenu (all 11 powers), "Give Ability →" submenu (all 14 pool abilities, fills first empty slot or overwrites slot 3), "Switch Dice →" (mid-match die swap, no match transition), "Win Entire Series", "Restart Run" shortcuts for playtesting
- UI: top bar (HP/Match N of 27/Act N/Location N); tab area with remaining-sum counter + threshold label + Continue button (disabled mid-round); bottom panel split into dice area (2/3) and abilities area (1/3); right-side powers panel (always visible, hover tooltips, stack count badge for duplicates, counter display "Name X/Y" for counter powers); power offer overlay (3-card pick) + rotation overlay + run-over overlay + run-won overlay — all built in code in match.gd
- Within-act texture system (feature/within-act-texture): between matches (excluding crossroads points), TextureRoller draws a beat — 50% silent (nothing shown), 30% vignette (one-line flavor text, click to dismiss), 20% event (prompt + two choices, mechanical effect). Beat fires AFTER rotation/power-offer beats, BEFORE crossroads check. Crossroads points (after match 9 and 21) skip texture.
- VignetteData + EventData resources; VignetteLibrary + EventLibrary autoloads parse data/vignettes.csv and data/events.csv; get_pool(pool_id) returns all entries with that pool_id. 3 vignettes (v_fog, v_bell, v_cold) + 1 event (e_coin: "hp-1;charge_random+1" / "none") in pool_id="default".
- Effect-string DSL parser (EventOverlay.apply_effects): parses semicolons; supports none, hp+N, hp-N (capped at MAX_HP / floored at 0; 0 does NOT immediately fire run-loss — detected on next match-end), charge_random+1 (+1 to random non-null below-max ability). Unknown effects push_error and skip.
- VignetteOverlay + EventOverlay UI (built in code, MOUSE_FILTER_STOP, opaque black bg, instant show/hide). Signal chain: vignette → dismissed → RunManager.handle_texture_done(); event → resolved(option) → RunManager.handle_texture_done().
- TextureRoller is a static-method class (no autoload needed). PROB_SILENT=0.50, PROB_VIGNETTE=0.30 constants for one-line tuning.
- Tests: test_run_manager.gd (46 tests) + test_power_effects.gd (30 tests) + test_ability_library.gd (22 abilities) + test_case_manager.gd (10 tests) + test_crossroads.gd (8 tests) + test_texture_roller.gd (9 tests) pass headless

## Git & GitHub

- Remote: `https://github.com/caleb-the-dev/SealTheBox.git`
- Godot-generated files (`.godot/`, `*.import`, shader caches) belong in `.gitignore`.
- **No git worktrees.** Always work directly in `C:/Users/caleb/.local/bin/Projects/Seal_the_Box/` on a feature branch. Caleb playtests from this fixed path — worktrees break his workflow.

### Feature branch workflow (follow this every time)

1. **Start:** `git checkout master && git checkout -b feature/<name>` — always branch from master
2. **Build:** implement the feature with commits on the branch
3. **QA handoff:** when implementation is done, give Caleb a checklist of what to test (bugs + playability) — he playtests from the same fixed path
4. **Approval:** once Caleb says it's good, wrap up:
   - Push the branch and open a PR to master: `git push -u origin feature/<name>` then `gh pr create`
   - After PR is merged on GitHub, delete the local branch: `git checkout master && git pull && git branch -d feature/<name>`
5. **Update CLAUDE.md:** move the branch entry into "Working" and clear "Next planned feature"
