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
    var draw_count = min(3, _pool.size())
    for i in draw_count:
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
