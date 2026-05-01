# Map Directory — Seal the Box
*Read this file at the start of every session to orient yourself before touching code.*

## What This Is
A living index of every system in the codebase. Each bucket file documents one system: what it does, where it lives, its public API, and known issues. Keep entries current — stale docs are worse than no docs.

---

## Meta
| Field | Value |
|-------|-------|
| Last groomed | 2026-05-01 |
| Sessions since groom | 0 |
| Groom trigger | 10 sessions |

---

## Bucket Files

| System | File | Status |
|--------|------|--------|
| Game State (autoload) | [game_state.md](game_state.md) | Planned |
| Ability Library (autoload) | [ability_library.md](ability_library.md) | Planned |
| Tab Board | [tab_board.md](tab_board.md) | Planned |
| Dice Pool | [dice_pool.md](dice_pool.md) | Planned |
| Round Manager | [round_manager.md](round_manager.md) | Planned |
| HUD (UI) | [hud.md](hud.md) | Planned |
| Ability Hand (UI) | [ability_hand.md](ability_hand.md) | Planned |
| Dice Hand (UI) | [dice_hand.md](dice_hand.md) | Planned |
| Tab Display (UI) | [tab_display.md](tab_display.md) | Planned |
| Match Scene | [match_scene.md](match_scene.md) | Planned |

---

## System Template
See `docs/system_template.md` for the standard format for new bucket files.

---

## Grooming Notes
- Increment `sessions_since_groom` each session in wrapup.
- When `sessions_since_groom` reaches `groom_trigger`, run `/map-audit`.
- Mark a system **Stale** when its file no longer matches the code; mark **Active** once up to date.
