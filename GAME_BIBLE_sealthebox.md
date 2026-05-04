# GAME BIBLE — Seal the Box
*High-level design overview — structural reference only*

---

## Working Title
**Seal the Box**

A roguelike puzzle game built around the Shut the Box dice mechanic, layered with ability cards, typed dice, powers, and run progression.

---

## Genre & Platform
- **Genre:** Roguelike Puzzle
- **Platform:** PC
- **Key References:** Shut the Box (core mechanic), Slay the Spire (ability card roguelike), Dicey Dungeons (dice manipulation)

---

## Core Fantasy
Roll your dice, play your cards, and seal the box — round by round, match by match. Build a run of typed dice and powers that synergize into a strategy powerful enough to shut every box you face.

---

## Core Gameplay Loop

**Roll → Seal Tabs → Win Match → (Critical: Collect Rewards) → Next Match**

Each **match** is one game of advanced Shut the Box:
- Tabs (numbered tiles) sit in the box. The goal is to reduce the sum of remaining tabs below the win threshold.
- Each round the player draws a hand of 3 dice from their pool, rolls them, then assigns dice combinations to seal matching tabs.
- Ability cards modify dice values, add rerolls, or grant special effects.
- When remaining sum ≤ win threshold, a "Continue →" button appears. The player chooses when to advance (threshold win — rotation only) or keeps pushing to seal all tabs (critical win — power offer then rotation).
- The run ends only when HP reaches 0.

Each **run** is an infinite loop of matches cycling through boxes (Classic → Low Evens → High Odds → repeat). After **every** match win: player picks 1 of 3 new abilities (mandatory rotation — slot 1 discards, slots shift, pick lands in slot 3). Additionally, critical wins offer a power (Accept to add it to owned_powers, or Skip) before the rotation. Dice are no longer acquired as rewards — the pool is fixed for the run.

---

## Tab System

- A **tab range** is the set of numbers present in the box. Default: [1–9].
- Tab ranges are flexible and can be non-flush (e.g., [1,2,4,7,9]).
- **Win threshold**: explicit per-box value in boxes.csv (tuned for playtesting). Current values: Classic 20, Low Evens 17, High Odds 17. Target feel: threshold achievable most rounds; shut the box requires skill or luck.
- **Round limit**: `ceili(tab_sum / 15) + 1`. Current values: all boxes 4 rounds.
- Exceeding the round limit costs 1 HP per extra round until the match ends.
- **Shut the box** = all tabs sealed (sum = 0) → critical win, offers a power (Accept or Skip) + mandatory ability rotation pick.

---

## Match Structure

Each round has three phases:
1. **Roll phase:** Draw 3 dice from your pool. Select which to roll. All drawn dice are discarded at end of round.
2. **Ability phase:** Play ability cards — modify dice values, reroll, etc.
3. **Seal phase:** Assign rolled dice whose sum equals an unsealed tab to seal it. Runs concurrently with the ability phase.

---

## Dice System

Dice have a **face size** (d4, d6, d8, d10, d12) and a **type** (Diabolic, Cosmic, Ethereal, Mundane).

| Roll (1d6) | Die  | Roll (1d4) | Type     |
|-----------|------|-----------|----------|
| 1         | d4   | 1         | Diabolic |
| 2         | d6   | 2         | Cosmic   |
| 3         | d8   | 3         | Ethereal |
| 4         | d10  | 4         | Mundane  |
| 5         | d12  |           |          |
| 6         | d6   |           |          |

**Dice traits:** Greater X (add X), Weaker X (subtract X), x2, Temporary X (limited rolls), Reroll X (reroll up to X times)

---

## Ability System

Ability cards are played for free. Each card has a type, optional traits, cooldown, and **charges**.

**Charges (implemented):** Each ability has a fixed number of uses (1–3). Charges decrement on use and do NOT reset between matches. When an ability reaches 0 charges it stays in its slot greyed out (dead weight) until rotation discards it. This creates "use it or lose it" pressure.

**Hand structure (implemented):** Fixed 3 slots. Slot 1 = oldest (discards next); Slot 3 = newest (rotation picks land here). Run starts with 1 random ability in slot 3; slots 1 and 2 empty.

**Ability traits (design intent, not all implemented):**
| Trait | Meaning |
|-------|---------|
| Repeatable | Can be used more than once per round |
| Preroll | Must be used before dice are rolled |
| Non-Final | Cannot be used when only one tab remains |
| Cooldown X | Cannot be played again for X rounds after use |
| Expended | Removed from hand for the rest of the match after use |
| Lost | Removed from the deck for the rest of the run after use |

---

## Power System

Powers are persistent run modifiers acquired between matches. They modify core game mechanics throughout the run.

**Power traits:**
| Trait | Meaning |
|-------|---------|
| SessionReward | Affects the rewards offered after a match |
| FirstRound | Only applies to the first round of a match |

---

## Run Structure

1. Player starts a run with a randomly generated dice pool (2d4, 3d6, 1d8 — types random) and starting abilities/powers based on dice type majority.
2. Play a match → win → collect rewards (choose a new die from 3 random options; GP awarded).
3. Shut the box → also collect a power.
4. Repeat with progressively harder tab ranges.
5. HP reaches 0 → run over.

**Starting setup:** most-common dice type → 1 ability + 1 power; second-most-common → 1 ability.

**GP formula:** `(threshold − remaining_sum) × (15 − threshold)` (flush ranges only)

---

## HP System

- Players start with 6 HP.
- Losing a round (exceeding the round limit) costs 1 HP per extra round.
- HP reaching 0 ends the run.
- Some powers and events can heal HP or increase max HP.

---

## Type System

Four types — Diabolic, Cosmic, Ethereal, Mundane — apply to both dice and abilities, enabling synergies:

| Type | Associations |
|------|-------------|
| Diabolic | High roll outcomes, max HP bonuses |
| Cosmic | Low roll outcomes, healing |
| Ethereal | Rerolls, flexible manipulation |
| Mundane | Baseline, generalist |

---

## Vertical Slice Status
See `docs/superpowers/specs/2026-05-01-vertical-slice-design.md` for the current build target.
Current slice: single match, tabs 1–9, hardcoded starting state, no run layer.
