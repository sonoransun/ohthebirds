## test_obstacle_manager.gd — Unit tests for ObstacleManager navigation system
##
## Tests: initial state, performance stats, safe altitude range,
## navigation hints for empty world, navigation assistance toggle,
## and hint generation for unknown obstacle types.
##
## ObstacleManager is instantiated from its script (not a scene) and
## depends on the GameManager autoload for state queries.

extends TestBase

# ============================================================
# MANAGER SETUP
# ============================================================

var manager: ObstacleManager

func setup() -> void:
	GameManager.return_to_menu()
	manager = ObstacleManager.new()
	add_child(manager)

func teardown() -> void:
	if is_instance_valid(manager):
		manager.queue_free()
	manager = null
	GameManager.return_to_menu()

# ============================================================
# INITIAL STATE TESTS
# ============================================================

func test_initial_state() -> void:
	# No obstacles tracked at startup
	assert_equal(manager.active_obstacles.size(), 0,
		"active_obstacles should be empty on init")
	assert_equal(manager.upcoming_obstacles.size(), 0,
		"upcoming_obstacles should be empty on init")
	assert_equal(manager.obstacle_clusters.size(), 0,
		"obstacle_clusters should be empty on init")
	# Hint cooldown: last_hint_time starts at 0
	assert_approx_equal(manager.last_hint_time, 0.0, 0.01,
		"last_hint_time should be 0 initially")
	# Navigation hints enabled by default
	assert_true(manager.show_navigation_hints,
		"navigation hints should be enabled by default")

# ============================================================
# PERFORMANCE STATS
# ============================================================

func test_performance_stats_returns_dict() -> void:
	var stats = manager.get_performance_stats()
	assert_true(stats is Dictionary, "get_performance_stats should return a Dictionary")
	assert_true(stats.has("obstacles_passed"), "stats should have 'obstacles_passed'")
	assert_true(stats.has("perfect_navigations"), "stats should have 'perfect_navigations'")
	assert_true(stats.has("close_calls"), "stats should have 'close_calls'")
	assert_true(stats.has("skill_level"), "stats should have 'skill_level'")
	assert_true(stats.has("active_obstacles"), "stats should have 'active_obstacles'")
	assert_true(stats.has("upcoming_obstacles"), "stats should have 'upcoming_obstacles'")

# ============================================================
# SAFE ALTITUDE RANGE
# ============================================================

func test_get_safe_altitude_range() -> void:
	# Returns a Vector2 where x = min_safe, y = max_safe
	var altitude_range = manager.get_safe_altitude_range()
	assert_true(altitude_range is Vector2,
		"get_safe_altitude_range should return a Vector2")
	# min_safe (x) should be less than max_safe (y)
	assert_lt(altitude_range.x, altitude_range.y,
		"min safe altitude should be less than max safe altitude")
	# Defaults are max(min_safe, 100) and min(max_safe, 900)
	assert_gte(altitude_range.x, 100.0,
		"min safe altitude should be at least 100")
	assert_lte(altitude_range.y, 900.0,
		"max safe altitude should be at most 900")

# ============================================================
# NAVIGATION HINT TESTS
# ============================================================

func test_navigation_hint_for_position_with_no_obstacles() -> void:
	# With no upcoming obstacles, hint should be an empty string
	var hint = manager.get_navigation_hint_for_position(Vector2(400.0, 300.0))
	assert_equal(hint, "",
		"hint should be empty string when no obstacles are tracked")

func test_enable_navigation_assistance() -> void:
	# Disable then re-enable navigation assistance without crash
	manager.enable_navigation_assistance(false)
	assert_false(manager.show_navigation_hints,
		"navigation hints should be disabled after passing false")
	manager.enable_navigation_assistance(true)
	assert_true(manager.show_navigation_hints,
		"navigation hints should be enabled after passing true")

func test_unknown_obstacle_returns_generic_hint() -> void:
	# generate_hint_for_obstacle returns "OBSTACLE AHEAD" for non-Volcano/Spire nodes
	var dummy_obstacle = Node2D.new()
	add_child(dummy_obstacle)
	var hint = manager.generate_hint_for_obstacle(dummy_obstacle)
	assert_equal(hint, "OBSTACLE AHEAD",
		"unknown obstacle type should produce generic 'OBSTACLE AHEAD' hint")
	dummy_obstacle.queue_free()
