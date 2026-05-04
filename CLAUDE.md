# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working in this repository.

## Project Overview

**Seal the Box** is a roguelike puzzle game built in Godot 4. Core loop: roll dice → spend AP to play ability cards → put down numbered tabs (1–9, Shut the Box style). Win a match by sealing all tabs; survive a run of matches with powers, events, and rewards between fights.

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
- `GameState` — current run state (HP, AP, round, tabs, dice pool, ability hand, current box)
- `AbilityLibrary` — all ability definitions indexed by id
- `BoxLibrary` — all box definitions indexed by id; get_ordered() returns CSV row order

**Match loop:** `RoundManager` orchestrates each round: roll dice pool → player uses free one-time abilities → player assigns dice to seal tabs → check win/lose. A **run** is 3 sequential matches across 3 different boxes (tab sets), each with its own tabs/round_limit/win_threshold loaded from BoxDefinition.

**Win condition:** `TabBoard.check_win(threshold)` — remaining tab sum ≤ threshold (not sealed sum ≥ threshold).

## Game Vocabulary (from design docs)

| Term | Meaning |
|------|---------|
| Tab | Numbered tile (1–9) to be sealed |
| Dice Pool | Quantity of dice available each round |
| AP | Action Points — currency for ability cards |
| Match | One Shut-the-Box game (core loop) |
| Run | Series of matches + events |
| Power | Persistent run modifier |
| Event | Between-match situation (Shop, Vignette, etc.) |

**Dice traits:** Greater X / Weaker X (add/subtract), x2, Temporary X, Reroll X
**Ability traits:** Repeatable, Preroll, Non-Final, Cooldown X, Expended, Lost
**Types:** Diabolic (high rolls, max HP), Cosmic (low rolls, healing), Ethereal (rerolls, flexible manipulation), Mundane (baseline)

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
- Infinite match loop: Classic → Low Evens → High Odds → repeat; run ends only at HP = 0
- BoxDefinition Resource + BoxLibrary autoload parse data/boxes.csv (columns: id, name, tabs, win_threshold)
- win_threshold is explicit per-box in CSV (Classic 20, Low Evens 17, High Odds 17); round_limit = ceili(tab_sum/15)+1 (all boxes: 4 rounds before overtime)
- Abilities (Reroll, Empower, Weaken, Empower II, Weaken II, Reroll All) are free one-time use, persist across the entire run
- Threshold win: "Continue →" button appears and animates once when remaining sum ≤ threshold; player chooses when to advance (no reward)
- Critical win (shut the box): auto-ends match, fires dice reward (pick 1 of 3 from [d2,d4,d6,d8,d10,d12]) + ability offer (swap or skip)
- GameState: hp=6, starting pool=3d6+1d4+1d8, ability_hand=[reroll_die, greater_1, lesser_1]
- Dev menu (T key or DEV button): "Win Current Match" and "Win Entire Series" shortcuts for playtesting
- UI: top bar (Round/HP/Match/Box), tab area with remaining-sum counter + threshold label + Continue button, dice hand, abilities, reward/ability-offer/over overlays — all built in code in match.gd
- Tests: test_run_manager.gd (11 tests) + test_box_definition.gd pass headless

## Git & GitHub

- Remote: `https://github.com/caleb-the-dev/SealTheBox.git`
- Godot-generated files (`.godot/`, `*.import`, shader caches) belong in `.gitignore`.
- **No git worktrees.** Always work directly in `C:/Users/caleb/.local/bin/Projects/Seal_the_Box/` on a feature branch. Caleb playtests from this fixed path — worktrees break his workflow.

### Feature branch workflow (follow this every time)

1. **Start:** `git checkout master && git checkout -b feature/<name>` — always branch from master
2. **Build:** implement the feature with commits on the branch
3. **QA handoff:** when implementation is done, give Caleb a checklist of what to test (bugs + playability) — he playtests from the same fixed path
4. **Approval:** once Caleb says it's good, wrap up:
   - `git checkout master && git merge feature/<name> && git branch -d feature/<name>`
   - `git push origin master`
5. **Update CLAUDE.md:** move the branch entry into "Working" and clear "Next planned feature"
