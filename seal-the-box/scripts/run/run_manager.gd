class_name RunManager
extends Node

signal next_match_ready()
signal show_reward(dice_faces: Array)
signal run_won(match_number: int, hp: int)
signal run_over(match_number: int)

const REWARD_DIE_FACES = [2, 3, 4, 5, 6, 7, 8, 10, 12]
const RUN_LENGTH: int = 3

var match_number: int = 1

func start_run() -> void:
	match_number = 1
	var gs = Engine.get_singleton("GameState")
	gs.reset_run()
	next_match_ready.emit()

func handle_match_won(_critical: bool) -> void:
	if match_number >= RUN_LENGTH:
		var gs = Engine.get_singleton("GameState")
		run_won.emit(match_number, gs.hp)
	else:
		show_reward.emit(_pick_reward_dice(3))

func handle_match_lost() -> void:
	run_over.emit(match_number)

func advance_to_next_match(chosen_face: int) -> void:
	var gs = Engine.get_singleton("GameState")
	gs.dice_pool.append(Die.new(chosen_face))
	match_number += 1
	gs.reset_match()
	next_match_ready.emit()

func _pick_reward_dice(count: int) -> Array:
	var pool: Array = REWARD_DIE_FACES.duplicate()
	var picks: Array = []
	for i in count:
		var idx = randi() % pool.size()
		picks.append(pool[idx])
		pool.remove_at(idx)
	return picks
