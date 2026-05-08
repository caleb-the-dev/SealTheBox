extends SceneTree

const TextureRollerScript = preload("res://scripts/run/texture_roller.gd")
const EventOverlayScript = preload("res://scripts/ui/event_overlay.gd")

func _init() -> void:
	# ── Bootstrap libraries ────────────────────────────────────────────────────
	var ability_lib = load("res://scripts/globals/ability_library.gd").new()
	ability_lib.name = "AbilityLibrary"
	get_root().add_child(ability_lib)
	ability_lib._ready()
	Engine.register_singleton("AbilityLibrary", ability_lib)

	var box_lib = load("res://scripts/globals/box_library.gd").new()
	box_lib.name = "BoxLibrary"
	get_root().add_child(box_lib)
	box_lib._ready()
	Engine.register_singleton("BoxLibrary", box_lib)

	var gs = load("res://scripts/globals/game_state.gd").new()
	gs.name = "GameState"
	get_root().add_child(gs)
	Engine.register_singleton("GameState", gs)

	var vl = load("res://scripts/globals/vignette_library.gd").new()
	vl.name = "VignetteLibrary"
	get_root().add_child(vl)
	vl._ready()
	Engine.register_singleton("VignetteLibrary", vl)

	var el = load("res://scripts/globals/event_library.gd").new()
	el.name = "EventLibrary"
	get_root().add_child(el)
	el._ready()
	Engine.register_singleton("EventLibrary", el)

	gs.reset_run()

	# ── Run tests ──────────────────────────────────────────────────────────────
	_test_distribution()
	_test_empty_pool_fallback()
	_test_effect_none()
	_test_effect_hp_minus()
	_test_effect_hp_plus()
	_test_effect_hp_plus_capped()
	_test_effect_charge_random()
	_test_effect_combined()
	_test_effect_unknown()

	print("All TextureRoller tests passed!")
	quit()

# ── Distribution test ─────────────────────────────────────────────────────────

func _test_distribution() -> void:
	const ROLLS := 1000
	const TOLERANCE := 0.08  # ±8 percentage points

	var counts := { "silent": 0, "vignette": 0, "event": 0 }
	for i in ROLLS:
		var result = TextureRollerScript.roll("default")
		var t: String = result["type"]
		counts[t] = counts[t] + 1

	var p_silent  := float(counts["silent"])  / ROLLS
	var p_vignette := float(counts["vignette"]) / ROLLS
	var p_event   := float(counts["event"])   / ROLLS

	var prob_event := 1.0 - TextureRollerScript.PROB_SILENT - TextureRollerScript.PROB_VIGNETTE
	assert(abs(p_silent  - TextureRollerScript.PROB_SILENT)   < TOLERANCE,
		"silent proportion %.3f not within %.0f%% of %.3f" % [p_silent, TOLERANCE*100, TextureRollerScript.PROB_SILENT])
	assert(abs(p_vignette - TextureRollerScript.PROB_VIGNETTE) < TOLERANCE,
		"vignette proportion %.3f not within %.0f%% of %.3f" % [p_vignette, TOLERANCE*100, TextureRollerScript.PROB_VIGNETTE])
	assert(abs(p_event - prob_event) < TOLERANCE,
		"event proportion %.3f not within %.0f%% of %.3f" % [p_event, TOLERANCE*100, prob_event])

# ── Empty-pool fallback ───────────────────────────────────────────────────────

func _test_empty_pool_fallback() -> void:
	# Roll many times with a non-existent pool_id; should never return vignette or event
	const ROLLS := 200
	for i in ROLLS:
		var result = TextureRollerScript.roll("nonexistent_pool")
		assert(result["type"] == "silent",
			"With empty pool, roll should return silent, got: %s" % result["type"])

# ── Effect-string parser tests ────────────────────────────────────────────────

func _test_effect_none() -> void:
	var gs = Engine.get_singleton("GameState")
	var before_hp = gs.hp
	EventOverlayScript.apply_effects("none")
	assert(gs.hp == before_hp, "'none' should not change HP")

func _test_effect_hp_minus() -> void:
	var gs = Engine.get_singleton("GameState")
	gs.hp = GameState.MAX_HP
	EventOverlayScript.apply_effects("hp-1")
	assert(gs.hp == GameState.MAX_HP - 1,
		"hp-1 should decrease HP by 1, got %d" % gs.hp)
	# Restore
	gs.hp = GameState.MAX_HP

func _test_effect_hp_plus() -> void:
	var gs = Engine.get_singleton("GameState")
	gs.hp = 3
	EventOverlayScript.apply_effects("hp+2")
	assert(gs.hp == 5, "hp+2 from 3 should give 5, got %d" % gs.hp)
	# Restore
	gs.hp = GameState.MAX_HP

func _test_effect_hp_plus_capped() -> void:
	var gs = Engine.get_singleton("GameState")
	gs.hp = GameState.MAX_HP
	EventOverlayScript.apply_effects("hp+2")
	assert(gs.hp == GameState.MAX_HP,
		"hp+2 at max should stay capped at %d, got %d" % [GameState.MAX_HP, gs.hp])

func _test_effect_charge_random() -> void:
	var gs = Engine.get_singleton("GameState")
	# Set up ability hand with one ability that has room for charges
	var lib = Engine.get_singleton("AbilityLibrary")
	var ability = lib.get_ability("reroll_die")
	assert(ability != null, "test setup: reroll_die should exist")
	var a = ability.duplicate()
	a.charges = 1
	a.max_charges = 2
	gs.ability_hand = [a, null, null]

	EventOverlayScript.apply_effects("charge_random+1")
	assert(gs.ability_hand[0].charges == 2,
		"charge_random+1 should add 1 charge, got %d" % gs.ability_hand[0].charges)

	# With all null — should no-op without error
	gs.ability_hand = [null, null, null]
	EventOverlayScript.apply_effects("charge_random+1")  # should not crash

	# Restore
	gs.reset_run()

func _test_effect_combined() -> void:
	var gs = Engine.get_singleton("GameState")
	gs.hp = GameState.MAX_HP
	var lib = Engine.get_singleton("AbilityLibrary")
	var ability = lib.get_ability("reroll_die")
	var a = ability.duplicate()
	a.charges = 1
	a.max_charges = 2
	gs.ability_hand = [a, null, null]

	EventOverlayScript.apply_effects("hp-1;charge_random+1")
	assert(gs.hp == GameState.MAX_HP - 1,
		"combined: hp-1 should work, got %d" % gs.hp)
	assert(gs.ability_hand[0].charges == 2,
		"combined: charge_random+1 should work, got %d" % gs.ability_hand[0].charges)

	# Restore
	gs.reset_run()

func _test_effect_unknown() -> void:
	var gs = Engine.get_singleton("GameState")
	var before_hp = gs.hp
	# This should push_error but not crash or change state
	EventOverlayScript.apply_effects("garbage_effect")
	assert(gs.hp == before_hp, "Unknown effect should not change HP")
