# Vertical Slice — Single Match Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a fully playable single match of Seal the Box in Godot 4 — roll dice, use ability cards, seal tabs 1–9, win or lose.

**Architecture:** Logic-first. Pure GDScript classes (TabBoard, DicePool, Die) are built and tested headlessly before the scene exists. RoundManager owns all phase transitions and emits signals; a single match.gd script creates all UI nodes in code (no complex .tscn authoring). The scene root is Node3D to support future 3D dice physics.

**Tech Stack:** Godot 4.5, GDScript, headless test runner (`--script`), CSV via `FileAccess.get_csv_line()`

---

## File Map

| File | Purpose |
|------|---------|
| `seal-the-box/project.godot` | Godot project config; registers autoloads, sets main scene |
| `seal-the-box/data/abilities.csv` | Ability definitions with `id` column |
| `seal-the-box/resources/ability_data.gd` | `class_name AbilityData extends Resource` |
| `seal-the-box/scripts/globals/ability_library.gd` | Autoload: parses CSV → `Dict[id → AbilityData]` |
| `seal-the-box/scripts/globals/game_state.gd` | Autoload: hp, ap, round, tabs, dice_pool, dice_hand, ability_hand |
| `seal-the-box/scripts/match/die.gd` | `class_name Die extends RefCounted` |
| `seal-the-box/scripts/match/tab_board.gd` | `class_name TabBoard extends RefCounted` — pure tab logic |
| `seal-the-box/scripts/match/dice_pool.gd` | `class_name DicePool extends RefCounted` — draw/roll/discard |
| `seal-the-box/scripts/match/round_manager.gd` | `extends Node` — phase orchestration, all signals |
| `seal-the-box/scripts/match/match.gd` | `extends Node3D` — builds 3D env + all UI in code |
| `seal-the-box/scenes/match/match.tscn` | Minimal scene: Node3D root + match.gd script only |
| `seal-the-box/tests/test_match_logic.gd` | Headless tests: TabBoard, DicePool, AP math |

---

## Task 1: Godot Project Scaffold

**Files:**
- Create: `seal-the-box/project.godot`
- Create: `seal-the-box/data/.gitkeep`
- Create: `seal-the-box/resources/.gitkeep`
- Create: `seal-the-box/scripts/globals/.gitkeep`
- Create: `seal-the-box/scripts/match/.gitkeep`
- Create: `seal-the-box/scenes/match/.gitkeep`
- Create: `seal-the-box/tests/.gitkeep`

- [ ] **Step 1: Create all directories**

```powershell
mkdir seal-the-box\data, seal-the-box\resources, seal-the-box\scripts\globals, seal-the-box\scripts\match, seal-the-box\scenes\match, seal-the-box\tests
```

- [ ] **Step 2: Write `seal-the-box/project.godot`**

```ini
; Engine configuration file.
; It's best edited using the editor UI and not directly,
; but the file format allows for manual editing.

config_version=5

[application]

config/name="Seal the Box"
config/features=PackedStringArray("4.5", "Forward Plus")
config/run/main_scene="res://scenes/match/match.tscn"

[autoload]

AbilityLibrary="*res://scripts/globals/ability_library.gd"
GameState="*res://scripts/globals/game_state.gd"
```

- [ ] **Step 3: Verify Godot can import the project**

Run:
```
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path seal-the-box --import
```
Expected: no errors, exits cleanly (may print import messages — that's fine).

- [ ] **Step 4: Commit**

```
git add seal-the-box/
git commit -m "feat: scaffold Godot project structure"
```

---

## Task 2: Die Class

**Files:**
- Create: `seal-the-box/scripts/match/die.gd`

- [ ] **Step 1: Write `seal-the-box/scripts/match/die.gd`**

```gdscript
class_name Die
extends RefCounted

var faces: int
var value: int = 0
var rolled: bool = false

func _init(f: int) -> void:
    faces = f

func roll() -> int:
    value = randi_range(1, faces)
    rolled = true
    return value
```

- [ ] **Step 2: Commit**

```
git add seal-the-box/scripts/match/die.gd
git commit -m "feat: add Die class"
```

---

## Task 3: AbilityData Resource + abilities.csv

**Files:**
- Create: `seal-the-box/resources/ability_data.gd`
- Create: `seal-the-box/data/abilities.csv`

- [ ] **Step 1: Write `seal-the-box/resources/ability_data.gd`**

```gdscript
class_name AbilityData
extends Resource

@export var id: String = ""
@export var flavor_name: String = ""
@export var type: String = ""
@export var traits: Array[String] = []
@export var cooldown: int = 0
@export var ap_cost: int = 1
@export var description: String = ""
```

- [ ] **Step 2: Write `seal-the-box/data/abilities.csv`**

```csv
id,flavor_name,type,traits,cooldown,ap_cost,description
reroll_die,Ethereal Card,Ethereal,Repeatable,0,1,Reroll any die
greater_1,Mundane Card,Mundane,,0,1,Apply greater 1 to any die
lesser_1,Cosmic Card,Cosmic,,0,1,Apply lesser 1 to any die
roll_d4,Mundane Card,Mundane,,0,1,Roll 1 mundane d4
lesser_greater_1,Mundane Card,Mundane,,0,2,Apply lesser 1 or greater 1 to any die
cosmic_coin,Cosmic Card,Cosmic,,0,1,Flip a cosmic coin (1d2)
lesser_2_cosmic,Cosmic Card,Cosmic,Preroll,0,1,Apply lesser 2 to any 1 cosmic die
roll_d20,Diabolic Card,Diabolic,,0,2,Roll 1 diabolic d20
greater_2_diabolic,Diabolic Card,Diabolic,,1,2,Apply greater 2 to any 1 diabolic die
x2_diabolic,Diabolic Card,Diabolic,Preroll,1,1,Apply x2 to any 1 diabolic die
greater_1_diabolic,Diabolic Card,Diabolic,,0,1,Apply greater 1 to any 1 diabolic die
put_down_highest,Diabolic Card,Diabolic,Non-Final,0,2,Put down the highest tab
```

- [ ] **Step 3: Commit**

```
git add seal-the-box/resources/ability_data.gd seal-the-box/data/abilities.csv
git commit -m "feat: add AbilityData resource and abilities.csv"
```

---

## Task 4: AbilityLibrary Autoload + Test

**Files:**
- Create: `seal-the-box/scripts/globals/ability_library.gd`
- Create: `seal-the-box/tests/test_ability_library.gd`

- [ ] **Step 1: Write the failing test `seal-the-box/tests/test_ability_library.gd`**

```gdscript
extends SceneTree

func _init() -> void:
    # AbilityLibrary is an autoload — available via the global name
    assert(AbilityLibrary != null, "AbilityLibrary autoload must exist")
    
    var reroll = AbilityLibrary.get_ability("reroll_die")
    assert(reroll != null, "reroll_die must be in library")
    assert(reroll.ap_cost == 1, "reroll_die ap_cost should be 1")
    assert("Repeatable" in reroll.traits, "reroll_die should have Repeatable trait")
    
    var greater = AbilityLibrary.get_ability("greater_1")
    assert(greater != null, "greater_1 must be in library")
    assert(greater.ap_cost == 1, "greater_1 ap_cost should be 1")
    
    var missing = AbilityLibrary.get_ability("does_not_exist")
    assert(missing == null, "Missing ability should return null")
    
    var all = AbilityLibrary.get_all()
    assert(all.size() >= 3, "Library should have at least 3 abilities")
    
    print("AbilityLibrary tests passed!")
    quit()
```

- [ ] **Step 2: Run test to confirm it fails (AbilityLibrary not yet implemented)**

```
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path seal-the-box --script tests/test_ability_library.gd
```
Expected: error about AbilityLibrary not found or assertion failure.

- [ ] **Step 3: Write `seal-the-box/scripts/globals/ability_library.gd`**

```gdscript
extends Node

var _abilities: Dictionary = {}

func _ready() -> void:
    _load_csv()

func _load_csv() -> void:
    var file = FileAccess.open("res://data/abilities.csv", FileAccess.READ)
    if not file:
        push_error("AbilityLibrary: cannot open res://data/abilities.csv")
        return
    var headers = file.get_csv_line()  # skip header row
    while not file.eof_reached():
        var row = file.get_csv_line()
        if row.size() < 7 or row[0].strip_edges().is_empty():
            continue
        var data = AbilityData.new()
        data.id = row[0].strip_edges()
        data.flavor_name = row[1].strip_edges()
        data.type = row[2].strip_edges()
        var traits_raw = row[3].strip_edges()
        data.traits = traits_raw.split(",", false) if traits_raw != "" else []
        data.cooldown = int(row[4])
        data.ap_cost = int(row[5])
        data.description = row[6].strip_edges()
        _abilities[data.id] = data
    file.close()

func get_ability(id: String) -> AbilityData:
    return _abilities.get(id, null)

func get_all() -> Array:
    return _abilities.values()
```

- [ ] **Step 4: Run the import step so Godot registers the new autoload**

```
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path seal-the-box --import
```

- [ ] **Step 5: Run test to confirm it passes**

```
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path seal-the-box --script tests/test_ability_library.gd
```
Expected: `AbilityLibrary tests passed!` then clean exit.

- [ ] **Step 6: Commit**

```
git add seal-the-box/scripts/globals/ability_library.gd seal-the-box/tests/test_ability_library.gd
git commit -m "feat: add AbilityLibrary autoload with CSV parsing"
```

---

## Task 5: GameState Autoload

**Files:**
- Create: `seal-the-box/scripts/globals/game_state.gd`

No separate test file — GameState is exercised via the match logic tests in Task 7.

- [ ] **Step 1: Write `seal-the-box/scripts/globals/game_state.gd`**

```gdscript
extends Node

var hp: int = 5
var ap: int = 3
var round: int = 0
var round_limit: int = 4
var win_threshold: int = 13
var tabs: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9]
var dice_pool: Array = []   # Array of Die
var dice_hand: Array = []   # Array of Die (currently drawn)
var ability_hand: Array = []  # Array of AbilityData

func reset_match() -> void:
    hp = 5
    ap = 3
    round = 0
    tabs = [1, 2, 3, 4, 5, 6, 7, 8, 9]
    _setup_dice_pool()
    _setup_ability_hand()

func spend_ap(amount: int) -> bool:
    if ap < amount:
        return false
    ap -= amount
    return true

func _setup_dice_pool() -> void:
    dice_pool = []
    for i in 3:
        dice_pool.append(Die.new(6))
    dice_pool.append(Die.new(8))

func _setup_ability_hand() -> void:
    ability_hand = []
    for id in ["reroll_die", "greater_1", "lesser_1"]:
        var ability = AbilityLibrary.get_ability(id)
        if ability:
            ability_hand.append(ability)
        else:
            push_error("GameState: ability not found: %s" % id)
```

- [ ] **Step 2: Re-import project**

```
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path seal-the-box --import
```

- [ ] **Step 3: Commit**

```
git add seal-the-box/scripts/globals/game_state.gd
git commit -m "feat: add GameState autoload"
```

---

## Task 6: TabBoard + Tests

**Files:**
- Create: `seal-the-box/scripts/match/tab_board.gd`
- Create: `seal-the-box/tests/test_tab_board.gd`

- [ ] **Step 1: Write the failing test `seal-the-box/tests/test_tab_board.gd`**

```gdscript
extends SceneTree

func _init() -> void:
    _test_initial_state()
    _test_seal_tab()
    _test_win_condition()
    _test_critical_win()
    _test_can_seal()
    print("TabBoard tests passed!")
    quit()

func _test_initial_state() -> void:
    var board = TabBoard.new()
    board.reset([1, 2, 3, 4, 5, 6, 7, 8, 9])
    assert(board.get_sum() == 45, "Initial sum should be 45, got %d" % board.get_sum())
    assert(board.get_remaining().size() == 9, "Should have 9 tabs")

func _test_seal_tab() -> void:
    var board = TabBoard.new()
    board.reset([1, 2, 3, 4, 5, 6, 7, 8, 9])
    board.seal_tab(5)
    assert(not 5 in board.get_remaining(), "Tab 5 should be sealed")
    assert(board.get_sum() == 40, "Sum after sealing 5 should be 40, got %d" % board.get_sum())
    assert(board.get_remaining().size() == 8, "Should have 8 tabs remaining")

func _test_win_condition() -> void:
    var board = TabBoard.new()
    board.reset([1, 2, 3, 4, 5, 6, 7, 8, 9])
    # Seal everything except 1,2,3 (sum=6) — below threshold 13
    for tab in [4, 5, 6, 7, 8, 9]:
        board.seal_tab(tab)
    assert(board.check_win(13), "Sum 6 should satisfy threshold 13")
    assert(not board.check_win(5), "Sum 6 should NOT satisfy threshold 5")
    assert(not board.check_critical_win(), "Tabs still remain, not critical win")
    # Threshold boundary: sum exactly 13 = win
    var board2 = TabBoard.new()
    board2.reset([4, 9])  # sum = 13
    assert(board2.check_win(13), "Sum exactly 13 should be a win (<=)")
    # sum 14 = not win
    var board3 = TabBoard.new()
    board3.reset([5, 9])  # sum = 14
    assert(not board3.check_win(13), "Sum 14 should NOT satisfy threshold 13")

func _test_critical_win() -> void:
    var board = TabBoard.new()
    board.reset([1, 2, 3])
    board.seal_tab(1)
    board.seal_tab(2)
    board.seal_tab(3)
    assert(board.check_critical_win(), "All tabs sealed = critical win")
    assert(board.check_win(0), "Critical win also satisfies threshold 0")

func _test_can_seal() -> void:
    var board = TabBoard.new()
    board.reset([1, 2, 3, 4, 5, 6, 7, 8, 9])
    assert(board.can_seal([5], 5), "Single die 5 seals tab 5")
    assert(board.can_seal([3, 2], 5), "3+2=5 seals tab 5")
    assert(board.can_seal([1, 2, 3], 6), "1+2+3=6 seals tab 6")
    assert(not board.can_seal([3, 1], 5), "3+1=4 does not seal tab 5")
    assert(not board.can_seal([3, 2], 10), "Tab 10 not in range")
    board.seal_tab(5)
    assert(not board.can_seal([5], 5), "Cannot seal already-sealed tab 5")
```

- [ ] **Step 2: Run test to confirm it fails**

```
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path seal-the-box --script tests/test_tab_board.gd
```
Expected: error — `TabBoard` class not defined.

- [ ] **Step 3: Write `seal-the-box/scripts/match/tab_board.gd`**

```gdscript
class_name TabBoard
extends RefCounted

var _remaining: Array[int] = []

func reset(tab_range: Array[int]) -> void:
    _remaining = tab_range.duplicate()

func seal_tab(value: int) -> void:
    _remaining.erase(value)

func get_remaining() -> Array[int]:
    return _remaining.duplicate()

func get_sum() -> int:
    var total: int = 0
    for t in _remaining:
        total += t
    return total

func check_win(threshold: int) -> bool:
    return get_sum() <= threshold

func check_critical_win() -> bool:
    return _remaining.is_empty()

func can_seal(dice_values: Array[int], tab: int) -> bool:
    if not tab in _remaining:
        return false
    var total: int = 0
    for v in dice_values:
        total += v
    return total == tab
```

- [ ] **Step 4: Run test to confirm it passes**

```
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path seal-the-box --script tests/test_tab_board.gd
```
Expected: `TabBoard tests passed!`

- [ ] **Step 5: Commit**

```
git add seal-the-box/scripts/match/tab_board.gd seal-the-box/tests/test_tab_board.gd
git commit -m "feat: add TabBoard with TDD"
```

---

## Task 7: DicePool + Tests

**Files:**
- Create: `seal-the-box/scripts/match/dice_pool.gd`
- Create: `seal-the-box/tests/test_dice_pool.gd`

- [ ] **Step 1: Write the failing test `seal-the-box/tests/test_dice_pool.gd`**

```gdscript
extends SceneTree

func _init() -> void:
    _test_draw_hand()
    _test_roll()
    _test_modifiers()
    _test_discard_and_reshuffle()
    _test_ap_spend()
    print("DicePool + AP tests passed!")
    quit()

func _test_draw_hand() -> void:
    var pool = DicePool.new()
    pool.setup([Die.new(6), Die.new(6), Die.new(6), Die.new(8)])
    var hand = pool.draw_hand()
    assert(hand.size() == 3, "Hand should have 3 dice, got %d" % hand.size())
    for die in hand:
        assert(die.faces in [6, 8], "Die face should be 6 or 8")

func _test_roll() -> void:
    var pool = DicePool.new()
    pool.setup([Die.new(6), Die.new(6), Die.new(6), Die.new(8)])
    var hand = pool.draw_hand()
    var die = hand[0]
    assert(not die.rolled, "Die should not be rolled yet")
    var val = pool.roll_die(die)
    assert(die.rolled, "Die should be marked rolled")
    assert(val >= 1 and val <= die.faces, "Rolled value %d out of range [1,%d]" % [val, die.faces])
    assert(die.value == val, "die.value should match returned value")

func _test_modifiers() -> void:
    var pool = DicePool.new()
    pool.setup([Die.new(6)])
    var hand = pool.draw_hand()
    var die = hand[0]
    die.value = 4
    die.rolled = true
    pool.apply_greater(die, 1)
    assert(die.value == 5, "Greater 1: 4+1=5, got %d" % die.value)
    pool.apply_greater(die, 10)
    assert(die.value == 6, "Greater capped at face max 6, got %d" % die.value)
    pool.apply_lesser(die, 2)
    assert(die.value == 4, "Lesser 2: 6-2=4, got %d" % die.value)
    die.value = 1
    pool.apply_lesser(die, 5)
    assert(die.value == 1, "Lesser capped at 1, got %d" % die.value)
    # Reroll stays in range
    for i in 20:
        pool.reroll(die)
        assert(die.value >= 1 and die.value <= die.faces, "Reroll out of range: %d" % die.value)

func _test_discard_and_reshuffle() -> void:
    var pool = DicePool.new()
    pool.setup([Die.new(6), Die.new(6), Die.new(6), Die.new(8)])
    var hand = pool.draw_hand()
    assert(pool.get_hand().size() == 3, "Hand size 3 after draw")
    pool.discard_hand()
    assert(pool.get_hand().size() == 0, "Hand cleared after discard")
    # Pool had 4 dice, drew 3, 1 remains. Drawing again should reshuffle and succeed.
    var hand2 = pool.draw_hand()
    assert(hand2.size() == 3, "After reshuffle, draw 3 again")

func _test_ap_spend() -> void:
    GameState.ap = 3
    assert(GameState.spend_ap(1), "Should spend 1 AP from 3")
    assert(GameState.ap == 2, "AP should be 2 after spending 1")
    assert(GameState.spend_ap(2), "Should spend 2 AP from 2")
    assert(GameState.ap == 0, "AP should be 0 after spending 2")
    assert(not GameState.spend_ap(1), "Should fail to spend 1 AP from 0")
    assert(GameState.ap == 0, "AP unchanged on failed spend")
```

- [ ] **Step 2: Run test to confirm it fails**

```
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path seal-the-box --script tests/test_dice_pool.gd
```
Expected: error — `DicePool` class not defined.

- [ ] **Step 3: Write `seal-the-box/scripts/match/dice_pool.gd`**

```gdscript
class_name DicePool
extends RefCounted

var _pool: Array = []    # undrawn Die objects
var _discard: Array = [] # discarded this round
var _hand: Array = []    # currently in hand

func setup(pool_config: Array) -> void:
    _pool = pool_config.duplicate()
    _discard = []
    _hand = []

func draw_hand() -> Array:
    if _pool.size() < 3:
        _reshuffle()
    _hand = []
    for i in 3:
        var idx = randi() % _pool.size()
        _hand.append(_pool[idx])
        _pool.remove_at(idx)
    return _hand

func roll_die(die: Die) -> int:
    return die.roll()

func apply_greater(die: Die, x: int) -> void:
    die.value = min(die.value + x, die.faces)

func apply_lesser(die: Die, x: int) -> void:
    die.value = max(die.value - x, 1)

func reroll(die: Die) -> int:
    die.rolled = false
    return die.roll()

func discard_hand() -> void:
    for die in _hand:
        die.value = 0
        die.rolled = false
        _discard.append(die)
    _hand = []

func get_hand() -> Array:
    return _hand

func _reshuffle() -> void:
    _pool.append_array(_discard)
    _discard = []
```

- [ ] **Step 4: Run test to confirm it passes**

```
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path seal-the-box --script tests/test_dice_pool.gd
```
Expected: `DicePool + AP tests passed!`

- [ ] **Step 5: Commit**

```
git add seal-the-box/scripts/match/dice_pool.gd seal-the-box/tests/test_dice_pool.gd
git commit -m "feat: add DicePool with TDD"
```

---

## Task 8: RoundManager

**Files:**
- Create: `seal-the-box/scripts/match/round_manager.gd`

RoundManager is tested via the playable scene (Task 9) rather than headlessly — it depends on signals and the full node tree.

- [ ] **Step 1: Write `seal-the-box/scripts/match/round_manager.gd`**

```gdscript
extends Node

signal phase_changed(phase: String)
signal round_ended(round_num: int)
signal match_won(critical: bool)
signal match_lost()
signal tab_sealed(value: int)
signal status_updated(text: String)

var _tab_board: TabBoard
var _dice_pool: DicePool
var _current_phase: String = ""

func _ready() -> void:
    _tab_board = TabBoard.new()
    _dice_pool = DicePool.new()

func start_match() -> void:
    GameState.reset_match()
    _tab_board.reset(GameState.tabs.duplicate())
    _dice_pool.setup(GameState.dice_pool.duplicate())
    start_round()

func start_round() -> void:
    GameState.round += 1
    GameState.ap = 3
    var hand = _dice_pool.draw_hand()
    GameState.dice_hand = hand
    _set_phase("roll")
    status_updated.emit("Round %d of %d — select dice to roll (1 AP each)" % [GameState.round, GameState.round_limit])

func commit_roll(dice: Array) -> void:
    for die in dice:
        if not GameState.spend_ap(1):
            status_updated.emit("Not enough AP to roll all selected dice!")
            break
        _dice_pool.roll_die(die)
    _set_phase("act")
    status_updated.emit("Round %d — seal tabs or use abilities" % GameState.round)

func attempt_seal(dice: Array, tab: int) -> bool:
    var values: Array[int] = []
    for d in dice:
        values.append(d.value)
    if not _tab_board.can_seal(values, tab):
        return false
    _tab_board.seal_tab(tab)
    GameState.tabs = _tab_board.get_remaining()
    tab_sealed.emit(tab)
    _check_win()
    return true

func use_ability(ability: AbilityData, target_die: Die) -> bool:
    if not GameState.spend_ap(ability.ap_cost):
        status_updated.emit("Not enough AP for %s!" % ability.flavor_name)
        return false
    match ability.id:
        "reroll_die":
            _dice_pool.reroll(target_die)
        "greater_1":
            _dice_pool.apply_greater(target_die, 1)
        "lesser_1":
            _dice_pool.apply_lesser(target_die, 1)
        _:
            push_warning("RoundManager: unhandled ability id: %s" % ability.id)
            GameState.ap += ability.ap_cost  # refund
            return false
    return true

func end_round() -> void:
    _dice_pool.discard_hand()
    GameState.dice_hand = []
    if GameState.round > GameState.round_limit:
        GameState.hp -= 1
        status_updated.emit("Round limit exceeded! HP: %d" % GameState.hp)
        if GameState.hp <= 0:
            match_lost.emit()
            return
    round_ended.emit(GameState.round)
    start_round()

func _check_win() -> void:
    if _tab_board.check_critical_win():
        match_won.emit(true)
    elif _tab_board.check_win(GameState.win_threshold):
        match_won.emit(false)

func _set_phase(phase: String) -> void:
    _current_phase = phase
    phase_changed.emit(phase)
```

- [ ] **Step 2: Commit**

```
git add seal-the-box/scripts/match/round_manager.gd
git commit -m "feat: add RoundManager"
```

---

## Task 9: Match Scene

**Files:**
- Create: `seal-the-box/scenes/match/match.tscn`
- Create: `seal-the-box/scripts/match/match.gd`

- [ ] **Step 1: Write `seal-the-box/scenes/match/match.tscn`**

This is a minimal scene file — all UI is created in code by match.gd.

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/match/match.gd" id="1_match"]

[node name="Match" type="Node3D"]
script = ExtResource("1_match")
```

- [ ] **Step 2: Write `seal-the-box/scripts/match/match.gd`**

```gdscript
extends Node3D

# ── state ──────────────────────────────────────────────────────────────────
var _round_manager: RoundManager
var _selected_dice: Array = []
var _selected_ability: AbilityData = null
var _targeting_die: bool = false

# ── ui references ───────────────────────────────────────────────────────────
var _hp_label: Label
var _ap_label: Label
var _round_label: Label
var _status_label: Label
var _tab_buttons: Array[Button] = []
var _dice_buttons: Array[Button] = []
var _ability_buttons: Array[Button] = []
var _roll_button: Button
var _end_round_button: Button

# ── lifecycle ───────────────────────────────────────────────────────────────
func _ready() -> void:
    _setup_3d()
    _setup_ui()
    _round_manager = RoundManager.new()
    add_child(_round_manager)
    _connect_signals()
    _round_manager.start_match()

# ── 3D environment ──────────────────────────────────────────────────────────
func _setup_3d() -> void:
    var cam = Camera3D.new()
    cam.position = Vector3(0, 5, 8)
    cam.rotation_degrees = Vector3(-25, 0, 0)
    add_child(cam)

    var light = DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-45, 45, 0)
    add_child(light)

    var table = MeshInstance3D.new()
    var mesh = PlaneMesh.new()
    mesh.size = Vector2(12, 10)
    table.mesh = mesh
    add_child(table)

# ── UI construction ─────────────────────────────────────────────────────────
func _setup_ui() -> void:
    var canvas = CanvasLayer.new()
    add_child(canvas)

    var vbox = VBoxContainer.new()
    vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
    vbox.add_theme_constant_override("separation", 10)
    canvas.add_child(vbox)

    # Top bar: HP | Round | AP
    var top = HBoxContainer.new()
    top.alignment = BoxContainer.ALIGNMENT_CENTER
    top.add_theme_constant_override("separation", 30)
    vbox.add_child(top)

    _hp_label = Label.new()
    top.add_child(_hp_label)
    _round_label = Label.new()
    top.add_child(_round_label)
    _ap_label = Label.new()
    top.add_child(_ap_label)

    # Tab board
    _add_section_label(vbox, "── TABS ──")
    var tab_row = HBoxContainer.new()
    tab_row.alignment = BoxContainer.ALIGNMENT_CENTER
    tab_row.add_theme_constant_override("separation", 6)
    vbox.add_child(tab_row)

    for i in range(1, 10):
        var btn = Button.new()
        btn.text = str(i)
        btn.custom_minimum_size = Vector2(52, 52)
        btn.pressed.connect(_on_tab_pressed.bind(i))
        tab_row.add_child(btn)
        _tab_buttons.append(btn)

    # Dice hand
    _add_section_label(vbox, "── DICE HAND ──")
    var dice_row = HBoxContainer.new()
    dice_row.alignment = BoxContainer.ALIGNMENT_CENTER
    dice_row.add_theme_constant_override("separation", 10)
    vbox.add_child(dice_row)

    for i in 3:
        var btn = Button.new()
        btn.text = "d?"
        btn.custom_minimum_size = Vector2(64, 64)
        btn.pressed.connect(_on_die_pressed.bind(i))
        dice_row.add_child(btn)
        _dice_buttons.append(btn)

    _roll_button = Button.new()
    _roll_button.text = "Roll Selected  (1 AP each)"
    _roll_button.pressed.connect(_on_roll_pressed)
    vbox.add_child(_roll_button)

    # Ability hand
    _add_section_label(vbox, "── ABILITIES ──")
    var ability_row = HBoxContainer.new()
    ability_row.alignment = BoxContainer.ALIGNMENT_CENTER
    ability_row.add_theme_constant_override("separation", 10)
    vbox.add_child(ability_row)

    for i in 3:
        var btn = Button.new()
        btn.custom_minimum_size = Vector2(140, 52)
        btn.pressed.connect(_on_ability_pressed.bind(i))
        ability_row.add_child(btn)
        _ability_buttons.append(btn)

    # End round + status
    _end_round_button = Button.new()
    _end_round_button.text = "End Round"
    _end_round_button.pressed.connect(_on_end_round_pressed)
    vbox.add_child(_end_round_button)

    _status_label = Label.new()
    _status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _status_label.custom_minimum_size = Vector2(400, 0)
    vbox.add_child(_status_label)

func _add_section_label(parent: VBoxContainer, text: String) -> void:
    var lbl = Label.new()
    lbl.text = text
    lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    parent.add_child(lbl)

# ── signal wiring ────────────────────────────────────────────────────────────
func _connect_signals() -> void:
    _round_manager.phase_changed.connect(_on_phase_changed)
    _round_manager.round_ended.connect(_on_round_ended)
    _round_manager.match_won.connect(_on_match_won)
    _round_manager.match_lost.connect(_on_match_lost)
    _round_manager.tab_sealed.connect(_on_tab_sealed)
    _round_manager.status_updated.connect(_on_status_updated)

# ── signal handlers ──────────────────────────────────────────────────────────
func _on_phase_changed(phase: String) -> void:
    _roll_button.disabled = (phase != "roll")
    _end_round_button.disabled = (phase == "roll")
    _refresh_ui()

func _on_round_ended(_round_num: int) -> void:
    _selected_dice = []
    _selected_ability = null
    _targeting_die = false
    _refresh_ui()

func _on_match_won(critical: bool) -> void:
    var msg = "SHUT THE BOX!\nCritical Win!" if critical else "Match Won!\nSum dropped below threshold."
    _show_end_dialog(msg)

func _on_match_lost() -> void:
    _show_end_dialog("Match Lost\nHP reached 0.")

func _on_tab_sealed(value: int) -> void:
    var btn = _tab_buttons[value - 1]
    btn.disabled = true
    btn.modulate = Color(0.4, 0.4, 0.4)
    _selected_dice = []
    _refresh_dice_highlight()
    _refresh_ui()

func _on_status_updated(text: String) -> void:
    _status_label.text = text

# ── input handlers ───────────────────────────────────────────────────────────
func _on_die_pressed(index: int) -> void:
    var hand = GameState.dice_hand
    if index >= hand.size():
        return
    var die = hand[index]

    if _targeting_die and _selected_ability != null:
        _round_manager.use_ability(_selected_ability, die)
        _selected_ability = null
        _targeting_die = false
        _refresh_ui()
        return

    if die in _selected_dice:
        _selected_dice.erase(die)
    else:
        _selected_dice.append(die)
    _refresh_dice_highlight()
    _update_sum_status()

func _on_tab_pressed(tab_value: int) -> void:
    var rolled = _selected_dice.filter(func(d): return d.rolled)
    if rolled.is_empty():
        _status_label.text = "Select rolled dice first, then a tab to seal."
        return
    if not _round_manager.attempt_seal(rolled, tab_value):
        var sum = 0
        for d in rolled:
            sum += d.value
        _status_label.text = "Can't seal tab %d with sum %d." % [tab_value, sum]

func _on_roll_pressed() -> void:
    var to_roll = _selected_dice.filter(func(d): return not d.rolled)
    if to_roll.is_empty():
        _status_label.text = "Select unrolled dice to roll."
        return
    _round_manager.commit_roll(to_roll)
    _selected_dice = []

func _on_ability_pressed(index: int) -> void:
    if index >= GameState.ability_hand.size():
        return
    var ability = GameState.ability_hand[index]
    if GameState.ap < ability.ap_cost:
        _status_label.text = "Not enough AP for %s." % ability.flavor_name
        return
    _selected_ability = ability
    _targeting_die = true
    _status_label.text = "%s — click a die to target it." % ability.description

func _on_end_round_pressed() -> void:
    _selected_dice = []
    _selected_ability = null
    _targeting_die = false
    _round_manager.end_round()

# ── ui refresh ───────────────────────────────────────────────────────────────
func _refresh_ui() -> void:
    _hp_label.text = "HP: %d" % GameState.hp
    _ap_label.text = "AP: %d" % GameState.ap
    _round_label.text = "Round: %d / %d" % [GameState.round, GameState.round_limit]
    _refresh_dice_display()
    _refresh_ability_display()

func _refresh_dice_display() -> void:
    var hand = GameState.dice_hand
    for i in 3:
        var btn = _dice_buttons[i]
        if i < hand.size():
            var die = hand[i]
            btn.text = str(die.value) if die.rolled else "d%d" % die.faces
            btn.disabled = false
        else:
            btn.text = "—"
            btn.disabled = true

func _refresh_dice_highlight() -> void:
    var hand = GameState.dice_hand
    for i in hand.size():
        if i < _dice_buttons.size():
            _dice_buttons[i].modulate = Color(1.5, 1.5, 0.3) if hand[i] in _selected_dice else Color.WHITE

func _refresh_ability_display() -> void:
    var hand = GameState.ability_hand
    for i in 3:
        var btn = _ability_buttons[i]
        if i < hand.size():
            var a = hand[i]
            btn.text = "%s\n%d AP" % [a.flavor_name, a.ap_cost]
            btn.disabled = (GameState.ap < a.ap_cost)
        else:
            btn.text = "—"
            btn.disabled = true

func _update_sum_status() -> void:
    var rolled_selected = _selected_dice.filter(func(d): return d.rolled)
    if rolled_selected.is_empty():
        return
    var total = 0
    for d in rolled_selected:
        total += d.value
    _status_label.text = "Selected dice sum: %d" % total

func _show_end_dialog(message: String) -> void:
    _end_round_button.disabled = true
    _roll_button.disabled = true
    for btn in _tab_buttons + _dice_buttons + _ability_buttons:
        btn.disabled = true
    var dialog = AcceptDialog.new()
    dialog.dialog_text = message
    dialog.title = "Match Over"
    add_child(dialog)
    dialog.popup_centered()
```

- [ ] **Step 3: Re-import project**

```
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path seal-the-box --import
```

Expected: clean import, no errors.

- [ ] **Step 4: Commit**

```
git add seal-the-box/scenes/match/match.tscn seal-the-box/scripts/match/match.gd
git commit -m "feat: add match scene with full UI built in code"
```

---

## Task 10: Run All Tests + Manual Smoke Check

- [ ] **Step 1: Run AbilityLibrary test**

```
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path seal-the-box --script tests/test_ability_library.gd
```
Expected: `AbilityLibrary tests passed!`

- [ ] **Step 2: Run TabBoard test**

```
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path seal-the-box --script tests/test_tab_board.gd
```
Expected: `TabBoard tests passed!`

- [ ] **Step 3: Run DicePool + AP test**

```
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path seal-the-box --script tests/test_dice_pool.gd
```
Expected: `DicePool + AP tests passed!`

- [ ] **Step 4: Launch the game to manually verify the match is playable**

```
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --path seal-the-box
```

Verify manually:
- [ ] Tabs 1–9 visible, HP/AP/Round shown correctly
- [ ] Three dice appear in the hand each round (labelled d6/d8)
- [ ] Selecting dice and clicking Roll costs AP and shows numeric values
- [ ] Selecting rolled dice shows their sum in the status label
- [ ] Clicking a tab seals it when the selected dice sum matches
- [ ] Ability cards (Reroll, Greater 1, Lesser 1) work: click card, then click a die
- [ ] End Round advances to next round; HP drains after round 4
- [ ] Win dialog appears when remaining sum ≤ 13
- [ ] Lose dialog appears when HP hits 0

- [ ] **Step 5: Final commit**

```
git add .
git commit -m "feat: vertical slice complete — single match playable"
git push origin master
```
