class_name RoundManager
extends Node

signal phase_changed(phase: String)
signal round_ended(round_num: int)
signal match_won(critical: bool)
signal match_lost()
signal tab_sealed(value: int)
signal status_updated(text: String)

var _tab_board: TabBoard
var _dice_pool: DicePool
var _current_phase: String = ""

func _ready() -> void:
	_tab_board = TabBoard.new()
	_dice_pool = DicePool.new()

func start_match() -> void:
	GameState.reset_match()
	_tab_board.reset(GameState.tabs.duplicate())
	_dice_pool.setup(GameState.dice_pool.duplicate())
	start_round()

func start_round() -> void:
	GameState.round += 1
	GameState.ap = 3
	var hand = _dice_pool.draw_hand()
	GameState.dice_hand = hand
	_set_phase("roll")
	status_updated.emit("Round %d of %d — select dice to roll (1 AP each)" % [GameState.round, GameState.round_limit])

func commit_roll(dice: Array) -> void:
	for die in dice:
		if not GameState.spend_ap(1):
			status_updated.emit("Not enough AP to roll all selected dice!")
			break
		_dice_pool.roll_die(die)
	_set_phase("act")
	status_updated.emit("Round %d — seal tabs or use abilities" % GameState.round)

func attempt_seal(dice: Array, tab: int) -> bool:
	var values: Array[int] = []
	for d in dice:
		values.append(d.value)
	if not _tab_board.can_seal(values, tab):
		return false
	_tab_board.seal_tab(tab)
	GameState.tabs = _tab_board.get_remaining()
	tab_sealed.emit(tab)
	_check_win()
	return true

func use_ability(ability: AbilityData, target_die: Die) -> bool:
	if not GameState.spend_ap(ability.ap_cost):
		status_updated.emit("Not enough AP for %s!" % ability.flavor_name)
		return false
	match ability.id:
		"reroll_die":
			_dice_pool.reroll(target_die)
		"greater_1":
			_dice_pool.apply_greater(target_die, 1)
		"lesser_1":
			_dice_pool.apply_lesser(target_die, 1)
		_:
			push_warning("RoundManager: unhandled ability id: %s" % ability.id)
			GameState.ap += ability.ap_cost  # refund
			return false
	return true

func end_round() -> void:
	_dice_pool.discard_hand()
	GameState.dice_hand = []
	if GameState.round > GameState.round_limit:
		GameState.hp -= 1
		status_updated.emit("Round limit exceeded! HP: %d" % GameState.hp)
		if GameState.hp <= 0:
			match_lost.emit()
			return
	round_ended.emit(GameState.round)
	start_round()

func _check_win() -> void:
	if _tab_board.check_critical_win():
		match_won.emit(true)
	elif _tab_board.check_win(GameState.win_threshold):
		match_won.emit(false)

func _set_phase(phase: String) -> void:
	_current_phase = phase
	phase_changed.emit(phase)
