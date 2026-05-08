class_name RoundManager
extends Node

# Preload BHV-axis dispatcher so it compiles in both full-project and
# headless --script test modes (global class_name lookup isn't available
# in --script mode without a project import).
const _BoxTabBehavior = preload("res://scripts/match/box_tab_behavior.gd")

signal phase_changed(phase: String)
signal round_ended(round_num: int)
signal match_won(critical: bool)
signal match_lost()
signal tabs_sealed(tabs: Array)
signal status_updated(text: String)
signal threshold_reached()
# Emitted when BHV hooks mutate the tab board mid-round so UI can refresh.
signal tab_behavior_changed(message: String)

var _tab_board: TabBoard
var _dice_pool: DicePool
var _current_phase: String = ""
var _match_over: bool = false
var _threshold_notified: bool = false
# Track whether any tabs were sealed in the current round (for revenant_tabs).
var _sealed_this_round: bool = false

# Shadow the autoload name so --script headless tests (which register the
# singleton manually) can compile this file without autoloads running.
var GameState: Node:
	get: return Engine.get_singleton("GameState")

func start_match(box: BoxDefinition) -> void:
	GameState.current_box = box
	var threshold = box.win_threshold
	var power_mgr = Engine.get_singleton("PowerManager") if Engine.has_singleton("PowerManager") else null
	if power_mgr:
		threshold += power_mgr.get_threshold_bonus()
		threshold += GameState.pending_threshold_bonus
		GameState.pending_threshold_bonus = 0
	GameState.win_threshold = threshold
	GameState.round_limit = box.round_limit
	GameState.tabs = box.tabs.duplicate()
	_tab_board = TabBoard.new()
	_dice_pool = DicePool.new()
	_match_over = false
	_threshold_notified = false
	_sealed_this_round = false
	GameState.reset_match()
	# fading_decoys: initialise the board with decoy metadata.
	# Phantoms are appended after the real tabs; reset_with_decoys uses
	# a trailing-count approach so real 3/5/7 stay real.
	if box.id == "fading_decoys":
		var phantom_values: Array[int] = [3, 5, 7]
		var all_tabs: Array[int] = box.tabs.duplicate()
		all_tabs.append_array(phantom_values)
		_tab_board.reset_with_decoys(all_tabs, phantom_values.size())
	else:
		_tab_board.reset(GameState.tabs.duplicate())
	# Sync GameState.tabs from the board so it reflects decoys too.
	GameState.tabs = _tab_board.get_remaining()
	_dice_pool.setup(GameState.dice_pool.duplicate())
	start_round()

func start_round() -> void:
	GameState.round += 1
	_sealed_this_round = false
	# BHV: fire round-start hook for the active box.
	if GameState.current_box and _BoxTabBehavior.has_behavior(GameState.current_box.id):
		_BoxTabBehavior.on_round_start(GameState.current_box.id, _tab_board, GameState)
		GameState.tabs = _tab_board.get_remaining()
		# Check if fading_decoys just revealed phantoms.
		if GameState.has_meta("bhv_fading_decoys_revealed"):
			var vanished: Array = GameState.get_meta("bhv_fading_decoys_revealed")
			GameState.remove_meta("bhv_fading_decoys_revealed")
			var msg := "Fading Decoys — the phantoms (%s) vanished!" % str(vanished)
			tab_behavior_changed.emit(msg)
		elif GameState.current_box.id == "moving_targets":
			tab_behavior_changed.emit("Moving Targets — range shifted for round %d." % GameState.round)
		elif GameState.current_box.id == "shuffler":
			tab_behavior_changed.emit("Shuffler — tab values redrawn!")
		elif GameState.current_box.id == "regrowing" and GameState.round > 1:
			tab_behavior_changed.emit("Regrowing — a tab returned!")
	var hand = _dice_pool.draw_hand()
	GameState.dice_hand = hand
	if GameState.round == 1:
		var power_mgr = Engine.get_singleton("PowerManager") if Engine.has_singleton("PowerManager") else null
		if power_mgr:
			power_mgr.apply_eager(hand)
			power_mgr.apply_coffee_break()
	_set_phase("roll")
	status_updated.emit("Round %d / %d — Roll Phase: select dice to roll." % [GameState.round, GameState.round_limit])

func commit_roll(dice: Array) -> void:
	var power_mgr = Engine.get_singleton("PowerManager") if Engine.has_singleton("PowerManager") else null
	for die in dice:
		_dice_pool.roll_die(die)
		if power_mgr:
			power_mgr.on_die_rolled(die)
	var total := 0
	for die in GameState.dice_hand:
		if die.rolled and not die.dropped:
			total += die.value
	_set_phase("act")
	status_updated.emit("Seal Phase — Total: %d — select tabs that sum to it." % total)

func attempt_seal(dice: Array, tabs: Array) -> bool:
	if _match_over:
		return false
	var dice_total := 0
	for d in dice:
		dice_total += d.value
	if not _tab_board.can_seal_multi(dice_total, tabs):
		return false
	_tab_board.seal_tabs(tabs)
	_sealed_this_round = true
	var all_sealed = tabs.duplicate()
	var power_mgr = Engine.get_singleton("PowerManager") if Engine.has_singleton("PowerManager") else null
	if power_mgr:
		var bonus = power_mgr.get_bonus_seals_if_ready(_tab_board, tabs)
		if not bonus.is_empty():
			_tab_board.seal_tabs(bonus)
			all_sealed.append_array(bonus)
		power_mgr.apply_tab9_bounty(all_sealed)
		power_mgr.on_tabs_sealed(all_sealed.size())
	# BHV: fire on_seal hook (e.g. mitosis spawning).
	if GameState.current_box and _BoxTabBehavior.has_behavior(GameState.current_box.id):
		var bhv_msg := _BoxTabBehavior.on_seal(GameState.current_box.id, all_sealed, _tab_board, GameState, 0)
		if not bhv_msg.is_empty():
			tab_behavior_changed.emit(bhv_msg)
	GameState.tabs = _tab_board.get_remaining()
	tabs_sealed.emit(all_sealed)
	_check_win()
	return true

func use_ability(ability: AbilityData, target_die) -> bool:
	if _match_over:
		return false
	if ability.charges <= 0:
		return false
	if _current_phase == "roll":
		status_updated.emit("Use abilities after rolling dice.")
		return false
	if target_die == null and ability.id not in ["reroll_all", "put_down_highest", "auto_seal_lowest"]:
		push_warning("RoundManager: target_die is null for ability: %s" % ability.id)
		return false
	var power_mgr = Engine.get_singleton("PowerManager") if Engine.has_singleton("PowerManager") else null
	match ability.id:
		"reroll_die":
			_dice_pool.reroll(target_die)
			if power_mgr:
				power_mgr.on_die_rolled(target_die)
		"greater_1":
			if target_die.value >= target_die.faces:
				status_updated.emit("Die is already at or above its maximum — Empower can't apply.")
				return false
			_dice_pool.apply_greater(target_die, 1)
		"lesser_1":
			_dice_pool.apply_lesser(target_die, 1)
		"greater_2":
			if target_die.value >= target_die.faces:
				status_updated.emit("Die is already at or above its maximum — Empower II can't apply.")
				return false
			_dice_pool.apply_greater(target_die, 2)
		"lesser_2":
			_dice_pool.apply_lesser(target_die, 2)
		"reroll_all":
			for die in GameState.dice_hand:
				if die.rolled:
					_dice_pool.reroll(die)
					if power_mgr:
						power_mgr.on_die_rolled(die)
		"put_down_highest":
			var remaining = _tab_board.get_real_remaining()
			if remaining.size() <= 1:
				return false
			remaining.sort()
			var tab_val = remaining[-1]
			_tab_board.seal_tab(tab_val)
			_sealed_this_round = true
			GameState.tabs = _tab_board.get_remaining()
			if power_mgr:
				power_mgr.apply_tab9_bounty([tab_val])
				power_mgr.on_tabs_sealed(1)
			if GameState.current_box and _BoxTabBehavior.has_behavior(GameState.current_box.id):
				var bhv_msg := _BoxTabBehavior.on_seal(GameState.current_box.id, [tab_val], _tab_board, GameState, 0)
				if not bhv_msg.is_empty():
					tab_behavior_changed.emit(bhv_msg)
				GameState.tabs = _tab_board.get_remaining()
			tabs_sealed.emit([tab_val])
			_check_win()
		"auto_seal_lowest":
			var remaining = _tab_board.get_real_remaining()
			if remaining.size() <= 1:
				return false
			remaining.sort()
			var tab_val = remaining[0]
			_tab_board.seal_tab(tab_val)
			_sealed_this_round = true
			GameState.tabs = _tab_board.get_remaining()
			if power_mgr:
				power_mgr.apply_tab9_bounty([tab_val])
				power_mgr.on_tabs_sealed(1)
			if GameState.current_box and _BoxTabBehavior.has_behavior(GameState.current_box.id):
				var bhv_msg := _BoxTabBehavior.on_seal(GameState.current_box.id, [tab_val], _tab_board, GameState, 0)
				if not bhv_msg.is_empty():
					tab_behavior_changed.emit(bhv_msg)
				GameState.tabs = _tab_board.get_remaining()
			tabs_sealed.emit([tab_val])
			_check_win()
		"multiply_2":
			if not target_die.rolled:
				return false
			_dice_pool.apply_multiply(target_die, 2)
		"set_max":
			if not target_die.rolled:
				return false
			_dice_pool.apply_set_max(target_die)
		"set_min":
			if not target_die.rolled:
				return false
			_dice_pool.apply_set_min(target_die)
		"reroll_lucky":
			if not target_die.rolled:
				return false
			_dice_pool.reroll_lucky(target_die)
		"drop_die":
			if not target_die.rolled:
				return false
			_dice_pool.drop_die(target_die)
		"reroll_unlucky":
			if not target_die.rolled:
				return false
			_dice_pool.reroll_unlucky(target_die)
		_:
			push_warning("RoundManager: unhandled ability id: %s" % ability.id)
			return false
	ability.charges -= 1
	var total := 0
	for die in GameState.dice_hand:
		if die.rolled and not die.dropped:
			total += die.value
	status_updated.emit("Seal Phase — Total: %d — select tabs that sum to it." % total)
	return true

func end_round() -> void:
	if _match_over:
		return
	_dice_pool.discard_hand()
	GameState.dice_hand = []
	var in_overtime: bool = GameState.round > GameState.round_limit
	if in_overtime:
		GameState.hp -= 1
	var power_mgr = Engine.get_singleton("PowerManager") if Engine.has_singleton("PowerManager") else null
	if power_mgr:
		power_mgr.on_round_end()
	# BHV: fire round-end hooks before emitting round_ended.
	if GameState.current_box and _BoxTabBehavior.has_behavior(GameState.current_box.id):
		var bhv_msg := _BoxTabBehavior.on_round_end(GameState.current_box.id, _tab_board, GameState)
		if not bhv_msg.is_empty():
			tab_behavior_changed.emit(bhv_msg)
		# No-seal hook: fires only if player sealed nothing this round.
		if not _sealed_this_round:
			var no_seal_msg := _BoxTabBehavior.on_round_end_no_seal(GameState.current_box.id, _tab_board, GameState)
			if not no_seal_msg.is_empty():
				tab_behavior_changed.emit(no_seal_msg)
		GameState.tabs = _tab_board.get_remaining()
	round_ended.emit(GameState.round)
	if in_overtime and GameState.hp <= 0:
		_match_over = true
		if power_mgr:
			power_mgr.on_match_end()
		match_lost.emit()
		return
	start_round()

func accept_threshold_win() -> void:
	if _match_over:
		return
	_match_over = true
	var power_mgr = Engine.get_singleton("PowerManager") if Engine.has_singleton("PowerManager") else null
	if power_mgr:
		power_mgr.on_match_end()
	match_won.emit(false)

func _check_win() -> void:
	if _tab_board.check_critical_win():
		_match_over = true
		GameState.hp = min(GameState.hp + 1, GameState.MAX_HP)
		var power_mgr = Engine.get_singleton("PowerManager") if Engine.has_singleton("PowerManager") else null
		if power_mgr:
			power_mgr.on_match_end()
		match_won.emit(true)
	elif _tab_board.check_win(GameState.win_threshold) and not _threshold_notified:
		_threshold_notified = true
		threshold_reached.emit()

func get_draw_count() -> int:
	return _dice_pool.get_draw_count() if _dice_pool else 0

func get_discard_count() -> int:
	return _dice_pool.get_discard_count() if _dice_pool else 0

# Expose tab board for testing purposes.
func get_tab_board() -> TabBoard:
	return _tab_board

func dev_win_match() -> void:
	if _match_over:
		return
	_match_over = true
	var power_mgr = Engine.get_singleton("PowerManager") if Engine.has_singleton("PowerManager") else null
	if power_mgr:
		power_mgr.on_match_end()
	match_won.emit(false)

func dev_critical_win() -> void:
	if _match_over:
		return
	_match_over = true
	GameState.hp = min(GameState.hp + 1, GameState.MAX_HP)
	var power_mgr = Engine.get_singleton("PowerManager") if Engine.has_singleton("PowerManager") else null
	if power_mgr:
		power_mgr.on_match_end()
	match_won.emit(true)

func _set_phase(phase: String) -> void:
	_current_phase = phase
	phase_changed.emit(phase)
