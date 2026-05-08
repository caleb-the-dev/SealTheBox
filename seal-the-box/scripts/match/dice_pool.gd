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
    if _pool.size() < 2:
        _reshuffle()
    if _pool.is_empty():
        push_warning("DicePool: draw_hand called on empty pool+discard — returning empty hand")
        _hand = []
        return _hand
    _hand = []
    var draw_count = min(2, _pool.size())
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
        die.dropped = false
        _discard.append(die)
    _hand = []

func get_hand() -> Array:
    return _hand

func get_draw_count() -> int:
    return _pool.size()

func get_discard_count() -> int:
    return _discard.size()

func apply_multiply(die: Die, factor: int) -> void:
    die.value = die.value * factor

func apply_set_max(die: Die) -> void:
    die.value = die.faces

func apply_set_min(die: Die) -> void:
    die.value = 1

func reroll_lucky(die: Die) -> int:
    var old_value = die.value
    die.rolled = false
    die.roll()
    if old_value > die.value:
        die.value = old_value
        die.rolled = true
    return die.value

func drop_die(die: Die) -> void:
    die.dropped = true

func reroll_unlucky(die: Die) -> int:
    var old_value = die.value
    die.rolled = false
    die.roll()
    if old_value < die.value:
        die.value = old_value
        die.rolled = true
    return die.value

func _reshuffle() -> void:
    _pool.append_array(_discard)
    _discard = []
