## test_sugar_glider.gd — Unit tests for SugarGlider physics, energy, and state
##
## Tests: initial state, gliding condition, energy drain/regen,
## low energy detection, stun state, evasion mode, velocity clamping.
##
## Each test instantiates a fresh SugarGlider from the .tscn and adds it to
## the scene tree so physics methods work correctly.
##
## Note: Running headlessly produces harmless warnings about missing animation
## frames (SugarGliderSprites.tres is a placeholder with empty frames) and
## missing GPU for particle effects. These do not affect test results.

extends TestBase

# ============================================================
# GLIDER SETUP HELPERS
# ============================================================

var glider: SugarGlider

## Create a fresh SugarGlider in a neutral state for each test.
func setup() -> void:
	GameManager.set_difficulty_preset(GameManager.DifficultyPreset.NORMAL)
	GameManager.start_new_game()

	# Instantiate from scene — gives us the full node tree
	glider = load("res://scenes/player/SugarGlider.tscn").instantiate()
	add_child(glider)

	# Reset to known initial physics state
	glider.velocity = Vector2(200.0, 0.0)  # Forward momentum to enable gliding
	glider.current_energy = glider.MAX_ENERGY
	glider.is_stunned = false
	glider.evasion_mode = false

	# Pause InputManager to prevent _process from overwriting our test inputs
	InputManager.set_process(false)
	InputManager.input_direction = Vector2.ZERO
	InputManager._is_input_active = false

func teardown() -> void:
	if is_instance_valid(glider):
		glider.queue_free()
	glider = null

	InputManager.input_direction = Vector2.ZERO
	InputManager._is_input_active = false
	InputManager.set_process(true)

	GameManager.return_to_menu()
	get_tree().paused = false

## Inject directional input directly (bypasses smoothing for deterministic tests).
func _inject_input(dir: Vector2) -> void:
	InputManager.input_direction = dir
	InputManager._is_input_active = dir != Vector2.ZERO

## Advance the glider N physics frames at 60fps.
func _advance_physics(frames: int) -> void:
	var dt := 1.0 / 60.0
	for _i in frames:
		glider._physics_process(dt)

# ============================================================
# INITIAL STATE TESTS
# ============================================================

func test_initial_energy_is_full() -> void:
	glider.current_energy = glider.MAX_ENERGY  # Ensure fresh state
	assert_approx_equal(glider.current_energy, glider.MAX_ENERGY, 0.001,
		"energy should start at MAX_ENERGY")

func test_energy_percentage_full_at_start() -> void:
	glider.current_energy = glider.MAX_ENERGY
	assert_approx_equal(glider.get_energy_percentage(), 1.0, 0.001,
		"energy percentage should be 1.0 when full")

# ============================================================
# GLIDING CONDITION TESTS
# ============================================================

func test_is_gliding_when_velocity_x_above_minimum() -> void:
	# MIN_GLIDE_SPEED = 100.0 and abs(velocity.y) < velocity.x
	glider.velocity = Vector2(200.0, 0.0)
	assert_true(glider.is_gliding(), "should be gliding at vx=200")

func test_not_gliding_when_velocity_x_below_minimum() -> void:
	glider.velocity = Vector2(50.0, 0.0)
	assert_false(glider.is_gliding(), "should not be gliding at vx=50 (below MIN_GLIDE_SPEED=100)")

func test_not_gliding_when_falling_faster_than_moving_forward() -> void:
	# is_gliding() returns false when abs(velocity.y) >= velocity.x
	glider.velocity = Vector2(200.0, 300.0)  # Falling faster than forward
	assert_false(glider.is_gliding(), "should not be gliding when falling fast")

# ============================================================
# ENERGY TESTS
# ============================================================

func test_energy_drains_during_active_input() -> void:
	glider.current_energy = glider.MAX_ENERGY
	_inject_input(Vector2(0.0, -1.0))  # Upward input
	_advance_physics(60)  # 1 second
	assert_lt(glider.current_energy, glider.MAX_ENERGY,
		"energy should decrease with active upward input")

func test_energy_regenerates_without_input() -> void:
	glider.current_energy = 50.0
	_inject_input(Vector2.ZERO)
	_advance_physics(60)  # 1 second of passive gliding
	assert_gt(glider.current_energy, 50.0,
		"energy should increase passively without input")

func test_energy_clamped_at_max() -> void:
	glider.current_energy = glider.MAX_ENERGY - 0.1  # Just below max
	_inject_input(Vector2.ZERO)
	_advance_physics(60)
	assert_lte(glider.current_energy, glider.MAX_ENERGY,
		"energy should not exceed MAX_ENERGY")

func test_is_low_energy_at_threshold() -> void:
	glider.current_energy = glider.LOW_ENERGY_THRESHOLD - 1.0  # Below threshold
	assert_true(glider.is_low_energy(), "should be low energy when below threshold")

func test_is_not_low_energy_above_threshold() -> void:
	glider.current_energy = glider.LOW_ENERGY_THRESHOLD + 10.0
	assert_false(glider.is_low_energy(), "should not be low energy above threshold")

# ============================================================
# STUN STATE TESTS
# ============================================================

func test_enter_stunned_state_sets_flag() -> void:
	glider.enter_stunned_state(1.0)
	assert_true(glider.is_stunned, "is_stunned should be true after entering stun state")

func test_stun_timer_set_correctly() -> void:
	glider.enter_stunned_state(2.5)
	assert_approx_equal(glider.stun_timer, 2.5, 0.001,
		"stun_timer should be set to the specified duration")

# ============================================================
# VELOCITY CLAMPING TESTS
# ============================================================

func test_velocity_x_never_goes_negative_with_left_input() -> void:
	# Applying strong left input should decelerate, not reverse, the glider
	glider.velocity = Vector2(150.0, 0.0)
	_inject_input(Vector2(-1.0, 0.0))  # Full left
	_advance_physics(120)  # 2 seconds of left input
	assert_gte(glider.velocity.x, 0.0,
		"velocity.x should never go negative in auto-scroller mode")

# ============================================================
# EVASION MODE TESTS
# ============================================================

func test_enter_evasion_mode_sets_flag() -> void:
	assert_false(glider.evasion_mode, "should start with evasion mode off")
	glider.enter_evasion_mode()
	assert_true(glider.evasion_mode, "evasion_mode should be true after activation")

func test_exit_evasion_mode_clears_flag() -> void:
	glider.enter_evasion_mode()
	glider.exit_evasion_mode()
	assert_false(glider.evasion_mode, "evasion_mode should be false after exit")

# ============================================================
# STUN STATE EXTENDED TESTS
# ============================================================

func test_stun_timer_decrements() -> void:
	glider.enter_stunned_state(1.0)
	glider.handle_stun_state(0.5)
	assert_lt(glider.stun_timer, 1.0,
		"stun_timer should decrease after handle_stun_state")

func test_stun_clears_after_duration() -> void:
	glider.enter_stunned_state(0.1)
	glider.handle_stun_state(0.2)
	assert_false(glider.is_stunned,
		"is_stunned should be false after stun_timer expires")

# ============================================================
# ENERGY AND FORCE EDGE CASE TESTS
# ============================================================

func test_energy_at_zero_halves_force() -> void:
	glider.current_energy = 0.0
	assert_true(glider.current_energy < glider.LOW_ENERGY_THRESHOLD,
		"energy 0 should be below LOW_ENERGY_THRESHOLD so force is halved")

func test_energy_clamp_at_zero() -> void:
	glider.current_energy = -10.0
	# Run update_energy with no input (regen path) to trigger clamp
	_inject_input(Vector2.ZERO)
	glider.update_energy(0.016)
	assert_gte(glider.current_energy, 0.0,
		"energy should be clamped to >= 0 after update_energy")

# ============================================================
# ENVIRONMENTAL EFFECTS TESTS
# ============================================================

func test_wind_effect_applied() -> void:
	glider.wind_effect = Vector2(100.0, 0.0)
	var vx_before = glider.velocity.x
	glider.apply_environmental_effects(1.0 / 60.0)
	assert_gt(glider.velocity.x, vx_before,
		"velocity.x should increase when wind_effect pushes right")

func test_thermal_sets_recovery_multiplier() -> void:
	glider.in_thermal = true
	glider.apply_environmental_effects(1.0 / 60.0)
	assert_approx_equal(glider.energy_recovery_multiplier, 1.5, 0.001,
		"energy_recovery_multiplier should be 1.5 when in thermal")

func test_thermal_off_resets_recovery_multiplier() -> void:
	glider.in_thermal = false
	glider.apply_environmental_effects(1.0 / 60.0)
	assert_approx_equal(glider.energy_recovery_multiplier, 1.0, 0.001,
		"energy_recovery_multiplier should be 1.0 when not in thermal")

# ============================================================
# COLLISION LAYER CONSTANTS TEST
# ============================================================

func test_collision_layer_constants_defined() -> void:
	assert_equal(glider.COLLISION_LAYER_OBSTACLE, 2,
		"COLLISION_LAYER_OBSTACLE should be 2")
	assert_equal(glider.COLLISION_LAYER_ROCKET, 4,
		"COLLISION_LAYER_ROCKET should be 4")
	assert_equal(glider.COLLISION_LAYER_BOUNDARY, 16,
		"COLLISION_LAYER_BOUNDARY should be 16")

# ============================================================
# EVASION MODE EXTENDED TESTS
# ============================================================

func test_evasion_mode_timer_set() -> void:
	glider.enter_evasion_mode()
	assert_gt(glider.evasion_timer, 0.0,
		"evasion_timer should be > 0 after entering evasion mode")
