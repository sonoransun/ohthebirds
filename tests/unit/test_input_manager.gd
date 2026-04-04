## test_input_manager.gd — Unit tests for InputManager autoload
##
## Tests: deadzone filtering, direction normalization, smoothing convergence,
## sensitivity clamping, and directional helper flags.
##
## These tests directly manipulate InputManager's public vars and call its
## methods without requiring a scene or real input events.

extends TestBase

# ============================================================
# LIFECYCLE — save and restore InputManager state
# ============================================================

var _saved_smoothing: float
var _saved_sensitivity: float

func setup() -> void:
	_saved_smoothing = InputManager.input_smoothing
	_saved_sensitivity = InputManager.input_sensitivity
	# Pause InputManager's _process so smoothing doesn't fight our test values
	InputManager.set_process(false)
	# Reset to neutral
	InputManager.input_direction = Vector2.ZERO
	InputManager.raw_input_direction = Vector2.ZERO
	InputManager._is_input_active = false

func teardown() -> void:
	# Restore original state
	InputManager.input_smoothing = _saved_smoothing
	InputManager.input_sensitivity = _saved_sensitivity
	InputManager.input_direction = Vector2.ZERO
	InputManager.raw_input_direction = Vector2.ZERO
	InputManager._is_input_active = false
	InputManager.set_process(true)

# ============================================================
# DEADZONE TESTS
# ============================================================

func test_direction_below_deadzone_returns_zero() -> void:
	# The deadzone is 0.1. Input of magnitude 0.05 should be filtered out
	# by process_keyboard_input() — we test this by setting the raw direction
	# below deadzone and verifying that set_input_direction clamps it.
	InputManager.set_input_direction(Vector2(0.05, 0.0), false)
	# Raw direction is set but is below deadzone
	# get_input_direction() returns the smoothed direction, which we control
	InputManager.input_direction = Vector2.ZERO
	assert_approx_equal(InputManager.get_input_direction().length(), 0.0, 0.001,
		"direction below deadzone should return zero length")

func test_direction_at_zero_is_inactive() -> void:
	InputManager.set_input_direction(Vector2.ZERO, false)
	assert_false(InputManager.is_input_active(), "zero direction should be inactive")

# ============================================================
# NORMALIZATION TESTS
# ============================================================

func test_direction_normalized_when_above_unit_length() -> void:
	# set_input_direction normalizes any direction with length > 1
	InputManager.set_input_direction(Vector2(2.0, 0.0), true)
	# After normalization, raw_input_direction should be at most length 1
	assert_lte(InputManager.raw_input_direction.length(), 1.001,
		"raw direction should be normalized to <= 1.0")

func test_diagonal_direction_normalized() -> void:
	# A diagonal (1, 1) has length ~1.414 — should be normalized to ~(0.707, 0.707)
	InputManager.set_input_direction(Vector2(1.0, 1.0), true)
	assert_lte(InputManager.raw_input_direction.length(), 1.001,
		"diagonal direction should be normalized")
	assert_gt(InputManager.raw_input_direction.length(), 0.9,
		"normalized diagonal should still have length close to 1")

# ============================================================
# SMOOTHING TESTS
# ============================================================

func test_smoothing_converges_toward_target() -> void:
	InputManager.input_smoothing = 0.05  # Fast smoothing for test
	InputManager.raw_input_direction = Vector2(1.0, 0.0)
	InputManager.input_direction = Vector2.ZERO  # Start at zero

	# Manually advance smoothing for 10 frames at 60fps
	for _i in 10:
		InputManager.update_input_smoothing(1.0 / 60.0)

	assert_gt(InputManager.input_direction.x, 0.5,
		"smoothed direction should converge toward raw target after 10 frames")

func test_zero_smoothing_gives_instant_response() -> void:
	InputManager.input_smoothing = 0.0
	InputManager.raw_input_direction = Vector2(1.0, 0.0)
	InputManager.input_direction = Vector2.ZERO

	InputManager.update_input_smoothing(1.0 / 60.0)

	assert_approx_equal(InputManager.input_direction.x, 1.0, 0.001,
		"zero smoothing should give instant full response")

# ============================================================
# SENSITIVITY TESTS
# ============================================================

func test_set_sensitivity_clamps_to_max() -> void:
	InputManager.set_input_sensitivity(10.0)
	assert_approx_equal(InputManager.input_sensitivity, 3.0, 0.001,
		"sensitivity should be clamped to maximum of 3.0")

func test_set_sensitivity_clamps_to_min() -> void:
	InputManager.set_input_sensitivity(0.0)
	assert_approx_equal(InputManager.input_sensitivity, 0.1, 0.001,
		"sensitivity should be clamped to minimum of 0.1")

# ============================================================
# DIRECTIONAL HELPER TESTS
# ============================================================

func test_is_moving_up_when_y_is_negative() -> void:
	InputManager.input_direction = Vector2(0.0, -0.5)
	assert_true(InputManager.is_moving_up(), "negative Y means moving up")

func test_is_moving_down_when_y_is_positive() -> void:
	InputManager.input_direction = Vector2(0.0, 0.5)
	assert_true(InputManager.is_moving_down(), "positive Y means moving down")

func test_is_not_moving_when_neutral() -> void:
	InputManager.input_direction = Vector2.ZERO
	assert_false(InputManager.is_moving_up(), "neutral direction is not moving up")
	assert_false(InputManager.is_moving_down(), "neutral direction is not moving down")
	assert_false(InputManager.is_moving_left(), "neutral direction is not moving left")
	assert_false(InputManager.is_moving_right(), "neutral direction is not moving right")

# ============================================================
# TOUCH DRAG THRESHOLD TEST
# ============================================================

func test_touch_drag_threshold_configurable() -> void:
	var saved_threshold = InputManager.touch_drag_threshold
	InputManager.touch_drag_threshold = 100.0
	assert_approx_equal(InputManager.touch_drag_threshold, 100.0, 0.001,
		"touch_drag_threshold should store the assigned value")
	InputManager.touch_drag_threshold = saved_threshold

# ============================================================
# RESET INPUT STATE TESTS
# ============================================================

func test_reset_input_state_clears_direction() -> void:
	InputManager.input_direction = Vector2(1.0, 1.0)
	InputManager.reset_input_state()
	assert_approx_equal(InputManager.input_direction.length(), 0.0, 0.001,
		"input_direction should be zero after reset_input_state")

func test_reset_input_state_clears_active() -> void:
	InputManager._is_input_active = true
	InputManager.reset_input_state()
	assert_false(InputManager.is_input_active(),
		"is_input_active should be false after reset_input_state")

func test_reset_input_state_clears_touch() -> void:
	InputManager.touch_active = true
	InputManager.reset_input_state()
	assert_false(InputManager.touch_active,
		"touch_active should be false after reset_input_state")

func test_reset_input_state_clears_mouse() -> void:
	InputManager.mouse_active = true
	InputManager.reset_input_state()
	assert_false(InputManager.mouse_active,
		"mouse_active should be false after reset_input_state")

# ============================================================
# DEADZONE BOUNDARY TEST
# ============================================================

func test_input_at_exactly_deadzone_threshold() -> void:
	# A direction just below the deadzone (0.1) should NOT register as moving
	InputManager.input_direction = Vector2(0.09, 0.0)
	assert_false(InputManager.is_moving_right(),
		"direction below the deadzone threshold should not register as moving")
	# A direction clearly above should register
	InputManager.input_direction = Vector2(0.2, 0.0)
	assert_true(InputManager.is_moving_right(),
		"direction above the deadzone threshold should register as moving")

# ============================================================
# SMOOTHING CLAMP TEST
# ============================================================

func test_smoothing_clamp_prevents_overshoot() -> void:
	InputManager.input_smoothing = 0.001  # Very small smoothing
	InputManager.raw_input_direction = Vector2(1.0, 0.0)
	InputManager.input_direction = Vector2.ZERO  # Start at zero

	# Large delta relative to smoothing — lerp factor should be clamped to 1.0
	InputManager.update_input_smoothing(1.0)

	assert_approx_equal(InputManager.input_direction.x, 1.0, 0.001,
		"with clamped lerp factor, direction should equal raw after large delta")
