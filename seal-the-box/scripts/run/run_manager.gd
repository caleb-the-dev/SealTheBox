class_name RunManager
extends Node

signal next_match_ready(box: BoxDefinition)
signal show_power_offer(powers: Array)
signal show_rotation_offer(options: Array)
signal show_die_swap(offered_dice: Array)
signal run_over(match_number: int)

const DIE_SWAP_FACES: Array[int] = [2, 4, 8, 10, 12]

var match_number: int = 1
var _boxes: Array = []
var _pending_rotation_options: Array = []

func start_run() -> void:
	var box_lib = Engine.get_singleton("BoxLibrary")
	_boxes = box_lib.get_ordered()
	match_number = 1
	var gs = Engine.get_singleton("GameState")
	gs.reset_run()
	next_match_ready.emit(_boxes[0])

func handle_match_won(critical: bool) -> void:
	match_number += 1
	if Engine.has_singleton("PowerManager"):
		Engine.get_singleton("PowerManager").apply_survivor()
	if critical:
		if Engine.has_singleton("PowerManager"):
			Engine.get_singleton("PowerManager").apply_box_shutter()
		_do_power_offer()
	else:
		_do_rotation_offer()

func handle_match_lost() -> void:
	if Engine.has_singleton("PowerManager"):
		if Engine.get_singleton("PowerManager").try_phoenix_down():
			match_number += 1
			_start_next_match()
			return
	run_over.emit(match_number)

func handle_power_offer_accepted(power: PowerData) -> void:
	if Engine.has_singleton("PowerManager"):
		Engine.get_singleton("PowerManager").add_power(power)
	else:
		Engine.get_singleton("GameState").owned_powers.append(power)
	_do_rotation_offer()

func handle_power_offer_skipped() -> void:
	_do_rotation_offer()

func handle_rotation_pick(chosen: AbilityData) -> void:
	if chosen == null:
		push_error("RunManager: handle_rotation_pick called with null ability")
		return
	var gs = Engine.get_singleton("GameState")
	gs.ability_hand[0] = gs.ability_hand[1]
	gs.ability_hand[1] = gs.ability_hand[2]
	gs.ability_hand[2] = chosen
	_pending_rotation_options = []
	gs.reset_run_end()
	# match_number is already post-incremented here; condition fires after matches 5, 10, 15, ...
	if (match_number - 1) % 5 == 0:
		var offered: Array = []
		for f in DIE_SWAP_FACES:
			offered.append(Die.new(f))
		show_die_swap.emit(offered)
	else:
		_start_next_match()

func handle_die_swap_confirm(offered_die: Die, pool_die: Die) -> void:
	var gs = Engine.get_singleton("GameState")
	var idx = gs.dice_pool.find(pool_die)
	if idx >= 0:
		gs.dice_pool[idx] = offered_die
	else:
		push_error("RunManager: handle_die_swap_confirm could not find pool_die in dice_pool")
	_start_next_match()

func handle_die_swap_skip() -> void:
	_start_next_match()

func dev_skip_rotation() -> void:
	if _pending_rotation_options.size() > 0:
		handle_rotation_pick(_pending_rotation_options[0])

func _start_next_match() -> void:
	var next_box = _boxes[(match_number - 1) % _boxes.size()]
	next_match_ready.emit(next_box)

func _do_power_offer() -> void:
	var gs = Engine.get_singleton("GameState")
	if not Engine.has_singleton("PowerLibrary"):
		_do_rotation_offer()
		return
	var powers = Engine.get_singleton("PowerLibrary").get_random_unowned_multiple(gs.owned_powers, 3)
	if powers.is_empty():
		_do_rotation_offer()
		return
	show_power_offer.emit(powers)

func _do_rotation_offer() -> void:
	var gs = Engine.get_singleton("GameState")
	var lib = Engine.get_singleton("AbilityLibrary")
	var pool: Array = gs.ABILITY_POOL_IDS.duplicate()
	_pending_rotation_options = []
	for i in 3:
		if pool.is_empty():
			break
		var idx = randi() % pool.size()
		var ability = lib.get_ability(pool[idx])
		pool.remove_at(idx)
		if ability:
			_pending_rotation_options.append(ability.duplicate())
	if _pending_rotation_options.size() < 3:
		push_error("RunManager: _do_rotation_offer could not build 3 options (got %d)" % _pending_rotation_options.size())
		return
	show_rotation_offer.emit(_pending_rotation_options)
