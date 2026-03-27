## test_game_manager.gd — Unit tests for GameManager autoload
##
## Tests: state machine transitions, scoring with difficulty multipliers,
## preset configuration values, distance-triggered difficulty scaling,
## and high score update logic.
##
## No scene instantiation required — tests operate on the autoload directly.

extends TestBase

# ============================================================
# LIFECYCLE
# ============================================================

func setup() -> void:
	# Reset to a known clean state before every test
	GameManager.return_to_menu()
	GameManager.current_score = 0
	GameManager.distance_traveled = 0.0
	GameManager.current_difficulty = GameManager.base_difficulty
	GameManager.high_score = 0
	GameManager.set_difficulty_preset(GameManager.DifficultyPreset.NORMAL)
	get_tree().paused = false

func teardown() -> void:
	# Same cleanup after every test to avoid state leakage
	GameManager.return_to_menu()
	GameManager.current_score = 0
	GameManager.distance_traveled = 0.0
	GameManager.high_score = 0
	GameManager.set_difficulty_preset(GameManager.DifficultyPreset.NORMAL)
	get_tree().paused = false

# ============================================================
# STATE MACHINE TESTS
# ============================================================

func test_initial_state_is_menu() -> void:
	# GameManager starts in MENU state (after our teardown restores it)
	assert_equal(GameManager.current_state, GameManager.GameState.MENU,
		"should start in MENU state")
	assert_false(GameManager.is_playing(), "should not be playing")
	assert_false(GameManager.is_paused(), "should not be paused")
	assert_false(GameManager.is_game_over(), "should not be game over")

func test_start_new_game_transitions_to_playing() -> void:
	GameManager.start_new_game()
	assert_true(GameManager.is_playing(), "should be in PLAYING state after start")
	assert_equal(GameManager.current_state, GameManager.GameState.PLAYING)

func test_pause_transitions_state() -> void:
	GameManager.start_new_game()
	GameManager.pause_game()
	assert_true(GameManager.is_paused(), "should be PAUSED after pause_game()")
	assert_false(GameManager.is_playing(), "should not be PLAYING while paused")

func test_resume_from_paused_returns_to_playing() -> void:
	GameManager.start_new_game()
	GameManager.pause_game()
	GameManager.resume_game()
	assert_true(GameManager.is_playing(), "should return to PLAYING after resume")
	assert_false(GameManager.is_paused(), "should not be paused after resume")

func test_end_game_transitions_to_game_over() -> void:
	GameManager.start_new_game()
	GameManager.end_game()
	assert_true(GameManager.is_game_over(), "should be in GAME_OVER state")
	assert_false(GameManager.is_playing(), "should not be playing when game over")

func test_restart_resets_score_and_distance() -> void:
	GameManager.start_new_game()
	GameManager.add_score(500)
	GameManager.update_distance(2000.0)
	GameManager.restart_game()
	assert_equal(GameManager.get_current_score(), 0, "score should reset on restart")
	assert_approx_equal(GameManager.get_distance_traveled(), 0.0, 0.001,
		"distance should reset on restart")

# ============================================================
# SCORING TESTS
# ============================================================

func test_score_multiplier_normal_preset_is_one_to_one() -> void:
	GameManager.set_difficulty_preset(GameManager.DifficultyPreset.NORMAL)
	GameManager.start_new_game()
	GameManager.add_score(100)
	assert_equal(GameManager.get_current_score(), 100,
		"NORMAL preset should give 1.0x score (100 → 100)")

func test_score_multiplier_easy_preset_reduces_score() -> void:
	GameManager.set_difficulty_preset(GameManager.DifficultyPreset.EASY)
	GameManager.start_new_game()
	GameManager.add_score(100)
	# EASY score multiplier = 0.75 → int(100 * 0.75) = 75
	assert_equal(GameManager.get_current_score(), 75,
		"EASY preset should give 0.75x score (100 → 75)")

func test_score_multiplier_extreme_preset_amplifies_score() -> void:
	GameManager.set_difficulty_preset(GameManager.DifficultyPreset.EXTREME)
	GameManager.start_new_game()
	GameManager.add_score(100)
	# EXTREME score multiplier = 2.5 → int(100 * 2.5) = 250
	assert_equal(GameManager.get_current_score(), 250,
		"EXTREME preset should give 2.5x score (100 → 250)")

func test_score_accumulates_across_multiple_add_calls() -> void:
	GameManager.start_new_game()
	GameManager.add_score(50)
	GameManager.add_score(30)
	GameManager.add_score(20)
	assert_equal(GameManager.get_current_score(), 100,
		"score should accumulate correctly")

# ============================================================
# DIFFICULTY SCALING TESTS
# ============================================================

func test_difficulty_increases_after_distance_interval() -> void:
	GameManager.set_difficulty_preset(GameManager.DifficultyPreset.NORMAL)
	GameManager.start_new_game()
	var initial_difficulty = GameManager.get_difficulty_multiplier()
	# Distance interval is 1000 units, so 1500 should trigger one increase
	GameManager.update_distance(1500.0)
	assert_gt(GameManager.get_difficulty_multiplier(), initial_difficulty,
		"difficulty should increase after passing 1000 unit interval")

func test_difficulty_preset_persists_through_restart() -> void:
	GameManager.set_difficulty_preset(GameManager.DifficultyPreset.HARD)
	GameManager.start_new_game()
	GameManager.end_game()
	GameManager.restart_game()
	assert_equal(GameManager.difficulty_preset, GameManager.DifficultyPreset.HARD,
		"difficulty preset should survive restart")

func test_high_score_updates_only_when_beaten() -> void:
	# First game — sets high score
	GameManager.start_new_game()
	GameManager.add_score(200)
	GameManager.end_game()
	assert_equal(GameManager.high_score, 200, "high score set after first game")

	# Second game — lower score, high score should not change
	GameManager.start_new_game()
	GameManager.add_score(100)
	GameManager.end_game()
	assert_equal(GameManager.high_score, 200, "high score should not decrease")

	# Third game — higher score, high score should update
	GameManager.start_new_game()
	GameManager.add_score(500)
	GameManager.end_game()
	assert_equal(GameManager.high_score, 500, "high score should update when beaten")
