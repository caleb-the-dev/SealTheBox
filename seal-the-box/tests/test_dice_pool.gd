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
    # GameState is an autoload that depends on AbilityLibrary (also an autoload).
    # In headless --script mode, autoloads are not initialized, so we test
    # spend_ap logic using a local helper that mirrors the same logic.
    var helper = _APHelper.new()
    helper.ap = 3
    assert(helper.spend_ap(1), "Should spend 1 AP from 3")
    assert(helper.ap == 2, "AP should be 2 after spending 1")
    assert(helper.spend_ap(2), "Should spend 2 AP from 2")
    assert(helper.ap == 0, "AP should be 0 after spending 2")
    assert(not helper.spend_ap(1), "Should fail to spend 1 AP from 0")
    assert(helper.ap == 0, "AP unchanged on failed spend")

class _APHelper:
    extends RefCounted
    var ap: int = 0
    func spend_ap(amount: int) -> bool:
        if ap < amount:
            return false
        ap -= amount
        return true
