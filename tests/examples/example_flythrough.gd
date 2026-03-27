## example_flythrough.gd — Annotated reference template for physics simulation tests
##
## COPY THIS FILE to tests/integration/test_your_scenario.gd and adapt it.
##
## Fly-through tests simulate the game physics loop by:
##   1. Instantiating SugarGlider from its .tscn
##   2. Setting initial physics state (velocity, energy, etc.)
##   3. Injecting input directly into InputManager
##   4. Advancing time by calling _physics_process(dt) in a loop
##   5. Asserting the resulting state
##
## This gives you deterministic, fast tests without real-time waiting.
## 300 frames at 1/60s = 5 simulated seconds in a few milliseconds.

extends TestBase

# ============================================================
# LIFECYCLE
# ============================================================

var glider: SugarGlider

func setup() -> void:
	GameManager.set_difficulty_preset(GameManager.DifficultyPreset.NORMAL)
	GameManager.start_new_game()

	glider = _spawn_glider()

	# IMPORTANT: Pause InputManager's _process to prevent the smoothing system
	# from fighting against our directly-injected test input values.
	InputManager.set_process(false)
	InputManager.input_direction = Vector2.ZERO
	InputManager._is_input_active = false

func teardown() -> void:
	if is_instance_valid(glider):
		glider.queue_free()
	glider = null

	# Always restore InputManager to normal operation
	InputManager.input_direction = Vector2.ZERO
	InputManager._is_input_active = false
	InputManager.set_process(true)

	GameManager.return_to_menu()
	GameManager.set_difficulty_preset(GameManager.DifficultyPreset.NORMAL)
	get_tree().paused = false

# ============================================================
# HELPERS — copy these into your test file
# ============================================================

## Instantiate a SugarGlider from the scene and add it to the tree.
## Physics methods (move_and_slide, etc.) require the node to be in the scene tree.
func _spawn_glider(initial_velocity: Vector2 = Vector2(200.0, 0.0)) -> SugarGlider:
	var g: SugarGlider = load("res://scenes/player/SugarGlider.tscn").instantiate()
	add_child(g)  # This triggers _ready() — sets up internal references
	g.velocity = initial_velocity
	g.current_energy = g.MAX_ENERGY
	g.is_stunned = false
	g.evasion_mode = false
	return g

## Inject directional input directly, bypassing the smoothing system.
## dir: Vector2 — direction to inject (should be normalized or zero)
func _inject_input(dir: Vector2) -> void:
	InputManager.input_direction = dir
	InputManager._is_input_active = (dir != Vector2.ZERO)

## Advance physics simulation for `seconds` seconds.
## Optional: pass a direction to inject during the simulation.
func _simulate(seconds: float, dir: Vector2 = Vector2.ZERO) -> void:
	_inject_input(dir)
	var frames := int(seconds * 60.0)
	var dt := 1.0 / 60.0
	for _i in frames:
		glider._physics_process(dt)

## Reset glider state without re-instantiating.
## Useful when you want to run the same scenario twice (e.g., EASY vs EXTREME).
func _reset_glider(vel: Vector2 = Vector2(200.0, 0.0)) -> void:
	glider.velocity = vel
	glider.current_energy = glider.MAX_ENERGY
	glider.is_stunned = false
	glider.evasion_mode = false
	glider.wind_effect = Vector2.ZERO
	glider.in_thermal = false

# ============================================================
# EXAMPLE SCENARIOS
# ============================================================

func test_example_basic_glide() -> void:
	# Scenario: glider passive flight for 2 seconds
	# Expected: gravity accumulates, energy regens slightly

	glider.current_energy = glider.MAX_ENERGY * 0.8
	glider.velocity = Vector2(200.0, 0.0)

	_simulate(2.0)  # 2 seconds, no input

	# After 2 passive seconds, energy should have recovered some
	assert_gt(glider.current_energy, glider.MAX_ENERGY * 0.8,
		"passive flight should regenerate energy")

func test_example_comparing_two_presets() -> void:
	# Pattern: run same scenario with two different difficulty presets,
	# assert that the harder one produces a more difficult outcome.

	# Run with EASY
	GameManager.set_difficulty_preset(GameManager.DifficultyPreset.EASY)
	_reset_glider(Vector2(300.0, 0.0))
	_simulate(3.0, Vector2(0.0, -1.0))  # 3s climbing
	var energy_easy := glider.current_energy

	# Run with HARD
	GameManager.set_difficulty_preset(GameManager.DifficultyPreset.HARD)
	_reset_glider(Vector2(300.0, 0.0))
	_simulate(3.0, Vector2(0.0, -1.0))  # Identical 3s climbing
	var energy_hard := glider.current_energy

	# EASY should drain less than HARD
	assert_gt(energy_easy, energy_hard,
		"EASY mode should leave more energy than HARD after identical climb")

func test_example_multi_phase_scenario() -> void:
	# Multi-phase: first drain, then regen, assert at each checkpoint

	# Phase 1: drain
	_simulate(5.0, Vector2(0.0, -1.0))
	var energy_after_drain := glider.current_energy
	assert_lt(energy_after_drain, glider.MAX_ENERGY,
		"energy should have drained during phase 1")

	# Phase 2: regen
	_simulate(3.0, Vector2.ZERO)
	assert_gt(glider.current_energy, energy_after_drain,
		"energy should recover during passive phase 2")

func test_example_reading_physics_state() -> void:
	# Access physics state directly from the glider object
	glider.velocity = Vector2(250.0, -100.0)

	# SugarGlider.get_debug_info() returns a comprehensive state snapshot
	var info := glider.get_debug_info()
	assert_not_null(info, "debug info should not be null")
	assert_true(info.has("velocity"), "debug info should include velocity")
	assert_true(info.has("energy"), "debug info should include energy")
	assert_true(info.has("is_gliding"), "debug info should include gliding state")
	assert_true(info.has("evasion_mode"), "debug info should include evasion state")

# ============================================================
# USEFUL CONSTANTS FROM SUGAR GLIDER (for assertions)
# ============================================================
# glider.MAX_ENERGY          = 100.0
# glider.ENERGY_DRAIN_RATE   = 15.0  (per second, active input)
# glider.ENERGY_REGEN_RATE   = 8.0   (per second, passive)
# glider.LOW_ENERGY_THRESHOLD = 20.0
# glider.MIN_GLIDE_SPEED     = 100.0
# glider.MAX_GLIDE_SPEED     = 600.0
# glider.MAX_FALL_SPEED      = 800.0
# glider.GRAVITY             = 980.0
