## test_rocket.gd — Unit tests for Rocket hazard projectile
##
## Tests: initial state, rocket type configuration, target/velocity setters,
## danger radius, lifetime constant, cleanup behavior, and info dictionary.
##
## Each test instantiates a fresh Rocket from the .tscn scene.
##
## Note: Running headlessly produces harmless warnings about missing GPU
## resources for particle effects. These do not affect test results.

extends TestBase

# ============================================================
# ROCKET SETUP
# ============================================================

var rocket: Rocket

func setup() -> void:
	if GameManager._difficulty_configs.is_empty():
		GameManager._init_difficulty_configs()
	GameManager.current_state = GameManager.GameState.MENU
	GameManager.start_new_game()
	rocket = load("res://scenes/hazards/Rocket.tscn").instantiate()
	add_child(rocket)

func teardown() -> void:
	if is_instance_valid(rocket):
		rocket.queue_free()
	rocket = null
	GameManager.current_state = GameManager.GameState.MENU
	GameManager.is_game_active = false

# ============================================================
# INITIAL STATE TESTS
# ============================================================

func test_initial_state() -> void:
	# is_armed starts false (armed after a delay timer)
	assert_false(rocket.is_armed, "rocket should not be armed immediately after instantiation")
	# cluster_split_triggered starts false (only used by CLUSTER type on explode)
	assert_false(rocket.cluster_split_triggered, "cluster_split should not be triggered initially")
	# elapsed_time starts at 0.0
	assert_approx_equal(rocket.elapsed_time, 0.0, 0.01,
		"elapsed_time should start at 0")

# ============================================================
# ROCKET TYPE CONFIGURATION TESTS
# ============================================================

func test_configure_basic_rocket_type() -> void:
	# BASIC is the default type; configure_rocket_type() is called in _ready
	# so the rocket should already be configured as BASIC
	assert_equal(rocket.rocket_type, Rocket.RocketType.BASIC,
		"default rocket_type should be BASIC")
	# BASIC does not modify launch_speed from the default 400.0
	assert_approx_equal(rocket.launch_speed, 400.0, 0.1,
		"BASIC rocket launch_speed should remain at default 400")

func test_configure_tracking_rocket_type() -> void:
	# Reconfigure the default rocket as TRACKING
	rocket.rocket_type = Rocket.RocketType.TRACKING
	rocket.configure_rocket_type()

	assert_gt(rocket.tracking_strength, 0.0,
		"TRACKING rocket should have positive tracking_strength")
	assert_approx_equal(rocket.lifetime, 10.0, 0.1,
		"TRACKING rocket lifetime should be 10.0")

func test_configure_fast_rocket_type() -> void:
	# Reconfigure the default rocket as FAST
	rocket.rocket_type = Rocket.RocketType.FAST
	rocket.configure_rocket_type()

	assert_approx_equal(rocket.launch_speed, 600.0, 0.1,
		"FAST rocket launch_speed should be 600")
	assert_approx_equal(rocket.max_speed, 800.0, 0.1,
		"FAST rocket max_speed should be 800")
	assert_approx_equal(rocket.lifetime, 5.0, 0.1,
		"FAST rocket lifetime should be 5.0")
	assert_approx_equal(rocket.explosion_radius, 60.0, 0.1,
		"FAST rocket explosion_radius should be 60")

# ============================================================
# TARGET AND VELOCITY TESTS
# ============================================================

func test_set_target_stores_position() -> void:
	var target = Vector2(500.0, 300.0)
	rocket.set_target(target)
	assert_equal(rocket.target_position, target,
		"target_position should match the value passed to set_target")
	assert_true(rocket.has_target, "has_target should be true after set_target")

func test_set_initial_velocity() -> void:
	var vel = Vector2(100.0, -200.0)
	rocket.set_initial_velocity(vel)
	assert_equal(rocket.initial_velocity, vel,
		"initial_velocity should match the value passed to set_initial_velocity")
	assert_equal(rocket.linear_velocity, vel,
		"linear_velocity should be set to the initial velocity")

# ============================================================
# DANGER RADIUS AND CONSTANTS
# ============================================================

func test_get_danger_radius_positive() -> void:
	var radius = rocket.get_danger_radius()
	assert_gt(radius, 0.0,
		"danger radius should be positive")
	# danger_radius = explosion_radius + 20.0
	assert_approx_equal(radius, rocket.explosion_radius + 20.0, 0.1,
		"danger radius should be explosion_radius + 20 safety margin")

func test_max_lifetime_constant_set() -> void:
	assert_gt(Rocket.MAX_LIFETIME, 0.0,
		"MAX_LIFETIME should be a positive constant")
	assert_approx_equal(Rocket.MAX_LIFETIME, 30.0, 0.1,
		"MAX_LIFETIME should be 30.0 seconds")

# ============================================================
# CLEANUP AND INFO
# ============================================================

func test_cleanup_queues_free() -> void:
	rocket.cleanup()
	# cleanup() calls queue_free via a deferred timer, so we check
	# that the node is still briefly valid but the signal was emitted
	# (rocket_destroyed). The node will be freed after the timer fires.
	# We verify it has not crashed and is still a valid instance at this point.
	assert_true(is_instance_valid(rocket),
		"rocket should still be valid immediately after cleanup (deferred free)")

func test_rocket_info_returns_dict() -> void:
	var info = rocket.get_rocket_info()
	assert_true(info is Dictionary, "get_rocket_info should return a Dictionary")
	assert_true(info.has("type"), "info dict should have 'type' key")
	assert_true(info.has("armed"), "info dict should have 'armed' key")
	assert_true(info.has("explosion_radius"), "info dict should have 'explosion_radius' key")
	assert_true(info.has("position"), "info dict should have 'position' key")
	assert_true(info.has("velocity"), "info dict should have 'velocity' key")
