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
	GameState.reset_match()
	_tab_board.reset(GameState.tabs.duplicate())
	_dice_pool.setup(GameState.dice_pool.duplicate())
	start_round()

func start_round() -> void:
	GameState.round += 1
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
	# Clear any modifier tags from the previous roll.
	for die in GameState.dice_hand:
		die.modifier_tag = ""
	var power_mgr = Engine.get_singleton("PowerManager") if Engine.has_singleton("PowerManager") else null
	for die in dice:
		_dice_pool.roll_die(die)
		if power_mgr:
			power_mgr.on_die_rolled(die)
	# Apply box roll modifier after all dice are rolled (pre-player-view).
	_apply_box_roll_modifier(GameState.dice_hand)
	# Apply display tags (×2 on high die, +N on exploded dice, etc.).
	if GameState.current_box != null:
		BoxRollModifiers.apply_display_tags(GameState.current_box.id, GameState.dice_hand)
	var total := _compute_roll_total(GameState.dice_hand)
	_set_phase("act")
	status_updated.emit("Seal Phase — Total: %d — select tabs that sum to it." % total)

func attempt_seal(dice: Array, tabs: Array) -> bool:
	if _match_over:
		return false
	# Use _compute_roll_total so total-override modifiers (halving_box, doubling_box,
	# high_die_doubles) apply correctly even after per-die ability use.
	var dice_total := _compute_roll_total(GameState.dice_hand)
	if not _tab_board.can_seal_multi(dice_total, tabs):
		return false
	_tab_board.seal_tabs(tabs)
	var all_sealed = tabs.duplicate()
	var power_mgr = Engine.get_singleton("PowerManager") if Engine.has_singleton("PowerManager") else null
	if power_mgr:
		var bonus = power_mgr.get_bonus_seals_if_ready(_tab_board, tabs)
		if not bonus.is_empty():
			_tab_board.seal_tabs(bonus)
			all_sealed.append_array(bonus)
		power_mgr.apply_tab9_bounty(all_sealed)
		power_mgr.on_tabs_sealed(all_sealed.size())
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
			var remaining = _tab_board.get_remaining()
			if remaining.size() <= 1:
				return false
			remaining.sort()
			var tab_val = remaining[-1]
			_tab_board.seal_tab(tab_val)
			GameState.tabs = _tab_board.get_remaining()
			if power_mgr:
				power_mgr.apply_tab9_bounty([tab_val])
				power_mgr.on_tabs_sealed(1)
			tabs_sealed.emit([tab_val])
			_check_win()
		"auto_seal_lowest":
			var remaining = _tab_board.get_remaining()
			if remaining.size() <= 1:
				return false
			remaining.sort()
			var tab_val = remaining[0]
			_tab_board.seal_tab(tab_val)
			GameState.tabs = _tab_board.get_remaining()
			if power_mgr:
				power_mgr.apply_tab9_bounty([tab_val])
				power_mgr.on_tabs_sealed(1)
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
	var total := _compute_roll_total(GameState.dice_hand)
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

# Apply dice-mutation modifiers (heavy_dice, weak_dice, exploding_ones, pair_swallows)
# once per roll. Called from commit_roll after all dice are rolled.
# Total-override modifiers (halving_box, doubling_box, high_die_doubles) are pure
# functions — they are NOT applied here; they recompute from die values on demand.
func _apply_box_roll_modifier(hand: Array) -> void:
	if GameState.current_box == null:
		return
	BoxRollModifiers.apply_dice_mutation(GameState.current_box.id, hand)

# Compute the effective roll total for the current hand, respecting any box roll modifier.
# Public accessor used by match.gd for display and tab-selection validation.
func get_roll_total() -> int:
	return _compute_roll_total(GameState.dice_hand)

# For total-override boxes (halving/doubling/high_die_doubles): returns modifier total.
# For mutation-type boxes: die.value already reflects the modifier; sums naturally.
# For boxes with no modifier: natural sum.
func _compute_roll_total(hand: Array) -> int:
	if GameState.current_box != null:
		var override := BoxRollModifiers.compute_total(GameState.current_box.id, hand)
		if override >= 0:
			return override
	# Natural sum.
	var total := 0
	for die in hand:
		if die.rolled and not die.dropped:
			total += die.value
	return total
