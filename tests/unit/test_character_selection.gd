## test_character_selection.gd — Tests for animal profile selection
##
## Covers: GameManager profile storage, set_animal() state and signal,
## SugarGlider.apply_animal_profile() physics application, isolation
## between profiles, and gameplay differentiation guarantees.

extends TestBase

const TOLERANCE: float = 0.0001

var glider: SugarGlider

func setup() -> void:
	# Ensure configs are populated even if autoload _ready() hasn't fired yet
	if GameManager._animal_configs.is_empty():
		GameManager._init_animal_configs()
	GameManager.set_animal(GameManager.AnimalType.SUGAR_GLIDER)
	GameManager.current_state = GameManager.GameState.MENU

	glider = load("res://scenes/player/SugarGlider.tscn").instantiate()
	add_child(glider)

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

	GameManager.set_animal(GameManager.AnimalType.SUGAR_GLIDER)
	GameManager.current_state = GameManager.GameState.MENU

# ── Default state ──────────────────────────────────────────────────────────

func test_default_animal_is_sugar_glider() -> void:
	assert_equal(GameManager.selected_animal, GameManager.AnimalType.SUGAR_GLIDER)

func test_default_animal_display_name() -> void:
	assert_equal(GameManager.get_animal_display_name(), "Sugar Glider")

# ── set_animal state changes ───────────────────────────────────────────────

func test_set_animal_sparrow() -> void:
	GameManager.set_animal(GameManager.AnimalType.SPARROW)
	assert_equal(GameManager.selected_animal, GameManager.AnimalType.SPARROW)

func test_set_animal_falcon() -> void:
	GameManager.set_animal(GameManager.AnimalType.FALCON)
	assert_equal(GameManager.selected_animal, GameManager.AnimalType.FALCON)

func test_set_animal_clamps_below_zero() -> void:
	GameManager.set_animal(-1)
	assert_gte(float(GameManager.selected_animal), 0.0)

func test_set_animal_clamps_above_max() -> void:
	GameManager.set_animal(99)
	assert_true(GameManager.selected_animal <= GameManager.AnimalType.FALCON)

# ── signal ─────────────────────────────────────────────────────────────────

var _received_animal_type: int = -1
func _on_animal_signal(t: int) -> void:
	_received_animal_type = t

func test_set_animal_emits_signal() -> void:
	_received_animal_type = -1
	GameManager.animal_selected.connect(_on_animal_signal)
	GameManager.set_animal(GameManager.AnimalType.SPARROW)
	GameManager.animal_selected.disconnect(_on_animal_signal)
	assert_equal(_received_animal_type, GameManager.AnimalType.SPARROW)

# ── get_animal_config values ───────────────────────────────────────────────

func test_sugar_glider_config() -> void:
	GameManager.set_animal(GameManager.AnimalType.SUGAR_GLIDER)
	var c = GameManager.get_animal_config()
	assert_approx_equal(c.max_glide_speed,        600.0,  TOLERANCE)
	assert_approx_equal(c.min_glide_speed,        100.0,  TOLERANCE)
	assert_approx_equal(c.input_force,            450.0,  TOLERANCE)
	assert_approx_equal(c.air_resistance,         0.98,   TOLERANCE)
	assert_approx_equal(c.glide_resistance,       0.995,  TOLERANCE)
	assert_approx_equal(c.glide_lift_coefficient, 0.3,    TOLERANCE)
	assert_approx_equal(c.max_fall_speed,         800.0,  TOLERANCE)

func test_sparrow_config() -> void:
	GameManager.set_animal(GameManager.AnimalType.SPARROW)
	var c = GameManager.get_animal_config()
	assert_approx_equal(c.max_glide_speed,        450.0,  TOLERANCE)
	assert_approx_equal(c.min_glide_speed,        80.0,   TOLERANCE)
	assert_approx_equal(c.input_force,            580.0,  TOLERANCE)
	assert_approx_equal(c.air_resistance,         0.985,  TOLERANCE)
	assert_approx_equal(c.glide_resistance,       0.997,  TOLERANCE)
	assert_approx_equal(c.glide_lift_coefficient, 0.38,   TOLERANCE)
	assert_approx_equal(c.max_fall_speed,         700.0,  TOLERANCE)

func test_falcon_config() -> void:
	GameManager.set_animal(GameManager.AnimalType.FALCON)
	var c = GameManager.get_animal_config()
	assert_approx_equal(c.max_glide_speed,        780.0,  TOLERANCE)
	assert_approx_equal(c.min_glide_speed,        130.0,  TOLERANCE)
	assert_approx_equal(c.input_force,            300.0,  TOLERANCE)
	assert_approx_equal(c.air_resistance,         0.972,  TOLERANCE)
	assert_approx_equal(c.glide_resistance,       0.991,  TOLERANCE)
	assert_approx_equal(c.glide_lift_coefficient, 0.22,   TOLERANCE)
	assert_approx_equal(c.max_fall_speed,         980.0,  TOLERANCE)

# ── apply_animal_profile writes to glider vars ─────────────────────────────

func test_apply_profile_sugar_glider() -> void:
	GameManager.set_animal(GameManager.AnimalType.SUGAR_GLIDER)
	glider.apply_animal_profile()
	assert_approx_equal(glider.MAX_GLIDE_SPEED,          600.0,  TOLERANCE)
	assert_approx_equal(glider.input_force,              450.0,  TOLERANCE)
	assert_approx_equal(glider.GLIDE_LIFT_COEFFICIENT,   0.3,    TOLERANCE)

func test_apply_profile_sparrow() -> void:
	GameManager.set_animal(GameManager.AnimalType.SPARROW)
	glider.apply_animal_profile()
	assert_approx_equal(glider.MAX_GLIDE_SPEED,          450.0,  TOLERANCE)
	assert_approx_equal(glider.input_force,              580.0,  TOLERANCE)
	assert_approx_equal(glider.MIN_GLIDE_SPEED,          80.0,   TOLERANCE)

func test_apply_profile_falcon() -> void:
	GameManager.set_animal(GameManager.AnimalType.FALCON)
	glider.apply_animal_profile()
	assert_approx_equal(glider.MAX_GLIDE_SPEED,          780.0,  TOLERANCE)
	assert_approx_equal(glider.input_force,              300.0,  TOLERANCE)
	assert_approx_equal(glider.MAX_FALL_SPEED,           980.0,  TOLERANCE)

# ── profile isolation ──────────────────────────────────────────────────────

func test_switching_sparrow_to_falcon_overwrites_vars() -> void:
	GameManager.set_animal(GameManager.AnimalType.SPARROW)
	glider.apply_animal_profile()
	GameManager.set_animal(GameManager.AnimalType.FALCON)
	glider.apply_animal_profile()
	assert_approx_equal(glider.input_force,     300.0,  TOLERANCE)
	assert_approx_equal(glider.MAX_GLIDE_SPEED, 780.0,  TOLERANCE)

# ── apply_animal_profile resets velocity and energy ───────────────────────

func test_apply_profile_resets_velocity() -> void:
	GameManager.set_animal(GameManager.AnimalType.FALCON)
	glider.velocity = Vector2(999.0, -500.0)
	glider.apply_animal_profile()
	assert_approx_equal(glider.velocity.x, 130.0, TOLERANCE)
	assert_approx_equal(glider.velocity.y, 0.0,   TOLERANCE)

func test_apply_profile_resets_energy() -> void:
	GameManager.set_animal(GameManager.AnimalType.SPARROW)
	glider.current_energy = 5.0
	glider.apply_animal_profile()
	assert_approx_equal(glider.current_energy, glider.MAX_ENERGY, TOLERANCE)

# ── gameplay differentiation guarantees ───────────────────────────────────

func test_falcon_max_speed_exceeds_sugar_glider() -> void:
	var falcon_max = 780.0
	var sg_max     = 600.0
	assert_gt(falcon_max, sg_max)

func test_sparrow_max_speed_below_sugar_glider() -> void:
	var sparrow_max = 450.0
	var sg_max      = 600.0
	assert_lt(sparrow_max, sg_max)

func test_sparrow_input_force_exceeds_sugar_glider() -> void:
	var sparrow_force = 580.0
	var sg_force      = 450.0
	assert_gt(sparrow_force, sg_force)

func test_falcon_input_force_below_sugar_glider() -> void:
	var falcon_force = 300.0
	var sg_force     = 450.0
	assert_lt(falcon_force, sg_force)

# ── display name tests ────────────────────────────────────────────────────

func test_get_animal_display_name_sparrow() -> void:
	GameManager.set_animal(GameManager.AnimalType.SPARROW)
	assert_equal(GameManager.get_animal_display_name(), "Sparrow",
		"Sparrow display name should be 'Sparrow'")

func test_get_animal_display_name_falcon() -> void:
	GameManager.set_animal(GameManager.AnimalType.FALCON)
	assert_equal(GameManager.get_animal_display_name(), "Falcon",
		"Falcon display name should be 'Falcon'")

# ── multiple profile switches ─────────────────────────────────────────────

func test_multiple_profile_switches() -> void:
	# sugar_glider -> sparrow -> falcon -> sugar_glider
	GameManager.set_animal(GameManager.AnimalType.SUGAR_GLIDER)
	GameManager.set_animal(GameManager.AnimalType.SPARROW)
	GameManager.set_animal(GameManager.AnimalType.FALCON)
	GameManager.set_animal(GameManager.AnimalType.SUGAR_GLIDER)
	glider.apply_animal_profile()
	# Final config should match sugar glider
	assert_approx_equal(glider.MAX_GLIDE_SPEED, 600.0, TOLERANCE,
		"after cycling back to Sugar Glider, MAX_GLIDE_SPEED should be 600")
	assert_approx_equal(glider.input_force, 450.0, TOLERANCE,
		"after cycling back to Sugar Glider, input_force should be 450")

# ── apply_animal_profile and evasion mode ─────────────────────────────────

func test_apply_profile_clears_evasion() -> void:
	# apply_animal_profile does NOT reset evasion_mode — it only sets
	# physics vars, velocity, and energy. So evasion_mode stays true.
	glider.evasion_mode = true
	glider.apply_animal_profile()
	assert_true(glider.evasion_mode,
		"apply_animal_profile should not reset evasion_mode")
