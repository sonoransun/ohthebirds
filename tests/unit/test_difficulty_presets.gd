## test_difficulty_presets.gd — Spec tests for all difficulty preset multipliers
##
## This file serves as a living specification document.
## If any difficulty value is intentionally changed in GameManager, update
## the EXPECTED table here to match. A failing test here means a design change
## happened without updating the spec.
##
## Tests: one per preset, each asserting all 5 multiplier values.

extends TestBase

# ============================================================
# SPEC TABLE — single source of truth for design values
# ============================================================

# Each entry maps: {scroll_speed, energy_drain, rocket_base, warning_time, score}
const EXPECTED: Dictionary = {
	# EASY: slower speed, less drain, fewer rockets, longer warnings, lower score
	0: {"scroll": 0.75, "drain": 0.60, "rocket": 0.50, "warning": 1.80, "score": 0.75},
	# NORMAL: baseline
	1: {"scroll": 1.00, "drain": 1.00, "rocket": 1.00, "warning": 1.00, "score": 1.00},
	# HARD: faster, more drain, more rockets, shorter warnings, higher score
	2: {"scroll": 1.20, "drain": 1.30, "rocket": 1.50, "warning": 0.60, "score": 1.50},
	# EXTREME: max speed, heavy drain, maximum rockets, almost no warning, big score
	3: {"scroll": 1.50, "drain": 1.70, "rocket": 2.00, "warning": 0.30, "score": 2.50},
}

const TOLERANCE: float = 0.001

# ============================================================
# LIFECYCLE
# ============================================================

func teardown() -> void:
	GameManager.set_difficulty_preset(GameManager.DifficultyPreset.NORMAL)

# ============================================================
# PRESET SPEC TESTS
# ============================================================

func test_easy_preset_multipliers() -> void:
	GameManager.set_difficulty_preset(GameManager.DifficultyPreset.EASY)
	var e = EXPECTED[GameManager.DifficultyPreset.EASY]

	assert_approx_equal(GameManager.get_scroll_speed_multiplier(), e.scroll, TOLERANCE,
		"EASY scroll_speed_multiplier")
	assert_approx_equal(GameManager.get_energy_drain_multiplier(), e.drain, TOLERANCE,
		"EASY energy_drain_multiplier")
	assert_approx_equal(GameManager.get_rocket_base_difficulty(), e.rocket, TOLERANCE,
		"EASY rocket_base_difficulty")
	assert_approx_equal(GameManager.get_warning_time_multiplier(), e.warning, TOLERANCE,
		"EASY warning_time_multiplier")
	assert_approx_equal(GameManager.get_score_multiplier(), e.score, TOLERANCE,
		"EASY score_multiplier")

func test_normal_preset_multipliers() -> void:
	GameManager.set_difficulty_preset(GameManager.DifficultyPreset.NORMAL)
	var e = EXPECTED[GameManager.DifficultyPreset.NORMAL]

	assert_approx_equal(GameManager.get_scroll_speed_multiplier(), e.scroll, TOLERANCE,
		"NORMAL scroll_speed_multiplier")
	assert_approx_equal(GameManager.get_energy_drain_multiplier(), e.drain, TOLERANCE,
		"NORMAL energy_drain_multiplier")
	assert_approx_equal(GameManager.get_rocket_base_difficulty(), e.rocket, TOLERANCE,
		"NORMAL rocket_base_difficulty")
	assert_approx_equal(GameManager.get_warning_time_multiplier(), e.warning, TOLERANCE,
		"NORMAL warning_time_multiplier")
	assert_approx_equal(GameManager.get_score_multiplier(), e.score, TOLERANCE,
		"NORMAL score_multiplier")

func test_hard_preset_multipliers() -> void:
	GameManager.set_difficulty_preset(GameManager.DifficultyPreset.HARD)
	var e = EXPECTED[GameManager.DifficultyPreset.HARD]

	assert_approx_equal(GameManager.get_scroll_speed_multiplier(), e.scroll, TOLERANCE,
		"HARD scroll_speed_multiplier")
	assert_approx_equal(GameManager.get_energy_drain_multiplier(), e.drain, TOLERANCE,
		"HARD energy_drain_multiplier")
	assert_approx_equal(GameManager.get_rocket_base_difficulty(), e.rocket, TOLERANCE,
		"HARD rocket_base_difficulty")
	assert_approx_equal(GameManager.get_warning_time_multiplier(), e.warning, TOLERANCE,
		"HARD warning_time_multiplier")
	assert_approx_equal(GameManager.get_score_multiplier(), e.score, TOLERANCE,
		"HARD score_multiplier")

func test_extreme_preset_multipliers() -> void:
	GameManager.set_difficulty_preset(GameManager.DifficultyPreset.EXTREME)
	var e = EXPECTED[GameManager.DifficultyPreset.EXTREME]

	assert_approx_equal(GameManager.get_scroll_speed_multiplier(), e.scroll, TOLERANCE,
		"EXTREME scroll_speed_multiplier")
	assert_approx_equal(GameManager.get_energy_drain_multiplier(), e.drain, TOLERANCE,
		"EXTREME energy_drain_multiplier")
	assert_approx_equal(GameManager.get_rocket_base_difficulty(), e.rocket, TOLERANCE,
		"EXTREME rocket_base_difficulty")
	assert_approx_equal(GameManager.get_warning_time_multiplier(), e.warning, TOLERANCE,
		"EXTREME warning_time_multiplier")
	assert_approx_equal(GameManager.get_score_multiplier(), e.score, TOLERANCE,
		"EXTREME score_multiplier")
