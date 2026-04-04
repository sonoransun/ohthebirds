## test_scrolling_manager.gd — Tests for ScrollingManager scrolling and tracking API
##
## Tests: initial scroll speed, getter return values, pause/resume,
## distance tracking, speed multiplier, and thermal zone queries.
##
## ScrollingManager is instantiated from its script and added to the tree.
## Node references (parallax, terrain generator, player) will be absent,
## which is fine — the public API still works on its own internal state.

extends TestBase

var manager: ScrollingManager

# ============================================================
# LIFECYCLE
# ============================================================

func setup() -> void:
	manager = ScrollingManager.new()
	# Prevent _ready from connecting to GameManager signals that may
	# interfere with other tests. We call initialize_scrolling manually.
	add_child(manager)

func teardown() -> void:
	if is_instance_valid(manager):
		manager.queue_free()
	manager = null

# ============================================================
# SCROLL SPEED TESTS
# ============================================================

func test_initial_scroll_speed() -> void:
	assert_approx_equal(manager.base_scroll_speed, 200.0, 0.01,
		"base_scroll_speed should default to 200.0")
	assert_approx_equal(manager.current_scroll_speed, 200.0, 0.01,
		"current_scroll_speed should initialize to base_scroll_speed")

func test_get_scroll_speed_returns_float() -> void:
	var speed = manager.get_scroll_speed()
	assert_true(speed is float,
		"get_scroll_speed should return a float")
	assert_approx_equal(speed, manager.current_scroll_speed, 0.01,
		"get_scroll_speed should match current_scroll_speed")

# ============================================================
# PAUSE / RESUME TESTS
# ============================================================

func test_pause_scrolling_stops_processing() -> void:
	manager.pause_scrolling()
	assert_false(manager.is_processing(),
		"pause_scrolling should disable _process via set_process(false)")

func test_resume_scrolling_restores_processing() -> void:
	manager.pause_scrolling()
	manager.resume_scrolling()
	assert_true(manager.is_processing(),
		"resume_scrolling should re-enable _process via set_process(true)")

# ============================================================
# DISTANCE TRACKING TESTS
# ============================================================

func test_distance_tracking() -> void:
	var distance = manager.get_distance_traveled()
	assert_true(distance is float,
		"get_distance_traveled should return a float")
	assert_approx_equal(distance, 0.0, 0.01,
		"distance_traveled should start at 0.0")

func test_distance_traveled_accumulates() -> void:
	# Manually increment to simulate what update_distance_tracking does
	manager.distance_traveled = 500.0
	assert_approx_equal(manager.get_distance_traveled(), 500.0, 0.01,
		"get_distance_traveled should reflect manually set distance")

# ============================================================
# SPEED MULTIPLIER TEST
# ============================================================

func test_scroll_speed_multiplier() -> void:
	manager.set_scroll_speed_multiplier(2.0)
	assert_approx_equal(manager.current_scroll_speed, manager.base_scroll_speed * 2.0, 0.01,
		"set_scroll_speed_multiplier(2.0) should double the base speed")

func test_scroll_speed_multiplier_fractional() -> void:
	manager.set_scroll_speed_multiplier(0.5)
	assert_approx_equal(manager.current_scroll_speed, manager.base_scroll_speed * 0.5, 0.01,
		"set_scroll_speed_multiplier(0.5) should halve the base speed")

# ============================================================
# THERMAL ZONE TESTS
# ============================================================

func test_is_position_in_thermal_empty_zones() -> void:
	# With no thermals generated, every position should be outside
	manager.thermal_zones.clear()
	assert_false(manager.is_position_in_thermal(Vector2(400, 500)),
		"should return false when no thermal zones exist")

func test_is_position_in_thermal_known_zone() -> void:
	# Manually add a thermal zone and query inside it
	manager.thermal_zones.clear()
	manager.thermal_zones.append(Rect2(100, 100, 200, 200))
	assert_true(manager.is_position_in_thermal(Vector2(200, 200)),
		"should return true for a point inside a manually added thermal zone")
	assert_false(manager.is_position_in_thermal(Vector2(500, 500)),
		"should return false for a point outside the thermal zone")

# ============================================================
# DEBUG / UTILITY TESTS
# ============================================================

func test_get_debug_info_returns_dict() -> void:
	var info = manager.get_debug_info()
	assert_true(info is Dictionary,
		"get_debug_info should return a Dictionary")
	assert_true(info.has("scroll_speed"),
		"debug info should contain scroll_speed key")
	assert_true(info.has("distance_traveled"),
		"debug info should contain distance_traveled key")
	assert_true(info.has("active_chunks"),
		"debug info should contain active_chunks key")

func test_get_active_chunk_count_starts_at_zero() -> void:
	assert_equal(manager.get_active_chunk_count(), 0,
		"active chunk count should be 0 with no chunks loaded")
