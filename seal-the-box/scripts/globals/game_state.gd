extends Node

var hp: int = 6
var ap: int = 3
var round: int = 0
var round_limit: int = 3
var win_threshold: int = 13
var tabs: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9]
var dice_pool: Array = []   # Array of Die
var dice_hand: Array = []   # Array of Die (currently drawn)
var ability_hand: Array = []  # Array of AbilityData
var current_box: BoxDefinition = null

func reset_run() -> void:
	hp = 6
	_setup_dice_pool()
	reset_match()
	if ability_hand.is_empty():
		_setup_ability_hand()

func reset_match() -> void:
	ap = 3
	round = 0
	dice_hand = []
	for die in dice_pool:
		die.value = 0
		die.rolled = false

func spend_ap(amount: int) -> bool:
	if ap < amount:
		return false
	ap -= amount
	return true

func reset_run_end() -> void:
	reset_match()

func _setup_dice_pool() -> void:
	dice_pool = []
	for i in 3:
		dice_pool.append(Die.new(6))
	dice_pool.append(Die.new(4))
	dice_pool.append(Die.new(8))

func _setup_ability_hand() -> void:
	ability_hand = []
	var lib = Engine.get_singleton("AbilityLibrary")
	for id in ["reroll_die", "greater_1", "lesser_1"]:
		var ability = lib.get_ability(id)
		if ability:
			ability_hand.append(ability.duplicate())
		else:
			push_error("GameState: ability not found: %s" % id)
