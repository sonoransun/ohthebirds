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
	# Ensure configs are initialized (autoload _ready may not have fired)
	if GameManager._difficulty_configs.is_empty():
		GameManager._init_difficulty_configs()
	if GameManager._animal_configs.is_empty():
		GameManager._init_animal_configs()
	# Reset to a known clean state — set fields directly to avoid
	# state-transition guards and get_tree() issues in headless mode
	GameManager.current_state = GameManager.GameState.MENU
	GameManager.current_score = 0
	GameManager.distance_traveled = 0.0
	GameManager.current_difficulty = GameManager.base_difficulty
	GameManager.high_score = 0
	GameManager.is_game_active = false
	GameManager.difficulty_preset = GameManager.DifficultyPreset.NORMAL

func teardown() -> void:
	GameManager.current_state = GameManager.GameState.MENU
	GameManager.current_score = 0
	GameManager.distance_traveled = 0.0
	GameManager.high_score = 0
	GameManager.is_game_active = false
	GameManager.difficulty_preset = GameManager.DifficultyPreset.NORMAL

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
	# Difficulty scaling now happens in update_game_progression()
	GameManager.update_game_progression(0.016)
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

# ============================================================
# RETURN-TO-MENU RESET TESTS
# ============================================================

func test_return_to_menu_resets_score() -> void:
	GameManager.start_new_game()
	GameManager.add_score(100)
	GameManager.return_to_menu()
	assert_equal(GameManager.current_score, 0,
		"score should be 0 after return_to_menu")

func test_return_to_menu_resets_distance() -> void:
	GameManager.start_new_game()
	GameManager.update_distance(500.0)
	GameManager.return_to_menu()
	assert_approx_equal(GameManager.distance_traveled, 0.0, 0.001,
		"distance should be 0.0 after return_to_menu")

func test_return_to_menu_state_is_menu() -> void:
	GameManager.start_new_game()
	GameManager.return_to_menu()
	assert_equal(GameManager.current_state, GameManager.GameState.MENU,
		"state should be MENU after return_to_menu")

# ============================================================
# SCORE MULTIPLIER & EDGE CASE TESTS
# ============================================================

func test_score_multiplier_hard_preset() -> void:
	GameManager.set_difficulty_preset(GameManager.DifficultyPreset.HARD)
	assert_approx_equal(GameManager.get_score_multiplier(), 1.75, 0.001,
		"HARD preset score multiplier should be 1.75")

func test_add_negative_score_clamps_to_zero() -> void:
	GameManager.start_new_game()
	GameManager.add_score(10)
	GameManager.add_score(-1000)
	assert_gte(float(GameManager.current_score), 0.0,
		"score should not go below zero after large negative add_score")

# ============================================================
# STATE TRANSITION GUARD TESTS
# ============================================================

func test_pause_when_not_playing_does_nothing() -> void:
	# current_state is MENU from setup()
	GameManager.pause_game()
	assert_equal(GameManager.current_state, GameManager.GameState.MENU,
		"pause_game should not change state when not PLAYING")

func test_resume_when_not_paused_does_nothing() -> void:
	GameManager.start_new_game()
	# current_state is now PLAYING
	GameManager.resume_game()
	assert_equal(GameManager.current_state, GameManager.GameState.PLAYING,
		"resume_game should not change state when not PAUSED")

func test_invalid_state_transition_blocked() -> void:
	# MENU -> GAME_OVER is not a valid transition
	GameManager.change_state(GameManager.GameState.GAME_OVER)
	assert_equal(GameManager.current_state, GameManager.GameState.MENU,
		"direct MENU -> GAME_OVER transition should be blocked")

func test_valid_state_transition_allowed() -> void:
	# MENU -> PLAYING is valid
	GameManager.change_state(GameManager.GameState.PLAYING)
	assert_equal(GameManager.current_state, GameManager.GameState.PLAYING,
		"MENU -> PLAYING transition should be allowed")

# ============================================================
# ANIMAL CONFIG FALLBACK TEST
# ============================================================

func test_get_animal_config_returns_default_when_empty() -> void:
	# Save and clear configs
	var saved_configs = GameManager._animal_configs.duplicate(true)
	GameManager._animal_configs.clear()
	# get_animal_config should return a fallback dict with "max_glide_speed"
	var config = GameManager.get_animal_config()
	assert_true(config.has("max_glide_speed"),
		"fallback config should contain 'max_glide_speed' key")
	# Restore configs
	GameManager._animal_configs = saved_configs
