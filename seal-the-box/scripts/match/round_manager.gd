class_name RoundManager
extends Node

signal phase_changed(phase: String)
signal round_ended(round_num: int)
signal match_won(critical: bool)
signal match_lost()
signal tabs_sealed(tabs: Array)
signal status_updated(text: String)
signal threshold_reached()

var _tab_board: TabBoard
var _dice_pool: DicePool
var _current_phase: String = ""
var _match_over: bool = false
var _threshold_notified: bool = false

func start_match(box: BoxDefinition) -> void:
	GameState.current_box = box
	GameState.win_threshold = box.win_threshold
	GameState.round_limit = box.round_limit
	GameState.tabs = box.tabs.duplicate()
	_tab_board = TabBoard.new()
	_dice_pool = DicePool.new()
	_match_over = false
	_threshold_notified = false
	GameState.reset_match()
	_tab_board.reset(GameState.tabs.duplicate())
	_dice_pool.setup(GameState.dice_pool.duplicate())
	start_round()

func start_round() -> void:
	GameState.round += 1
	GameState.ap = 3
	if GameState.round > GameState.round_limit:
		GameState.hp -= 1
		if GameState.hp <= 0:
			_match_over = true
			match_lost.emit()
			return
	var hand = _dice_pool.draw_hand()
	GameState.dice_hand = hand
	_set_phase("roll")
	if GameState.round > GameState.round_limit:
		status_updated.emit("Overtime — Round %d / %d — Lost 1 HP (%d remaining). Roll Phase: select dice to roll." % [GameState.round, GameState.round_limit, GameState.hp])
	else:
		status_updated.emit("Round %d / %d — Roll Phase: select dice to roll (1 AP each)" % [GameState.round, GameState.round_limit])

func commit_roll(dice: Array) -> void:
	var partial := false
	for die in dice:
		if not GameState.spend_ap(1):
			partial = true
			break
		_dice_pool.roll_die(die)
	var total := 0
	for die in GameState.dice_hand:
		if die.rolled:
			total += die.value
	_set_phase("act")
	if partial:
		status_updated.emit("Seal Phase — Out of AP. Total: %d — select tabs to seal." % total)
	else:
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
	GameState.tabs = _tab_board.get_remaining()
	tabs_sealed.emit(tabs)
	_check_win()
	return true

func use_ability(ability: AbilityData, target_die) -> bool:
	if _match_over:
		return false
	if _current_phase == "roll":
		status_updated.emit("Use abilities after rolling dice.")
		return false
	if target_die == null and ability.id != "reroll_all":
		push_warning("RoundManager: target_die is null for ability: %s" % ability.id)
		return false
	match ability.id:
		"reroll_die":
			_dice_pool.reroll(target_die)
		"greater_1":
			_dice_pool.apply_greater(target_die, 1)
		"lesser_1":
			_dice_pool.apply_lesser(target_die, 1)
		"greater_2":
			_dice_pool.apply_greater(target_die, 2)
		"lesser_2":
			_dice_pool.apply_lesser(target_die, 2)
		"reroll_all":
			for die in GameState.dice_hand:
				if die.rolled:
					_dice_pool.reroll(die)
		_:
			push_warning("RoundManager: unhandled ability id: %s" % ability.id)
			return false
	GameState.ability_hand.erase(ability)
	var total := 0
	for die in GameState.dice_hand:
		if die.rolled:
			total += die.value
	status_updated.emit("Seal Phase — Total: %d — select tabs that sum to it." % total)
	return true

func end_round() -> void:
	if _match_over:
		return
	_dice_pool.discard_hand()
	GameState.dice_hand = []
	round_ended.emit(GameState.round)
	start_round()

func accept_threshold_win() -> void:
	if _match_over:
		return
	_match_over = true
	match_won.emit(false)

func _check_win() -> void:
	if _tab_board.check_critical_win():
		_match_over = true
		match_won.emit(true)
	elif _tab_board.check_win(GameState.win_threshold) and not _threshold_notified:
		_threshold_notified = true
		threshold_reached.emit()

func get_draw_count() -> int:
	return _dice_pool.get_draw_count() if _dice_pool else 0

func get_discard_count() -> int:
	return _dice_pool.get_discard_count() if _dice_pool else 0

func dev_win_match() -> void:
	if _match_over:
		return
	_match_over = true
	match_won.emit(false)

func _set_phase(phase: String) -> void:
	_current_phase = phase
	phase_changed.emit(phase)
