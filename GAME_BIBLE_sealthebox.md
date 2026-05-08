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

Each **run** is a **27-match Case** divided into three acts (9 easy / 12 medium / 6 hard boxes drawn randomly by tier), for a randomly chosen entity (Diabolic, Cosmic, or Ethereal). The Case ends either by losing all HP or by winning match 27. After **every** match win: player picks 1 of 3 new abilities (mandatory rotation — slot 1 discards, slots shift, pick lands in slot 3). Additionally, critical wins offer a power (Accept to add it to owned_powers, or Skip) before the rotation. Between acts, a Crossroads choice fires (Rest: +2 HP, capped at MAX_HP; or Whetstone: one die swap) — the only way to swap dice mid-run.

---

## Tab System

- A **tab range** is the set of numbers present in the box. Default: [1–9].
- Tab ranges are flexible and can be non-flush (e.g., [1,2,4,7,9]).
- **Win threshold**: explicit per-box value in boxes.csv (tuned for playtesting). Current values: Classic 11, Low Evens 10, High Odds 10, Stairs 9, Compressed 8, boss boxes 11/11/13. Target feel: must seal most tabs to reach threshold; shut the box requires skill or luck.
- **Round limit**: `ceili(tab_sum / 15) + 1`. Current values: all boxes 4 rounds (unchanged from original formula).
- Exceeding the round limit costs 1 HP per extra round until the match ends.
- **Shut the box** = all tabs sealed (sum = 0) → critical win: heals +1 HP (capped at MAX_HP), offers a power (Accept or Skip) + mandatory ability rotation pick.

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

**Power types (implemented):**
| Type | Meaning |
|------|---------|
| Passive | Always-on effect (e.g. Lighter Box, Phoenix Down, Survivor) |
| Match-Start | Fires at the start of round 1 each match (e.g. Eager, Coffee Break) |
| On-Seal | Fires when specific tabs are sealed (no current powers use this type) |
| Critical-Win | Fires on critical wins only (e.g. Box Shutter) |
| Counter | Tracks a specific trigger event; fires when counter reaches its target, then resets to 0. Trigger varies by power: Bonus Seal counts rounds, Tax Collector counts critical wins (target=2), Tab 9 Bounty counts tab-9 seals (target=3), Diabolic Pact counts d12 rolls (target=7), Tab Counter counts tab seals (target=5). Counter initializes to 0 at acquisition and fires after exactly N events. Bonus Seal resets at match end; all other counters persist across matches and reset only on run reset. |

**Power traits (design intent, not all implemented):**
| Trait | Meaning |
|-------|---------|
| SessionReward | Affects the rewards offered after a match |
| FirstRound | Only applies to the first round of a match |

---

## Run Structure

A run is a **Case** — 27 matches across three acts with a boss match closing each act:
- **Matches 1–8:** easy-tier boxes (Classic, Low Evens)
- **Match 9:** boss-tier (act 1 finale — one of the 3 Source boxes, shuffled per run)
- **Matches 10–20:** medium-tier boxes (Stairs, High Odds)
- **Match 21:** boss-tier (act 2 finale)
- **Matches 22–26:** hard-tier boxes (Compressed)
- **Match 27:** boss-tier (run finale / Source)

The 3 boss boxes (the Pact, the Veil, the Anchor) are shuffled at run start — each boss match gets a different one, no repeats. The top bar shows the current match's tier (easy / medium / hard / BOSS).

**Win:** seal match 27. **Lose:** HP reaches 0 at any point.

**Between-act crossroads:** after match 9 (Act 1 end) and match 21 (Act 2 end), player chooses Rest (+2 HP, capped at MAX_HP=6) or Whetstone (one die swap). This is the only way to swap dice mid-run.

**Entity types:** designed but cut for prototyping (2026-05-08). Three entity flavors (Diabolic / Cosmic / Ethereal) will eventually drive vignette/event pool theming and run-won copy. No mechanical asymmetry planned yet.

**Within-act texture:** designed but cut for prototyping (2026-05-08). 50/30/20 silent/vignette/event beat between matches will return once the core difficulty curve is validated.

**Starting setup:** pool = 1d4 + 4d6 + 2d8 (7 dice fixed). Run starts with 1 random ability in slot 3; no starting powers.

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
See `docs/superpowers/specs/2026-05-06-game-flow-design.md` for the Case meta-flow spec and slice breakdown.

| Slice | Branch | Status |
|-------|--------|--------|
| 1 — Case shape (27-match structure, tier boxes, run-won overlay) | feature/case-shape | ✅ Merged |
| 2 — Crossroads (Rest/Whetstone after acts 1 and 2; remove periodic die swap) | feature/crossroads | ✅ Merged |
| 3 — Within-act texture (silent/vignette/event roller, VignetteLibrary, EventLibrary) | feature/within-act-texture | ✅ Merged → ⏸ Cut for prototyping 2026-05-08 |
| 4 — Entity types (Diabolic/Cosmic/Ethereal; per-entity content pools) | feature/entity-types | ✅ Merged → ⏸ Cut for prototyping 2026-05-08 |
| 5 — Source boxes (boss tier; 3 boxes shuffled across matches 9/21/27) | feature/source-boxes | ✅ Merged + redesigned 2026-05-08 |
