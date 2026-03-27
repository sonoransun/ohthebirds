## example_unit_test.gd — Annotated reference template for writing unit tests
##
## COPY THIS FILE to tests/unit/test_your_feature.gd and adapt it.
## Remove the explanatory comments once you understand the pattern.
##
## Unit tests: test one thing in isolation, with fast execution.
## No physics simulation, no scene loading if you can avoid it.
## Target: specific methods, constants, or pure logic.

# ============================================================
# REQUIRED: extend TestBase to get assert methods and auto-discovery
# ============================================================
extends TestBase

# ============================================================
# LIFECYCLE HOOKS
# setup() runs before EACH test method.
# teardown() runs after EACH test method.
# Always restore any global state you touch, so tests don't affect each other.
# ============================================================

func setup() -> void:
	# Put GameManager in a known state before every test
	GameManager.return_to_menu()
	GameManager.current_score = 0
	GameManager.distance_traveled = 0.0
	GameManager.set_difficulty_preset(GameManager.DifficultyPreset.NORMAL)
	get_tree().paused = false

func teardown() -> void:
	# Mirror of setup — undo everything setup did
	GameManager.return_to_menu()
	GameManager.current_score = 0
	GameManager.set_difficulty_preset(GameManager.DifficultyPreset.NORMAL)

# ============================================================
# TEST METHODS
# Name must start with "test_" to be discovered automatically.
# Use descriptive names: test_<what>_<when>_<expected>.
# ============================================================

func test_example_assert_equal() -> void:
	# assert_equal(actual, expected, optional_message)
	# Passes if actual == expected (uses ==)
	var result = 2 + 2
	assert_equal(result, 4, "basic arithmetic should work")

func test_example_assert_approx_equal() -> void:
	# For floats: use assert_approx_equal(actual, expected, tolerance)
	# Never use assert_equal for floats — floating point is imprecise
	var score_multiplier = GameManager.get_score_multiplier()
	assert_approx_equal(score_multiplier, 1.0, 0.001,
		"NORMAL preset score multiplier should be 1.0")

func test_example_assert_true_and_false() -> void:
	# assert_true / assert_false for boolean conditions
	GameManager.start_new_game()
	assert_true(GameManager.is_playing(), "should be playing after start")
	assert_false(GameManager.is_paused(), "should not be paused after start")

func test_example_assert_gt_lt() -> void:
	# assert_gt(actual, than) — actual > than
	# assert_lt(actual, than) — actual < than
	# assert_gte / assert_lte also available
	GameManager.start_new_game()
	GameManager.update_distance(2000.0)
	var difficulty = GameManager.get_difficulty_multiplier()
	assert_gt(difficulty, 1.0, "difficulty should be above base after distance traveled")
	assert_lt(difficulty, 5.0, "difficulty should not be unreasonably high this early")

func test_example_multiple_assertions_in_one_test() -> void:
	# You can have multiple asserts per test when they're all testing the same concept.
	# All failures are collected — execution continues even after a failure.
	GameManager.set_difficulty_preset(GameManager.DifficultyPreset.EASY)
	# Test multiple related values together
	assert_approx_equal(GameManager.get_score_multiplier(), 0.75, 0.001)
	assert_approx_equal(GameManager.get_energy_drain_multiplier(), 0.60, 0.001)
	assert_approx_equal(GameManager.get_scroll_speed_multiplier(), 0.75, 0.001)

# ============================================================
# CAPTURING SIGNALS
# Connect to a signal before the action, record in a variable, assert afterward.
# ============================================================

var _last_state_change: int = -1  # -1 = no signal received yet

func test_example_signal_emission() -> void:
	# Connect to the signal we want to observe
	GameManager.game_state_changed.connect(func(new_state): _last_state_change = new_state)

	GameManager.start_new_game()

	# Assert the signal was emitted with the expected value
	assert_equal(_last_state_change, GameManager.GameState.PLAYING,
		"game_state_changed should fire with PLAYING state")

	# Cleanup: disconnect to avoid affecting other tests
	GameManager.game_state_changed.disconnect(func(_s): pass)
	# Note: use a named callback function for easier disconnection in real tests

# ============================================================
# COMMON PATTERNS
# ============================================================

func test_example_score_with_multiplier() -> void:
	# Test that scoring respects the difficulty multiplier
	GameManager.set_difficulty_preset(GameManager.DifficultyPreset.HARD)
	GameManager.start_new_game()
	GameManager.add_score(100)
	# HARD score multiplier = 1.5x → int(100 * 1.5) = 150
	assert_equal(GameManager.get_current_score(), 150,
		"HARD preset should give 1.5x score")

# ============================================================
# WHAT NOT TO DO
# ============================================================

# DON'T: Test implementation details (internal vars that could change)
# DO:    Test observable behavior (public methods, signals, return values)

# DON'T: Leave global state modified at end of test (always teardown)
# DO:    Reset in teardown() so each test is independent

# DON'T: Assert floats with == (test_example_assert_approx_equal shows the right way)
# DO:    Use assert_approx_equal with a reasonable tolerance

# DON'T: Write one giant test method testing everything
# DO:    Write focused tests: one concept per test method
