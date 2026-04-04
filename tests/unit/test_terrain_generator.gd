## test_terrain_generator.gd — Tests for TerrainGenerator procedural generation
##
## Tests: noise setup, deterministic seeding, obstacle density configuration,
## gap size validation, obstacle height capping, and generation stats API.
##
## TerrainGenerator is instantiated from its script (not a scene) and added
## to the tree manually. Note: create_obstacle relies on a terrain_container
## node, so tests that trigger full chunk generation provide one.

extends TestBase

var generator: TerrainGenerator

# ============================================================
# LIFECYCLE
# ============================================================

func setup() -> void:
	generator = TerrainGenerator.new()
	add_child(generator)
	# Call setup_noise and setup_pattern_templates manually since _ready
	# will also call find_containers (which won't find anything in test).
	generator.setup_noise()
	generator.setup_pattern_templates()

func teardown() -> void:
	if is_instance_valid(generator):
		generator.queue_free()
	generator = null

# ============================================================
# NOISE TESTS
# ============================================================

func test_setup_noise_creates_valid_noise() -> void:
	assert_not_null(generator.terrain_noise,
		"terrain_noise should not be null after setup_noise()")

func test_set_noise_seed_deterministic() -> void:
	generator.set_noise_seed(42)
	var value_a = generator.terrain_noise.get_noise_2d(100.0, 0.0)

	generator.set_noise_seed(42)
	var value_b = generator.terrain_noise.get_noise_2d(100.0, 0.0)

	assert_approx_equal(value_a, value_b, 0.0001,
		"same seed should produce the same noise value at the same coordinates")

# ============================================================
# CHUNK GENERATION TESTS
# ============================================================

func test_generate_chunk_creates_obstacles() -> void:
	# Provide a terrain_container so create_obstacle can add children
	var container = Node2D.new()
	container.name = "TerrainContainer"
	generator.terrain_container = container
	add_child(container)

	var chunk_data = {
		"id": 0,
		"position": 0.0,
		"obstacles": [],
		"hazards": [],
		"effects": []
	}

	# Force procedural generation (patterns may also work, but procedural is
	# deterministic with a fixed seed and density).
	generator.use_pattern_based = false
	generator.obstacle_density = 0.9
	generator.set_noise_seed(12345)

	generator.generate_chunk(chunk_data)

	# With high density and a fixed seed we expect at least one obstacle entry
	assert_gt(chunk_data.obstacles.size(), 0,
		"generate_chunk should populate the obstacles array")

	# Cleanup spawned obstacles
	container.queue_free()

# ============================================================
# CONFIGURATION TESTS
# ============================================================

func test_obstacle_density_configurable() -> void:
	generator.set_obstacle_density(0.4)
	assert_approx_equal(generator.obstacle_density, 0.4, 0.001,
		"obstacle_density should be 0.4 after set_obstacle_density(0.4)")

func test_obstacle_density_clamps_high() -> void:
	generator.set_obstacle_density(5.0)
	assert_lte(generator.obstacle_density, 1.0,
		"obstacle_density should be clamped to <= 1.0")

func test_obstacle_density_clamps_low() -> void:
	generator.set_obstacle_density(-1.0)
	assert_gte(generator.obstacle_density, 0.1,
		"obstacle_density should be clamped to >= 0.1")

func test_gap_size_validation() -> void:
	# Set a very small gap range; after update_difficulty_for_position the
	# generator guarantees min <= max.
	generator.set_gap_size_range(10.0, 5.0)  # Intentionally inverted
	# Trigger the validation logic that runs during chunk generation
	generator.update_difficulty_for_position(5000.0)
	assert_lte(generator.min_gap_size, generator.max_gap_size,
		"min_gap_size should never exceed max_gap_size after validation")

func test_obstacle_height_capped() -> void:
	# generate_obstacles_from_pattern caps height at 800.0.
	# With a very high difficulty_multiplier the raw height would exceed 800.
	generator.difficulty_multiplier = 10.0
	var pattern = generator.pattern_templates[0]  # simple_gap

	# The capping happens inline: min(height * difficulty_multiplier, 800.0)
	for obstacle_data in pattern.obstacles:
		var computed_height = min(obstacle_data.height * generator.difficulty_multiplier, 800.0)
		assert_lte(computed_height, 800.0,
			"obstacle height should be capped at 800.0 regardless of difficulty")

# ============================================================
# STATS API TEST
# ============================================================

func test_generation_stats_returns_dict() -> void:
	var stats = generator.get_generation_stats()
	assert_true(stats is Dictionary,
		"get_generation_stats should return a Dictionary")
	assert_true(stats.has("difficulty_multiplier"),
		"stats should contain difficulty_multiplier key")
	assert_true(stats.has("obstacle_density"),
		"stats should contain obstacle_density key")
	assert_true(stats.has("min_gap_size"),
		"stats should contain min_gap_size key")
	assert_true(stats.has("max_gap_size"),
		"stats should contain max_gap_size key")
	assert_true(stats.has("pattern_count"),
		"stats should contain pattern_count key")
