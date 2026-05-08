# Box Design Backlog
*2026-05-07*

## Premise

The current build cycles through 5 boxes (Classic, Low Evens, High Odds, Compressed, Stairs) that vary tab values within the standard partition mechanic. To drive replayability, we need a substantially larger box pool with structural variety — boxes that change *how* a match plays, not just which numbers are on the board.

This backlog catalogs **48 box designs** across **7 mechanic axes**. Each box is tagged with a primary mechanic domain and overlap-compatibility hints so future designers (including a future Caleb) can compose boxes by layering domains rather than designing each from scratch.

This is a *backlog*, not a single implementable feature. Implementation is split into 7 slice files under `docs/superpowers/slices/` — see "Slice Plan" below.

---

## Prototyping Discipline (READ FIRST)

> Every slice ships as the **simplest thing that proves the box mechanic works and is fun.** Placeholders are encouraged.

- **Tab values, thresholds, and round limits in this doc are starting points.** Playtest, then tune.
- **Implement the cheapest boxes first.** Axis 1 (pure tab composition) is one CSV-only slice; ship that and validate the new box pool feels distinct *before* building the more complex domain hooks.
- **One axis per slice.** Don't bundle a topology box into a tab-behavior slice. Each axis has its own implementation pass; mixing creates risk.
- **Within a slice, ship 1-2 boxes first, playtest, then add the rest.** Don't implement all 14 composition boxes in one go — three rounds of fun-feedback beat one round of bulk work.

---

## Mechanic Domain Taxonomy

Each box is tagged with a primary domain. Domains define what part of the match loop the box modifies. A box can layer with another box from a *different, compatible* domain — but two boxes from the **same domain** conflict (two tab-composition boxes can't co-exist; one defines the tabs).

| Domain | Code | Modifies | Examples |
|--------|------|----------|----------|
| Tab Composition | COMP | Tab values & count | `cluster_of_fours`, `prime_pyramid` |
| Tab Behavior | BHV | How tabs change during play | `regrowing`, `shuffler` |
| Board Topology | TOPO | Multi-board / locking structure | `twin_swap`, `vertical_stack` |
| Dice Access | DICE | Pool size / availability | `single_die`, `locked_d8` |
| Roll Modifiers | ROLL | Die values / roll totals | `heavy_dice`, `halving_box` |
| Win Condition | WIN | Victory rules | `crit_only`, `escalating_threshold` |
| Entry/Persistent | ENTRY | Match-scope buffs/debuffs | `bounty_box`, `cleanse_box` |

### Overlap Compatibility Matrix

`✓` compatible. `⚠` conditional (read note). `✗` conflicts.

|        | COMP | BHV | TOPO | DICE | ROLL | WIN | ENTRY |
|--------|:----:|:---:|:----:|:----:|:----:|:---:|:-----:|
| COMP   |  ✗   |  ✓  |  ⚠¹  |  ✓   |  ✓   |  ✓  |   ✓   |
| BHV    |  ✓   |  ✗  |  ⚠²  |  ✓   |  ✓   |  ✓  |   ✓   |
| TOPO   |  ⚠¹  |  ⚠² |  ✗   |  ✓   |  ✓   |  ⚠³ |   ✓   |
| DICE   |  ✓   |  ✓  |  ✓   |  ✗   |  ⚠⁴  |  ✓  |   ✓   |
| ROLL   |  ✓   |  ✓  |  ✓   |  ⚠⁴  |  ✗   |  ✓  |   ✓   |
| WIN    |  ✓   |  ✓  |  ⚠³  |  ✓   |  ✓   |  ✗  |   ✓   |
| ENTRY  |  ✓   |  ✓  |  ✓   |  ✓   |  ✓   |  ✓  |   ⚠⁵  |

**Notes:**
1. **COMP × TOPO** — only when TOPO doesn't define its own tab values. `vertical_stack` works with any tab spec; `linked_pair` defines its tabs and won't combine.
2. **BHV × TOPO** — single-board BHV rules need explicit per-board adaptation in multi-board topologies. Doable but requires design pass.
3. **TOPO × WIN** — some win conditions assume one board (e.g., `escalating_threshold` over which board?). Multi-board boxes need their own win condition.
4. **DICE × ROLL** — when DICE shrinks the pool, ROLL still applies to whatever rolls. Conceptually compatible, but stack with care — a halved single die is brutal.
5. **ENTRY × ENTRY** — most ENTRY effects don't conflict (a free die loaner + fixed power are fine), but double-resource grants need balance review.

---

## Box Specs

Tabs are written `1;2;3;...` (semicolon-separated, matching boxes.csv). Default tabs `1-9` means `1;2;3;4;5;6;7;8;9` (sum 45). Tier is a difficulty hint — actual placement in run/act tiers is the **Game Flow** feature's concern, not this one.

### Axis 1 — Tab Composition (COMP)

| ID | Name | Tabs | Sum | Tier | Mechanic |
|----|------|------|-----|------|----------|
| `cluster_of_fours` | Cluster of Fours | `4;4;4;4;4;4;4;4;4;4` | 40 | Med | Every legal partition is a multiple of 4. |
| `five_nines` | Five Nines | `9;9;9;9;9` | 45 | Hard | Sub-9 rolls are dead rounds. |
| `high_wall` | High Wall | `5;6;7;8;9;10` | 45 | Hard | No small tabs; mid rolls seal one. |
| `exact_evens` | Exact Evens | `2;4;6;8;10;12` | 42 | Hard | Odd rolls are dead. Parity gate. |
| `lopsided_giant` | Lopsided Giant | `1;1;1;1;1;1;1;9` | 16 | Easy | The 9 is the only puzzle; 1s are flex. |
| `easy_starter` | Easy Starter | `1;2;2;3;3;4;5` | 20 | Easy | Small tabs, max partitions, big dopamine. |
| `triple_triplets` | Triple Triplets | `1;1;1;5;5;5;9;9;9` | 45 | Med | Three difficulty bands; pacing puzzle. |
| `mirror_ladder` | Mirror Ladder | `1;2;3;4;5;5;4;3;2;1` | 30 | Med | Symmetric, doubled smalls give flex. |
| `prime_pyramid` | Prime Pyramid | `2;3;5;7;11;13` | 41 | Hard | 11 and 13 force combos. |
| `crowded_low` | Crowded Low | `1;1;1;1;2;2;2;3;3;3;4;4` | 27 | Easy/Med | Lots of tabs, lots of partitions, satisfying sweep. |
| `the_long_count` | The Long Count | `1;2;3;4;5;6;7;8;9;1;2;3;4;5;6;7;8;9` | 90 | Boss | Endurance Classic, double rounds. |
| `avalanche` | Avalanche | `1;2;3;4;5;6;7;8;9;10;11;12` | 78 | Boss | Extended ladder; upper tabs gate everything. |
| `ten_pillars` | Ten Pillars | `10;10;10;10;10;10` | 60 | Hard | Every seal must be a multiple of 10. |
| `den_of_sevens` | Den of Sevens | `7;7;7;7;7;7;3` | 45 | Hard | Six 7s + one flex 3 for odd-roll outlets. |

**Domain:** all COMP. Compatible with BHV, DICE, ROLL, WIN, ENTRY (per matrix).

### Axis 2 — Tab Behavior Over Time (BHV)

Default tabs unless overridden. Rules fire at defined moments (round start, round end, on-seal, on-miss).

| ID | Name | Tabs | Tier | Rule |
|----|------|------|------|------|
| `regrowing` | Regrowing | `1-9` | Med | Round start: lowest sealed tab returns. |
| `rising_tide` | Rising Tide | `1;2;3;4;5;6;7` | Hard | Round end: every unsealed tab `+1` (ceiling 13). |
| `shuffler` | Shuffler | `1-9` | Med | Round start: every unsealed tab redraws value from 1-9. |
| `clock_tabs` | Clock Tabs | `2;3;4;5;6;7;8;9` | Hard | Round end: one random unsealed tab ticks down by 1; if it hits 0, take 1 HP. |
| `growing_pillars` | Growing Pillars | `2;2;2;2;2;2;2` | Hard | Round end: every unsealed tab `+1` (ceiling 13). Variant of rising_tide. |
| `revenant_tabs` | Revenant Tabs | `1-9` | Med | If you seal nothing in a round, lowest sealed tab returns. |
| `fading_decoys` | Fading Decoys | `1-9` + 3 hidden phantoms (`3;5;7`) | Easy/Med | Phantoms auto-vanish at end of round 2. Player can't tell phantoms from real tabs. **Sealing a phantom does nothing** — no progress, no counter, no threshold effect. After phantoms vanish the game reveals which were decoys. Phantoms don't influence the threshold (set against real tabs only). |
| `mitosis` | Mitosis | `4;6;8;10;12` | Boss | Sealing any tab `≥6` instead spawns a tab of half its value (rounded down). Must grind down to small tabs to actually progress. |
| `moving_targets` | Moving Targets | R1 `1-6`, R2 `2-7`, R3 `3-8`, R4 `4-9` | Boss | Whole tab range shifts up each round. Sum climbs every round. |

**Domain:** all BHV. Compatible with COMP, DICE, ROLL, WIN, ENTRY.

### Axis 3 — Board Topology (TOPO)

| ID | Name | Tabs | Tier | Structure |
|----|------|------|------|-----------|
| `twin_swap` | Twin Swap | A: `1-9`, B: `1-9` | Med | Two boards alternate per round (R1→A, R2→B, R3→A...). Win = both meet threshold. |
| `split_focus` | Split Focus | A: `1-9`, B: `1-9` | Hard | Two boards; each round you pick which receives the roll. Win = both meet threshold. |
| `stacked_layers` | Stacked Layers | Top `1-6`, Bottom `5;6;7;8;9` | Med/Hard | Bottom locked until top fully sealed. |
| `vertical_stack` | Vertical Stack | `1-9` | Med/Hard | Only the lowest 3 unsealed tabs are sealable (sliding window). When 1 seals, 4 unlocks, etc. |
| `escape_box` | Escape Box | A: `1-9`. B: starts empty | Hard | Round end: random `1-9` decoy spawns in B. If B's sum > 15, take 1 HP. Allocate dice to suppress B while clearing A. |
| `linked_pair` | Linked Pair | `1;1;2;2;3;3;4;4;5;5;5;5;6;6;7;7;8;8;9;9` (sum 100) | Easy/Med | Sealing any tab also auto-seals one paired tab (1↔9, 2↔8, 3↔7, 4↔6, 5↔5). |
| `relay_rows` | Relay Rows | Row A: `1-9`, Row B: `1-9` | Med/Hard | Row B's tab N is locked until Row A's tab N seals. Per-tab gating, not per-layer. |

**Domain:** all TOPO. Compatible with DICE, ROLL, ENTRY (with care for WIN and BHV per matrix).

### Axis 4 — Dice Access (DICE)

| ID | Name | Tabs | Tier | Rule |
|----|------|------|------|------|
| `single_die` | Single Die | `1;1;2;3;4;4` | Hard | Roll only 1 die per round. |
| `locked_d8` | Locked d8 | `1-9` | Med | d8s disabled this match (effective pool 1d4+4d6). |
| `locked_d4` | Locked d4 | `1-9` | Med | d4 disabled (effective pool 4d6+2d8 — slightly easier). |
| `bounty_box` | Bounty Box | `2;3;4;5;6;7;8;9;9` | Hard | **Marquee match — appears once per run.** Always grants the same fixed Power on entry (TBD which). |
| `tax_per_roll` | Tax Per Roll | `2;3;4;5;6` | Hard | End of every round after round 1, take 1 HP. Round 1 is free. |
| `forced_full_commit` | Forced Full Commit | `1-9` | Hard | Must commit ALL rolled pips into a partition each round. Unused pips deal damage equal to the leftover. **Flag during impl: confirm this composes with current partition rules.** |

**Domain:** all DICE. Compatible with COMP, BHV, ROLL (with care), WIN, ENTRY.

### Axis 5 — Roll Modifiers (ROLL)

| ID | Name | Tabs | Tier | Rule |
|----|------|------|------|------|
| `heavy_dice` | Heavy Dice | `2;3;4;5;6;7;8;9` | Easy/Med | Every die rolled gets +1 (no cap from die face). 1 tab dropped to keep last-tab seals possible. |
| `weak_dice` | Weak Dice | `1-9` | Hard | Every die rolled gets -1 (floor of 1). |
| `halving_box` | Halving Box | `1;2;3;4;5;6` | Hard | Roll total halved (rounded down). |
| `doubling_box` | Doubling Box | `4;6;8;10;12;14;16` | Med | Roll total doubled. Player-positive but with much larger tabs. |
| `exploding_ones` | Exploding Ones | `1-9` | Easy/Med | A die that shows 1 keeps the 1, then rerolls and **adds** the new value. Chains on consecutive 1s. |
| `pair_swallows` | Pair Swallows | `1-9` | Med | When two dice show the same face, they merge into a single die equal to their sum. |
| `high_die_doubles` | High Die Doubles | `1-9` | Med | The highest die in each roll counts double (no cap; d8 face=8 → contributes 16). |

**Domain:** all ROLL. Compatible with COMP, BHV, TOPO, WIN, ENTRY.

### Axis 7 — Win Condition Twists (WIN)

(Axis 6 archived for future Tab Types feature — see Deferred Features.)

| ID | Name | Tabs | Tier | Rule |
|----|------|------|------|------|
| `crit_only` | Crit Only | `1-9` | Hard | Threshold win disabled. The only way out is shut-the-box (seal everything). |
| `escalating_threshold` | Escalating Threshold | `1-9` | Hard | Threshold drops each round: R1 ≤30, R2 ≤25, R3 ≤20, R4 ≤15. Front-loaded pressure. |

**Domain:** all WIN. Compatible with COMP, BHV, DICE, ROLL, ENTRY.

### Axis 8 — Entry / Persistent Effects (ENTRY)

| ID | Name | Tabs | Tier | Rule |
|----|------|------|------|------|
| `storm_box` | Storm Box | `1;2;3;4;5;6;7;8;9;5` | Med | On entry, pool gains an extra random die for this match only (returns after). |
| `cleanse_box` | Cleanse Box | `3;4;5;6;7;8;9;10;11` | Med/Hard | On entry, all ability charges refill to max. Heavier tabs balance the boost. |
| `borrowed_time` | Borrowed Time | `2;3;4;5;6;7;8;9;9` | Med | On entry, take 1 damage; in exchange, round limit is +1. **Only spawnable when HP ≥ 3** (suicide gate). |

**Domain:** all ENTRY. Compatible with COMP, BHV, DICE, ROLL, WIN. (`bounty_box` from Axis 4 is also fundamentally an ENTRY effect — listed under Axis 4 for the dice/marquee flavor.)

---

## Deferred Features

Ideas that surfaced during this brainstorm but belong in their own future feature passes.

### Tab Types (separate feature)

Per-tab special behaviors. Tab types are *building blocks* that boxes use — a box might be defined as "tabs `1;2;3;4;5` plus one *bleeding tab* worth 7." Brainstorm seeds:

- **Bleeding tab** — sealing it deals 1 self-damage
- **Healing tab** — sealing it heals 1 HP
- **Charge tab** — sealing gives +1 charge to a random ability
- **Threshold tab** (starred) — sealing reduces threshold by 1
- **Golden tab** — sealing grants a free Power offer at match end
- **Payday tab** (e.g., the 9) — sealing grants +1 max HP for the run
- **Required tab** — must be sealed for any victory (overrides threshold)
- **Steal-health tab** — drains 1 HP each round it's unsealed; returns it when sealed
- **Double-seal tab** — must be sealed twice to come down
- **Shut-bonus rule** — critical wins on certain boards grant double rewards (box-level rule, but lives in this feature)

A separate brainstorm session will refine the tab-type catalog, design how tabs are composed into boxes (CSV format, special tab markers), and produce its own slice plan. See "Future Brainstorm Prompt" at the end of this doc.

### Match Objectives / Bonus Rewards (separate feature)

Optional in-match goals that grant bonus rewards on top of the standard win. Brainstorm seeds:

- **Double threshold** — soft threshold for normal win; hard threshold for bonus reward
- **Run-length pattern** — end match with N consecutive sealed tabs for a bonus
- **Parity goal** — seal all odd OR all even tabs for a bonus
- **Set goal** — seal all multiples of 3 (or some other set) for a bonus

This system is its own feature pass — likely a CSV of objective definitions plus a per-match objective selector.

---

## Slice Plan

Each axis becomes its own implementation slice (or a small group of related slices). Slices are listed by recommended implementation order — earliest = cheapest and lowest risk to existing systems.

| Order | Slice File | Axis | Boxes | Why this order |
|------:|-----------|------|------:|----------------|
| 1 | `slice-boxes-1-composition.md` | COMP | 14 | Pure CSV row additions; no new game logic. Validates the new box pool feels distinct before expanding. |
| 2 | `slice-boxes-2-roll-mods.md` | ROLL | 7 | Mostly localized to dice resolution; modest hook surface. |
| 3 | `slice-boxes-3-win-conditions.md` | WIN | 2 | Two boxes only; threshold/crit logic already exists, just needs override hooks. |
| 4 | `slice-boxes-4-dice-access.md` | DICE | 6 | Pool-modifier hooks; affects RoundManager but not board structure. |
| 5 | `slice-boxes-5-entry-effects.md` | ENTRY | 3 | Entry hooks already exist (powers, abilities); extending them is incremental. |
| 6 | `slice-boxes-6-tab-behavior.md` | BHV | 9 | Needs round-start/end/on-seal/on-miss hook system for tab mutation. New infrastructure. |
| 7 | `slice-boxes-7-topology.md` | TOPO | 7 | Biggest refactor — multi-board UI, lock systems, alternating round logic. Last because most invasive. |

Within each slice, ship 1-2 boxes first, playtest, then expand.

---

## Open Questions

- **`bounty_box` fixed power** — which power is always granted? TBD; pick once Powers feature is more mature and we know which would feel marquee.
- **Tier→pool assignments** — how easy/medium/hard/boss tiers feed into the run sequence is the **Game Flow** feature's concern. This doc only tags tier as a hint.
- **`forced_full_commit`** — confirm during implementation that this composes with the existing partition logic without breaking expected UX.
- **`borrowed_time` HP gate** — confirmed as "only spawnable when HP ≥ 3" to prevent suicide encounters. Re-confirm if the user intended the opposite.
- **Per-axis hook architecture** — slices 6 and 7 require new hook systems (round-tick BHV hooks; multi-board TOPO state). The exact API surface should be designed in those slices, not pre-committed here.

---

## Risks

- **Backlog stays a backlog.** 48 boxes is a lot of design; it's tempting to ship them all and discover half don't feel good. Mitigation: each slice is incremental, and individual boxes within a slice can be cut after playtest without affecting siblings.
- **Domain conflicts during runtime composition.** The overlap matrix is a *design-time* tool; runtime safety relies on box CSV being correct. A linting test (`tests/test_box_definitions.gd`) that validates each box's domain tags should ship in slice 1.
- **Tab Types feature collides with existing boxes.** When Tab Types lands, some boxes designed here may become re-expressible as "regular tabs + special tab types." That's fine — those simplifications can refactor later. Don't pre-optimize now.
- **Scope creep within a slice.** It's tempting to bundle "just one BHV box" into the COMP slice. Resist — a single new domain hook costs more design time than 5 more CSV rows.
