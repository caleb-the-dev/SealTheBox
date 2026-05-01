# Vertical Slice Design — Single Match
*2026-05-01*

## Scope & Boundaries

### In Scope
- Single match, tabs 1–9 (hardcoded)
- Win threshold: 13 (highest tab 9 × 1.5, floored)
- Round limit: 4 (highest tab 9 × 0.5, floored)
- HP: 5; each round beyond the limit costs 1 HP; HP 0 = match lost
- Critical win: all tabs sealed (sum = 0) — distinct win message, no reward yet
- 3 AP per round; rolling a die costs 1 AP
- Dice hand: 3 random dice drawn from pool each round, discarded at end of round
- Starting pool: 3× d6, 1× d8 (hardcoded, no type system)
- Starting ability hand: 3 cards — Reroll any die (1 AP, Repeatable), Apply Greater 1 (1 AP), Apply Lesser 1 (1 AP)
- AbilityLibrary parses abilities.csv at startup; starting hand is hardcoded IDs from that library

### Out of Scope (Backlog)
- Run layer, rewards, GP, relic on shut, random starting pool generation, dice/ability type system, events, shop, art/polish

---

## Architecture & File Structure

```
seal-the-box/
  project.godot
  data/
    abilities.csv              # parsed by AbilityLibrary at startup
  resources/
    ability_data.gd            # Resource: id, name, ap_cost, traits[], description
  scripts/
    globals/
      ability_library.gd       # Autoload: parses abilities.csv → Dict[id → AbilityData]
      game_state.gd            # Autoload: hp, ap, tabs[], dice_pool[], hand[], round, round_limit
    match/
      tab_board.gd             # seal_tab(n), get_remaining(), get_sum(), check_win()
      dice_pool.gd             # pool[], hand[], draw_hand(), roll_selected(), apply_modifier()
      round_manager.gd         # phase transitions; signals: phase_changed, round_ended, match_won, match_lost
    ui/
      hud.gd                   # AP / HP / round counters, status label
      ability_hand.gd          # renders ability cards, handles clicks
      tab_display.gd           # renders 9 tab buttons, handles dice-sum-to-tab assignment
      dice_hand.gd             # renders drawn dice, handles selection and roll
  scenes/
    match/
      match.tscn               # root match scene
  tests/
    test_match_logic.gd        # headless: win/lose detection, tab sealing, AP math
```

**Key constraints:**
- `RoundManager` owns all phase transitions; emits signals — UI nodes never call each other directly
- `GameState` is the single source of truth; logic scripts mutate it, UI reads it
- `AbilityLibrary` parses CSV once at `_ready()` — never re-parsed at runtime

---

## Match Loop & Mechanics

### Round Flow
1. `RoundManager` starts round: reset AP to 3, draw 3 random dice from pool into hand
2. **Phase 1 (Roll):** Player selects dice from hand → clicks Roll. Each selected die costs 1 AP. Dice display their rolled values. Unrolled dice in hand show face size only.
3. **Phase 2/3 (Act):** Player can in any order:
   - Click an ability card (AP ≥ cost) → target a die → effect applied immediately
   - Select rolled dice whose values sum to an unsealed tab → click Seal → tab sealed
   - Repeat until AP exhausted or player clicks End Round
4. **End of round:** Discard all 3 dice. If `round > round_limit` → HP −1; if `hp == 0` → match lost. Advance to next round.

**Win check runs immediately after every seal**, not just at end of round. If `remaining_sum ≤ 13` at any point → match won immediately (no need to click End Round).

### Dice Mechanics
- `apply_greater(die, x)`: `die.value += x`, clamped to die face max
- `apply_lesser(die, x)`: `die.value -= x`, clamped to 1
- `reroll(die)`: randomise `die.value` within `[1, die.faces]`
- Pool reshuffles (all discards returned) when fewer than 3 dice remain undrawn

### Tab Sealing
- Player selects 1–N rolled dice; UI shows their running sum in real time
- Seal button activates only when sum matches an unsealed tab exactly
- Sealed tab is removed from board permanently

### Win / Lose
| Condition | Result |
|-----------|--------|
| `remaining_sum ≤ 13` at end of round | Match won |
| `remaining_sum == 0` | Critical win (all tabs sealed) |
| `hp == 0` | Match lost |

---

## Scene Structure

```
match.tscn
  Node3D (root)
    Camera3D
    DirectionalLight3D
    MeshInstance3D         # flat table surface — placeholder
    CanvasLayer
      HUD                  # AP / HP / Round counters
      TabDisplay           # 9 tab buttons (sealed = dimmed)
      DiceHand             # 3 drawn dice cards; select → roll
      AbilityHand          # ability card buttons; dimmed when AP insufficient
      EndRoundButton
      StatusLabel
      WinLoseDialog        # popup on match end
```

**Rationale for 3D root:** future 3D dice with physics drop into the Node3D world. The CanvasLayer UI remains unchanged — `DiceHand` switches from showing values itself to displaying results from the 3D dice objects.

---

## UI Layout

```
[ HP: 5 ]          [ Round: 1 / 4 ]          [ AP: 3 ]

[ Tab Board ]
  [ 1 ] [ 2 ] [ 3 ] [ 4 ] [ 5 ] [ 6 ] [ 7 ] [ 8 ] [ 9 ]

[ Dice Hand ]  — drawn fresh each round, discarded at end
  [ d6 ] [ d8 ] [ d6 ]
  [ Roll Selected (1 AP each) ]

[ Ability Hand ]
  [ Reroll Die — 1 AP ]  [ Greater 1 — 1 AP ]  [ Lesser 1 — 1 AP ]

                        [ End Round ]

[ Status: "Round 2 — sum remaining: 18" ]
```

Visual states (no art — color/dim only):
- Sealed tabs: dimmed, non-interactive
- Selected dice: highlighted
- Ability cards with insufficient AP: dimmed
- Rolled dice: show numeric value; unrolled show face size

---

## Testing

`tests/test_match_logic.gd` — headless GDScript, covers:
- Tab sealing: valid and invalid sums
- Win detection: threshold boundary (sum 13 = win, sum 14 = not)
- Critical win: sum 0
- AP deduction on roll and ability use
- HP drain after round limit exceeded
- Dice pool reshuffle when pool exhausted
