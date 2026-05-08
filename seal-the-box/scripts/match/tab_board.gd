class_name TabBoard
extends RefCounted

# TabData tracks each active tab: its value and optional metadata.
# Using a parallel array (_decoy_flags) to track is_decoy status keeps
# the public Array[int] API backward-compatible while supporting fading_decoys.
class TabData:
	var value: int = 0
	var is_decoy: bool = false

	func _init(v: int, decoy: bool = false) -> void:
		value = v
		is_decoy = decoy

signal tabs_changed

# Internal storage: Array of TabData.
# Public-facing methods still return Array[int] for backward compatibility.
var _tabs: Array = []   # Array of TabData

# ---------------------------------------------------------------------------
# Reset / initialisation
# ---------------------------------------------------------------------------

func reset(tab_range: Array[int]) -> void:
	_tabs = []
	for v in tab_range:
		_tabs.append(TabData.new(v))
	tabs_changed.emit()

# Reset with decoy information.
# tab_range: all tabs in order (real first, then phantoms appended at the end).
# decoy_count: how many of the trailing entries are decoys.
# This assumes phantoms are appended AFTER the real tabs.
func reset_with_decoys(tab_range: Array[int], decoy_count: int) -> void:
	_tabs = []
	var real_count: int = tab_range.size() - decoy_count
	for i in tab_range.size():
		var is_decoy: bool = (i >= real_count)
		_tabs.append(TabData.new(tab_range[i], is_decoy))
	tabs_changed.emit()

# ---------------------------------------------------------------------------
# Mutation API  (each emits tabs_changed so the UI can re-render)
# ---------------------------------------------------------------------------

# Append a new tab with given value.
func add_tab(value: int) -> void:
	_tabs.append(TabData.new(value))
	tabs_changed.emit()

# Remove the first tab with the given value (real tabs only by default).
# Pass check_decoy=false to also target decoy tabs.
func remove_tab(value: int, check_decoy: bool = false) -> void:
	for i in _tabs.size():
		var td: TabData = _tabs[i]
		if td.value == value and (not td.is_decoy or check_decoy):
			_tabs.remove_at(i)
			tabs_changed.emit()
			return

# Change the first real tab with old_value to new_value.
func change_tab_value(old_value: int, new_value: int) -> void:
	for td in _tabs:
		if td.value == old_value and not td.is_decoy:
			td.value = new_value
			tabs_changed.emit()
			return

# Change the tab at a specific index (by position in _tabs).
func change_tab_value_at(index: int, new_value: int) -> void:
	if index >= 0 and index < _tabs.size():
		_tabs[index].value = new_value
		tabs_changed.emit()

# Replace all tabs entirely (used by moving_targets).
func replace_all_tabs(new_values: Array[int]) -> void:
	_tabs = []
	for v in new_values:
		_tabs.append(TabData.new(v))
	tabs_changed.emit()

# Reveal all decoys (set them back to non-decoy and then remove them).
# Returns the values that were phantom so callers can report them.
func reveal_and_vanish_decoys() -> Array[int]:
	var revealed: Array[int] = []
	var survivors: Array = []
	for td in _tabs:
		if td.is_decoy:
			revealed.append(td.value)
		else:
			survivors.append(td)
	_tabs = survivors
	tabs_changed.emit()
	return revealed

# ---------------------------------------------------------------------------
# Legacy seal API (operates on real tabs only)
# ---------------------------------------------------------------------------

func seal_tab(value: int) -> void:
	remove_tab(value, false)

func seal_tabs(tabs: Array) -> void:
	for t in tabs:
		seal_tab(t)

# ---------------------------------------------------------------------------
# Read API
# ---------------------------------------------------------------------------

# Returns values of all remaining tabs (real + decoys).
func get_remaining() -> Array[int]:
	var result: Array[int] = []
	for td in _tabs:
		result.append(td.value)
	return result

# Returns values of real (non-decoy) tabs only.
func get_real_remaining() -> Array[int]:
	var result: Array[int] = []
	for td in _tabs:
		if not td.is_decoy:
			result.append(td.value)
	return result

# Returns the TabData array (for advanced callers like the UI).
func get_tab_data() -> Array:
	return _tabs.duplicate()

# Sum of real (non-decoy) tab values only (for threshold / win logic).
func get_real_sum() -> int:
	var total: int = 0
	for td in _tabs:
		if not td.is_decoy:
			total += td.value
	return total

# Legacy get_sum — returns sum of ALL tabs (real + decoy) for display purposes.
# Win logic should use get_real_sum() / check_win_real().
func get_sum() -> int:
	var total: int = 0
	for td in _tabs:
		total += td.value
	return total

# Win check uses real-tab sum only.
func check_win(threshold: int) -> bool:
	return get_real_sum() <= threshold

# Critical win: all real tabs sealed (decoys may still be present).
func check_critical_win() -> bool:
	for td in _tabs:
		if not td.is_decoy:
			return false
	return true

# can_seal_multi checks only among real tabs.
func can_seal_multi(dice_total: int, tabs: Array) -> bool:
	var real_remaining := get_real_remaining()
	var tab_sum: int = 0
	for t in tabs:
		if not t in real_remaining:
			return false
		tab_sum += t
	return tab_sum == dice_total

# Returns all tab data entries (real and decoy) — for UI display with decoy hints.
func has_decoys() -> bool:
	for td in _tabs:
		if td.is_decoy:
			return true
	return false
