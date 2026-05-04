extends Node

const ABILITY_POOL_IDS: Array[String] = ["reroll_die", "greater_1", "lesser_1", "greater_2", "lesser_2", "reroll_all"]

var hp: int = 6
var round: int = 0
var round_limit: int = 3
var win_threshold: int = 13
var tabs: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9]
var dice_pool: Array = []   # Array of Die
var dice_hand: Array = []   # Array of Die (currently drawn)
var ability_hand: Array = [null, null, null]  # fixed 3-slot array; null = empty
var current_box: BoxDefinition = null

func reset_run() -> void:
	hp = 6
	_setup_dice_pool()
	reset_match()
	_setup_ability_hand()

func reset_match() -> void:
	round = 0
	dice_hand = []
	for die in dice_pool:
		die.value = 0
		die.rolled = false

func reset_run_end() -> void:
	reset_match()

func _setup_dice_pool() -> void:
	dice_pool = []
	for i in 3:
		dice_pool.append(Die.new(6))
	dice_pool.append(Die.new(4))
	dice_pool.append(Die.new(8))

func _setup_ability_hand() -> void:
	var lib = Engine.get_singleton("AbilityLibrary")
	if not lib:
		push_error("GameState: AbilityLibrary singleton not available")
		return
	var chosen_id = ABILITY_POOL_IDS[randi() % ABILITY_POOL_IDS.size()]
	var ability = lib.get_ability(chosen_id)
	ability_hand = [null, null, null]
	if ability:
		ability_hand[2] = ability.duplicate()
	else:
		push_error("GameState: ability not found: %s" % chosen_id)
