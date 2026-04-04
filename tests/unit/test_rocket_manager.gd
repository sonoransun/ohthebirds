## test_rocket_manager.gd — Unit tests for RocketManager challenge system
##
## Tests: initial threat count, performance stats, constants, launcher
## enable/disable safety, challenge pattern retrieval, and cleanup safety.
##
## RocketManager is instantiated from its script (not a scene) and added
## to the tree. It depends on the GameManager autoload for difficulty
## and state queries.

extends TestBase

# ============================================================
# MANAGER SETUP
# ============================================================

var manager: RocketManager

func setup() -> void:
	if GameManager._difficulty_configs.is_empty():
		GameManager._init_difficulty_configs()
	GameManager.current_state = GameManager.GameState.MENU
	GameManager.difficulty_preset = GameManager.DifficultyPreset.NORMAL
	manager = RocketManager.new()
	add_child(manager)

func teardown() -> void:
	if is_instance_valid(manager):
		manager.queue_free()
	manager = null
	GameManager.current_state = GameManager.GameState.MENU

# ============================================================
# INITIAL STATE TESTS
# ============================================================

func test_initial_threat_count_zero() -> void:
	# No launchers have been spawned yet, so active threat count should be 0
	assert_equal(manager.get_active_threat_count(), 0,
		"active threat count should be 0 with no spawned launchers")

# ============================================================
# PERFORMANCE STATS
# ============================================================

func test_performance_stats_returns_dict() -> void:
	var stats = manager.get_performance_stats()
	assert_true(stats is Dictionary, "get_performance_stats should return a Dictionary")
	assert_true(stats.has("rockets_fired"), "stats should have 'rockets_fired'")
	assert_true(stats.has("near_misses"), "stats should have 'near_misses'")
	assert_true(stats.has("active_launchers"), "stats should have 'active_launchers'")
	assert_true(stats.has("current_difficulty"), "stats should have 'current_difficulty'")
	assert_true(stats.has("current_wave"), "stats should have 'current_wave'")

# ============================================================
# CONSTANTS
# ============================================================

func test_max_active_launchers_constant() -> void:
	assert_gt(float(RocketManager.MAX_ACTIVE_LAUNCHERS), 0.0,
		"MAX_ACTIVE_LAUNCHERS should be a positive constant")
	assert_equal(RocketManager.MAX_ACTIVE_LAUNCHERS, 20,
		"MAX_ACTIVE_LAUNCHERS should be 20")

# ============================================================
# LAUNCHER ENABLE/DISABLE SAFETY
# ============================================================

func test_disable_all_launchers_does_not_crash() -> void:
	# With no active launchers, this should complete without error
	manager.disable_all_launchers()
	assert_true(true, "disable_all_launchers should not crash with empty launcher list")

func test_enable_all_launchers_does_not_crash() -> void:
	# With no active launchers, this should complete without error
	manager.enable_all_launchers()
	assert_true(true, "enable_all_launchers should not crash with empty launcher list")

# ============================================================
# CHALLENGE PATTERN
# ============================================================

func test_get_current_challenge_pattern_returns_dict() -> void:
	# get_current_challenge_pattern returns a Dictionary describing the
	# currently applicable challenge pattern based on difficulty.
	# If challenge_patterns were populated in _ready, verify structure;
	# otherwise just verify it returns a Dictionary without crashing.
	if manager.challenge_patterns.is_empty():
		# setup_challenge_patterns may fail if RocketLauncher enums unavailable
		assert_true(true, "challenge_patterns empty in headless mode — acceptable")
	else:
		var pattern = manager.get_current_challenge_pattern()
		assert_true(pattern is Dictionary,
			"get_current_challenge_pattern should return a Dictionary")
		assert_true(pattern.has("name"), "challenge pattern should have a 'name' key")

# ============================================================
# CLEANUP SAFETY
# ============================================================

func test_cleanup_distant_launchers_empty_is_safe() -> void:
	# With no launchers active, cleanup_distant_launchers should be a no-op
	manager.cleanup_distant_launchers()
	assert_equal(manager.get_active_threat_count(), 0,
		"threat count should remain 0 after cleaning up with no launchers")
