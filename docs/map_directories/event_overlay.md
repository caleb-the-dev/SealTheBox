# Event Overlay
*Full-screen opaque overlay that shows a two-choice event prompt. Choosing an option applies mechanical effects and emits resolved.*

## Location
- Script: `scripts/ui/event_overlay.gd` (extends Control)
- Scene: `scenes/ui/event_overlay.tscn` (minimal — just Control + script; all UI built in _ready())
- Instantiated in `match.gd._setup_ui()` via `load("res://scripts/ui/event_overlay.gd").new()`

## Responsibility
Display an event prompt with two choice buttons. When the player picks one, parse and apply the option's effect string, emit `resolved(option)`, then match.gd hides the overlay and advances to the next match.

## Signals
```gdscript
signal resolved(option: String)
    # "a" or "b" — which option the player chose.
    # Emitted AFTER effects have been applied.
```

## Public API
```gdscript
func setup(event) -> void
    # Call before setting visible=true.
    # Sets prompt text and button labels from event (EventData instance, untyped).

static func apply_effects(effect_string: String) -> void
    # Parses a semicolon-separated effect string and applies each effect.
    # Safe to call with "none" or empty string.
    # Static — can be called from tests without instantiating the overlay.
```

## UI Layout
- Anchors: PRESET_FULL_RECT
- Background: `ColorRect` with `Color(0,0,0,1.0)` — fully opaque black
- Content: VBoxContainer anchored 20%–80% width, 30%–75% height, separation=32
  - `_prompt_label`: font_size=22, centered, word-wrapped
  - HBoxContainer (centered, separation=32):
    - `_btn_a`: 160×64, font_size=18 — Option A button
    - `_btn_b`: 160×64, font_size=18 — Option B button
- `mouse_filter = MOUSE_FILTER_STOP` — blocks input below

## Effect-String DSL
Parsed by `apply_effects()` / `_apply_single_effect()`. Semicolons separate multiple effects.

| Effect string | Behavior |
|---------------|----------|
| `none` | No-op |
| `hp+N` | `gs.hp = min(gs.hp + N, GameState.MAX_HP)` |
| `hp-N` | `gs.hp -= N` (clamped to 0; does NOT immediately trigger run-loss — detected on next match-end) |
| `charge_random+1` | +1 charge to a random non-null ability in `GameState.ability_hand` whose charges < max_charges. No-op if all null or all at max. |
| Unknown | `push_error(...)` then skip — no state change |

**Note on hp-N and run-loss:** Setting `gs.hp = 0` via an event effect does NOT immediately fire the run-over overlay. The run-loss path is triggered by `RunManager.handle_match_lost()`, which fires from `RoundManager.match_lost` signal at the end of a round. HP=0 from an event is detected the next time the player loses a round in the following match.

**Stub-only effects** (for future slices): `max_hp+1`, `charge_all+1`, `power_random`, `die_swap_offer` — these will `push_error` if encountered.

## Wiring in match.gd
```gdscript
# Setup and show:
_event_overlay.call("setup", event_data)
_event_overlay.visible = true
_event_overlay.resolved.connect(_on_event_resolved, CONNECT_ONE_SHOT)

# On resolved:
func _on_event_resolved(_option: String) -> void:
    _event_overlay.visible = false
    _refresh_ui()
    _refresh_powers_panel()
    _run_manager.handle_texture_done()
```

## Dependencies
- `GameState` — apply_effects() reads/writes hp, ability_hand (via Engine.get_singleton)

## Gotchas
- **`setup()` param is untyped** (`event` not `event: EventData`) — avoids parse-time class-not-found.
- **Effects applied before `resolved` is emitted** — state changes happen before match.gd sees the signal.
- **`apply_effects` is static** — can be called directly in headless tests without instantiating the scene. Tests do `EventOverlayScript.apply_effects("hp-1")`.
- **HP=0 does NOT immediately end the run** — see hp-N behavior above. If this becomes a bug (player plays at 0 HP for a full match), the run-loss can be wired as an immediate check in match.gd's `_on_event_resolved`.
- **`CONNECT_ONE_SHOT`** prevents double-fire if the overlay is shown twice in succession without cleanup.
- **`_refresh_powers_panel()` is called after resolved** — so any ability charge changes (charge_random+1) are reflected immediately in the UI.

## Recent Changes
| Date | Change |
|------|--------|
| 2026-05-07 | Created (feature/within-act-texture). DSL: none, hp±N, charge_random+1. |
