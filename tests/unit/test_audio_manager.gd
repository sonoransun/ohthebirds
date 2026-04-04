## test_audio_manager.gd — Tests for AudioManager settings and volume API
##
## Tests: volume setters with clamping, enable/disable toggles,
## and convenience sound methods that should not crash even without
## loaded audio resources.

extends TestBase

# ============================================================
# LIFECYCLE
# ============================================================

func setup() -> void:
	AudioManager.master_volume = 1.0
	AudioManager.music_volume = 1.0
	AudioManager.sfx_volume = 1.0
	AudioManager.music_enabled = true
	AudioManager.sfx_enabled = true

func teardown() -> void:
	AudioManager.master_volume = 1.0
	AudioManager.music_volume = 1.0
	AudioManager.sfx_volume = 1.0
	AudioManager.music_enabled = true
	AudioManager.sfx_enabled = true

# ============================================================
# VOLUME SETTER TESTS
# ============================================================

func test_set_master_volume_stores_value() -> void:
	AudioManager.set_master_volume(0.5)
	assert_approx_equal(AudioManager.master_volume, 0.5, 0.001,
		"master_volume should be 0.5 after set_master_volume(0.5)")

func test_set_music_volume_stores_value() -> void:
	AudioManager.set_music_volume(0.7)
	assert_approx_equal(AudioManager.music_volume, 0.7, 0.001,
		"music_volume should be 0.7 after set_music_volume(0.7)")

func test_set_sfx_volume_stores_value() -> void:
	AudioManager.set_sfx_volume(0.3)
	assert_approx_equal(AudioManager.sfx_volume, 0.3, 0.001,
		"sfx_volume should be 0.3 after set_sfx_volume(0.3)")

# ============================================================
# ENABLE / DISABLE TESTS
# ============================================================

func test_disable_music() -> void:
	AudioManager.set_music_enabled(false)
	assert_false(AudioManager.music_enabled,
		"music_enabled should be false after set_music_enabled(false)")

func test_disable_sfx() -> void:
	AudioManager.set_sfx_enabled(false)
	assert_false(AudioManager.sfx_enabled,
		"sfx_enabled should be false after set_sfx_enabled(false)")

# ============================================================
# CLAMPING TESTS
# ============================================================

func test_volume_clamps_above_one() -> void:
	AudioManager.set_master_volume(5.0)
	assert_lte(AudioManager.master_volume, 1.0,
		"master_volume should be clamped to <= 1.0 when set to 5.0")

func test_volume_clamps_below_zero() -> void:
	AudioManager.set_master_volume(-1.0)
	assert_gte(AudioManager.master_volume, 0.0,
		"master_volume should be clamped to >= 0.0 when set to -1.0")

# ============================================================
# CONVENIENCE SOUND METHODS (no-crash smoke tests)
# ============================================================

func test_play_sfx_does_not_crash() -> void:
	# play_sfx with a nonexistent sound name should not crash;
	# the placeholder get_sfx_resource returns null, so nothing plays.
	AudioManager.play_sfx("nonexistent")
	assert_true(true, "play_sfx with unknown name should not crash")

func test_play_collision_sound_does_not_crash() -> void:
	AudioManager.play_collision_sound()
	assert_true(true, "play_collision_sound should not crash")

func test_play_glide_sound_does_not_crash() -> void:
	AudioManager.play_glide_sound()
	assert_true(true, "play_glide_sound should not crash")
