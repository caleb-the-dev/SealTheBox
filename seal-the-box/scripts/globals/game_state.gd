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
	round_limit = 4
	win_threshold = 13
	tabs = [1, 2, 3, 4, 5, 6, 7, 8, 9]
	dice_hand = []
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
			ability_hand.append(ability.duplicate())
		else:
			push_error("GameState: ability not found: %s" % id)
