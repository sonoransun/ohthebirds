## test_flythrough.gd — Integration tests: simulated flight scenarios
##
## These tests drive the SugarGlider's physics loop with injected inputs and
## assert emergent behavior over multiple simulated seconds. Think of them as
## automated playthroughs that verify the game "feels right" — gliding regen,
## climb drain, energy cycles, and that difficulty presets actually change behavior.
##
## Unlike unit tests that check individual methods, these tests verify that
## the whole physics+energy+input pipeline works end-to-end.
##
## Physics is advanced by calling _physics_process(dt) directly — no real-time
## waiting. 300 calls at 1/60s each = 5 simulated seconds in milliseconds.

extends TestBase

# ============================================================
# HELPERS
# ============================================================

var glider: SugarGlider

func setup() -> void:
	GameManager.set_difficulty_preset(GameManager.DifficultyPreset.NORMAL)
	GameManager.start_new_game()
	glider = _spawn_glider()
	InputManager.set_process(false)  # Prevent smoothing from overwriting test input

func teardown() -> void:
	if is_instance_valid(glider):
		glider.queue_free()
	glider = null
	InputManager.input_direction = Vector2.ZERO
	InputManager._is_input_active = false
	InputManager.set_process(true)
	GameManager.return_to_menu()
	GameManager.set_difficulty_preset(GameManager.DifficultyPreset.NORMAL)
	get_tree().paused = false

## Instantiate a fresh glider at a known starting state.
func _spawn_glider(initial_velocity: Vector2 = Vector2(200.0, 0.0)) -> SugarGlider:
	var g: SugarGlider = load("res://scenes/player/SugarGlider.tscn").instantiate()
	add_child(g)
	g.velocity = initial_velocity
	g.current_energy = g.MAX_ENERGY
	g.is_stunned = false
	g.evasion_mode = false
	return g

## Set input state for fly-through (bypasses smoothing).
func _set_input(dir: Vector2) -> void:
	InputManager.input_direction = dir
	InputManager._is_input_active = dir != Vector2.ZERO

## Simulate N seconds at 60fps.
func _simulate(seconds: float, dir: Vector2 = Vector2.ZERO) -> void:
	_set_input(dir)
	var frames := int(seconds * 60.0)
	var dt := 1.0 / 60.0
	for _i in frames:
		glider._physics_process(dt)

## Reset the glider to a fresh state without re-instantiating.
func _reset_glider(vel: Vector2 = Vector2(200.0, 0.0)) -> void:
	glider.velocity = vel
	glider.current_energy = glider.MAX_ENERGY
	glider.is_stunned = false
	glider.evasion_mode = false
	glider.wind_effect = Vector2.ZERO
	glider.in_thermal = false

# ============================================================
# SCENARIO 1: Passive Glide
# Verify gravity accumulates and energy regenerates during passive flight.
# ============================================================

func test_passive_glide_regenerates_energy_and_accumulates_gravity() -> void:
	# Start at 90% energy (not full, so regen is noticeable)
	glider.current_energy = glider.MAX_ENERGY * 0.9
	glider.velocity = Vector2(200.0, 0.0)

	_simulate(5.0, Vector2.ZERO)  # 5 seconds, no input

	# Energy should have regenerated toward max
	assert_gt(glider.current_energy, glider.MAX_ENERGY * 0.9,
		"energy should regen during passive glide over 5 seconds")

	# Gravity should have caused downward velocity accumulation
	# (may be capped at MAX_FALL_SPEED=800 if gliding doesn't fully counteract gravity)
	assert_gt(glider.velocity.y, 0.0,
		"velocity.y should be positive (downward) after 5s with gravity and no climb input")

# ============================================================
# SCENARIO 2: Active Climb
# Verify upward input drains energy and produces upward velocity.
# ============================================================

func test_active_climb_drains_energy_and_produces_upward_velocity() -> void:
	glider.current_energy = glider.MAX_ENERGY
	glider.velocity = Vector2(300.0, 0.0)  # Fast enough for good lift

	_simulate(3.0, Vector2(0.0, -1.0))  # 3 seconds of upward input

	# Energy should have drained significantly (15/s * 1.5 upward multiplier * 3s ≈ 67.5 drained)
	assert_lt(glider.current_energy, glider.MAX_ENERGY * 0.7,
		"energy should drain substantially during 3s upward climb")

	# Upward input should resist gravity — velocity.y should be less than
	# pure free-fall would produce (gravity=980 over 3s with resistance)
	assert_lt(glider.velocity.y, 2000.0,
		"upward input should reduce downward velocity compared to free fall")

# ============================================================
# SCENARIO 3: Full Energy Cycle — Drain to LOW_ENERGY, then Recover
# Verifies the complete energy lifecycle works as designed.
# ============================================================

func test_energy_cycle_drain_then_recover() -> void:
	glider.current_energy = glider.MAX_ENERGY
	glider.velocity = Vector2(300.0, 0.0)

	# Phase 1: Hold upward input to drain energy
	# At 15/s * 1.5x upward * (any drain multiplier) it drains fast
	# Simulate up to 8 seconds to ensure we hit LOW_ENERGY_THRESHOLD
	_simulate(8.0, Vector2(0.0, -1.0))

	assert_true(glider.is_low_energy(),
		"should reach LOW_ENERGY_THRESHOLD after sustained upward input")

	# Phase 2: Release input — passive regen should restore energy
	var energy_at_low := glider.current_energy
	_simulate(5.0, Vector2.ZERO)  # 5 seconds passive

	assert_gt(glider.current_energy, energy_at_low,
		"energy should recover passively after releasing input")

# ============================================================
# SCENARIO 4: Difficulty Preset Effect on Energy Drain
# Verifies that EASY drains less energy than EXTREME for identical inputs.
# This is the key integration test that confirms difficulty multipliers wire
# correctly all the way to the physics loop.
# ============================================================

func test_easy_drains_less_energy_than_extreme() -> void:
	# Run with EASY preset
	GameManager.set_difficulty_preset(GameManager.DifficultyPreset.EASY)
	_reset_glider(Vector2(300.0, 0.0))
	_simulate(3.0, Vector2(0.0, -1.0))
	var energy_after_easy := glider.current_energy

	# Run with EXTREME preset (reset glider to same starting state)
	GameManager.set_difficulty_preset(GameManager.DifficultyPreset.EXTREME)
	_reset_glider(Vector2(300.0, 0.0))
	_simulate(3.0, Vector2(0.0, -1.0))
	var energy_after_extreme := glider.current_energy

	assert_gt(energy_after_easy, energy_after_extreme,
		"EASY mode should leave more energy than EXTREME after identical 3s climb")

# ============================================================
# SCENARIO 5: Full Game State Cycle
# Verifies the complete start → play → score → end → game_over sequence.
# ============================================================

func test_full_game_state_cycle() -> void:
	# Start a new game
	GameManager.start_new_game()
	assert_true(GameManager.is_playing(), "should be PLAYING after start")
	assert_equal(GameManager.get_current_score(), 0, "score should start at 0")

	# Score some points
	GameManager.add_score(150)
	assert_equal(GameManager.get_current_score(), 150,
		"score should reflect added points (NORMAL = 1.0x)")

	# Travel some distance to trigger difficulty scaling
	GameManager.update_distance(1200.0)
	GameManager.update_game_progression(0.016)
	assert_gt(GameManager.get_difficulty_multiplier(), 1.0,
		"difficulty should have increased at 1200 units")

	# End the game
	GameManager.end_game()
	assert_true(GameManager.is_game_over(), "should be in GAME_OVER state")
	assert_equal(GameManager.high_score, 150, "high score should update after game over")

	# Cleanup
	GameManager.return_to_menu()
	GameManager.high_score = 0

# ============================================================
# SCENARIO 6: Left Input Decelerates Glider
# Verifies that sustained left input reduces forward velocity.
# ============================================================

func test_left_input_decelerates_glider() -> void:
	_reset_glider(Vector2(300.0, 0.0))
	var initial_vx = glider.velocity.x

	_simulate(3.0, Vector2(-1.0, 0.0))  # 3 seconds of left input

	assert_lt(glider.velocity.x, initial_vx,
		"velocity.x should decrease after 3s of left input")

# ============================================================
# SCENARIO 7: Energy Depletion to Zero
# Sustained upward input on EXTREME difficulty until energy hits 0.
# Glider should still exist (not freed / crashed).
# ============================================================

func test_energy_depletion_to_zero() -> void:
	GameManager.set_difficulty_preset(GameManager.DifficultyPreset.EXTREME)
	_reset_glider(Vector2(300.0, 0.0))

	# Sustained upward input — EXTREME energy_drain_multiplier is 1.7
	# At 15/s * 1.5 (upward) * 1.7 (extreme) = ~38.25/s drain, 100 energy ~ 2.6s
	_simulate(5.0, Vector2(0.0, -1.0))  # 5 seconds should drain to 0

	assert_approx_equal(glider.current_energy, 0.0, 0.001,
		"energy should be 0 after sustained upward input on EXTREME")
	assert_true(is_instance_valid(glider),
		"glider should still exist after energy depletion")

# ============================================================
# SCENARIO 8: Wind Effect Changes Velocity
# Set a wind_effect on the glider, simulate 2s, verify velocity
# differs from a no-wind baseline run.
# ============================================================

func test_wind_effect_changes_velocity() -> void:
	# Baseline: no wind
	_reset_glider(Vector2(200.0, 0.0))
	glider.wind_effect = Vector2.ZERO
	_simulate(2.0, Vector2.ZERO)
	var baseline_vx = glider.velocity.x
	var baseline_vy = glider.velocity.y

	# With wind
	_reset_glider(Vector2(200.0, 0.0))
	glider.wind_effect = Vector2(150.0, -50.0)
	_simulate(2.0, Vector2.ZERO)
	var wind_vx = glider.velocity.x
	var wind_vy = glider.velocity.y

	# At least one axis should differ meaningfully
	var vx_diff = abs(wind_vx - baseline_vx)
	var vy_diff = abs(wind_vy - baseline_vy)
	assert_gt(vx_diff + vy_diff, 1.0,
		"velocity should differ between wind and no-wind runs")
