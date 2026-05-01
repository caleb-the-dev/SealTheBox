# Match Scene
*Root scene for a single match. Wires all systems together.*

## Location
`scenes/match/match.tscn` / `scripts/match/round_manager.gd` (scene controller)

## Scene Tree
```
match.tscn
  Node3D (root)
    Camera3D
    DirectionalLight3D
    MeshInstance3D          # flat table surface — placeholder
    CanvasLayer
      HUD
      TabDisplay
      DiceHand
      AbilityHand
      EndRoundButton
      StatusLabel
      WinLoseDialog         # popup on match end
```

## Responsibility
Entry point for a match. Instantiates and connects all UI nodes to RoundManager signals. Starts the match on _ready().
The Node3D root exists to support future 3D dice physics — UI lives entirely in the CanvasLayer.

## Dependencies
All match systems: RoundManager, TabBoard, DicePool, GameState, AbilityLibrary, all UI nodes.

## Known Issues / TODOs
- [ ] Implement (not yet built)
- [ ] 3D table mesh is placeholder — replace with art asset

## Last Updated
2026-05-01
