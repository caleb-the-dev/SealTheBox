# Vignette Overlay
*Full-screen opaque overlay that shows a one-line flavor text vignette. Click anywhere to dismiss.*

## Location
- Script: `scripts/ui/vignette_overlay.gd` (extends Control)
- Scene: `scenes/ui/vignette_overlay.tscn` (minimal — just Control + script; all UI built in _ready())
- Instantiated in `match.gd._setup_ui()` via `load("res://scripts/ui/vignette_overlay.gd").new()`

## Responsibility
Display a single-line vignette text over the game screen. Emit `dismissed` when the player clicks. No game state changes — pure display.

## Signals
```gdscript
signal dismissed    # emitted when player clicks anywhere on the overlay; no arguments
```

## Public API
```gdscript
func setup(vignette) -> void
    # Call before setting visible=true.
    # Sets _text_label.text = vignette.text.
    # vignette is a VignetteData instance (untyped to avoid class-not-found issues at parse time).
```

## UI Layout
- Anchors: PRESET_FULL_RECT (covers entire viewport)
- Background: `ColorRect` with `Color(0,0,0,1.0)` — fully opaque black (Prototyping UI Rule)
- Content: VBoxContainer anchored 20%–80% width, 40%–70% height
  - `_text_label`: font_size=24, centered, word-wrapped
  - Hint label: "[ click anywhere to continue ]", font_size=14, grey (Color 0.6 0.6 0.6)
- `mouse_filter = MOUSE_FILTER_STOP` — blocks all input to elements below

## Dismiss Mechanism
`_gui_input()` checks for `InputEventMouseButton` (left button, pressed). On match: emits `dismissed`. match.gd connects with `CONNECT_ONE_SHOT` — the connection auto-disconnects after one fire.

## Wiring in match.gd
```gdscript
# Setup and show:
_vignette_overlay.call("setup", vignette_data)
_vignette_overlay.visible = true
_vignette_overlay.dismissed.connect(_on_vignette_dismissed, CONNECT_ONE_SHOT)

# On dismissed:
func _on_vignette_dismissed() -> void:
    _vignette_overlay.visible = false
    _refresh_ui()
    _run_manager.handle_texture_done()
```

## Dependencies
- None at runtime (receives a VignetteData dict key, reads `.text` from it)
- match.gd owns it and wires it

## Gotchas
- **`setup()` param is untyped** (`vignette` not `vignette: VignetteData`) — avoids parse-time class-not-found in headless contexts. Access only `.text` from it.
- **No auto-dismiss timer** — player must click. This is intentional per the slice 3 design question being tested.
- **Hidden in `_on_next_match_ready()`** as a safeguard even though normal flow always dismisses it before next match starts.
- **`CONNECT_ONE_SHOT`** prevents the signal from double-firing if the overlay is somehow shown twice in a row without cleanup.

## Recent Changes
| Date | Change |
|------|--------|
| 2026-05-07 | Created (feature/within-act-texture). |
