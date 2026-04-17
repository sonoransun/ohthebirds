extends Node
class_name TerrainGenerator

# Terrain generation for Sugar Glider Adventure
signal obstacle_spawned(obstacle: Node2D, type: String)
signal terrain_feature_created(feature: Node2D, position: Vector2)

# Generation parameters
var chunk_width: float = 2000.0
var obstacle_density: float = 0.6  # Base density of obstacles
var min_gap_size: float = 150.0    # Minimum navigable gap size
var max_gap_size: float = 300.0    # Maximum gap size

# Obstacle configuration
var volcano_height_range: Vector2 = Vector2(200, 500)
var spire_height_range: Vector2 = Vector2(100, 400)
var obstacle_width_range: Vector2 = Vector2(80, 150)

# Difficulty scaling
var difficulty_multiplier: float = 1.0
var gap_size_reduction_rate: float = 0.05
var density_increase_rate: float = 0.1

# Pattern generation
var use_pattern_based: bool = true
var pattern_templates: Array[Dictionary] = []

# References to containers
var terrain_container: Node2D
var hazard_container: Node2D
var game_world: Node2D

# Obstacle prefabs
var volcano_prefab: PackedScene = preload("res://scenes/environment/VolcanoObstacle.tscn")
var spire_prefab: PackedScene = preload("res://scenes/environment/SpireObstacle.tscn")

# Noise for procedural generation
var terrain_noise: FastNoiseLite

func _ready():
	setup_noise()
	setup_pattern_templates()
	find_containers()

	print("TerrainGenerator initialized")

func setup_noise():
	"""Initialize noise for procedural generation"""
	terrain_noise = FastNoiseLite.new()
	terrain_noise.seed = randi()
	terrain_noise.frequency = 0.01
	terrain_noise.noise_type = FastNoiseLite.TYPE_PERLIN

func set_noise_seed(seed_value: int):
	"""Set a deterministic noise seed (useful for tests)"""
	if terrain_noise:
		terrain_noise.seed = seed_value

func setup_pattern_templates():
	"""Define pattern templates for obstacle generation"""
	pattern_templates = [
		# Simple gap pattern
		{
			"name": "simple_gap",
			"width": 800.0,
			"obstacles": [
				{"type": "volcano", "x": 0.0, "height": 300.0, "gap_after": 200.0},
				{"type": "spire", "x": 500.0, "height": 250.0, "gap_after": 150.0}
			]
		},
		# Slalom pattern
		{
			"name": "slalom",
			"width": 1200.0,
			"obstacles": [
				{"type": "volcano", "x": 0.0, "height": 350.0, "gap_after": 180.0},
				{"type": "spire", "x": 400.0, "height": 200.0, "gap_after": 160.0},
				{"type": "volcano", "x": 800.0, "height": 320.0, "gap_after": 190.0}
			]
		},
		# Tight passage pattern
		{
			"name": "tight_passage",
			"width": 600.0,
			"obstacles": [
				{"type": "volcano", "x": 0.0, "height": 450.0, "gap_after": 120.0},
				{"type": "volcano", "x": 350.0, "height": 420.0, "gap_after": 130.0}
			]
		},
		# Spire field pattern
		{
			"name": "spire_field",
			"width": 1000.0,
			"obstacles": [
				{"type": "spire", "x": 0.0, "height": 180.0, "gap_after": 140.0},
				{"type": "spire", "x": 250.0, "height": 220.0, "gap_after": 160.0},
				{"type": "spire", "x": 500.0, "height": 200.0, "gap_after": 150.0},
				{"type": "spire", "x": 750.0, "height": 240.0, "gap_after": 170.0}
			]
		}
	]

func find_containers():
	"""Find container nodes for spawning objects"""
	game_world = get_tree().get_first_node_in_group("game_world")
	if not game_world:
		game_world = get_parent().get_parent()  # Fallback

	if game_world:
		terrain_container = game_world.get_node_or_null("PlayArea/TerrainContainer")
		hazard_container = game_world.get_node_or_null("PlayArea/HazardContainer")

	if not terrain_container:
		print("Warning: TerrainContainer not found")
	if not hazard_container:
		print("Warning: HazardContainer not found")

func generate_chunk(chunk_data: Dictionary):
	"""Generate terrain for a chunk"""
	var chunk_position = chunk_data.position
	var chunk_id = chunk_data.id

	print("Generating chunk ", chunk_id, " at position ", chunk_position)

	# Update difficulty based on distance
	update_difficulty_for_position(chunk_position)

	# Choose generation method
	if use_pattern_based and randf() < 0.7:  # 70% chance to use patterns
		generate_chunk_with_patterns(chunk_data)
	else:
		generate_chunk_procedurally(chunk_data)

	# Ensure navigable path exists
	ensure_navigable_path(chunk_data)

func update_difficulty_for_position(position: float):
	"""Update generation difficulty based on distance traveled"""
	var distance_factor = position / 1000.0  # Every 1000 units
	difficulty_multiplier = 1.0 + (distance_factor * 0.1)

	# Apply difficulty to generation parameters
	obstacle_density = min(0.6 + (distance_factor * density_increase_rate), 0.9)
	var gap_reduction = distance_factor * gap_size_reduction_rate
	min_gap_size = max(100.0, 150.0 - gap_reduction * 50.0)
	max_gap_size = max(min_gap_size + 50.0, 300.0 - gap_reduction * 100.0)

	# Ensure min never exceeds max
	if min_gap_size > max_gap_size:
		min_gap_size = max_gap_size

func generate_chunk_with_patterns(chunk_data: Dictionary):
	"""Generate chunk using predefined patterns"""
	var chunk_position = chunk_data.position
	var remaining_width = chunk_width
	var current_x = chunk_position

	# Occasionally add strategic challenges for experienced players
	if difficulty_multiplier > 1.3 and randf() < 0.3:  # 30% chance at higher difficulty
		add_strategic_challenge_to_chunk(chunk_data)

	while remaining_width > 200.0:  # Minimum space for a pattern
		var pattern = choose_pattern_for_difficulty(difficulty_multiplier)
		var pattern_width = pattern.width

		# Check if pattern fits
		if pattern_width > remaining_width:
			pattern = get_simple_pattern(remaining_width)

		# Generate obstacles from pattern
		generate_obstacles_from_pattern(pattern, current_x, chunk_data)

		current_x += pattern_width
		remaining_width -= pattern_width

func add_strategic_challenge_to_chunk(chunk_data: Dictionary):
	"""Add a strategic challenge to the chunk"""
	var challenge_types = ["precision_course", "altitude_challenge", "speed_section"]
	var challenge_type = challenge_types[randi() % challenge_types.size()]

	create_strategic_challenge(chunk_data, challenge_type)
	print("Added strategic challenge: ", challenge_type)

func choose_pattern_for_difficulty(difficulty: float) -> Dictionary:
	"""Choose appropriate pattern based on difficulty"""
	var available_patterns = []

	for pattern in pattern_templates:
		var pattern_difficulty = calculate_pattern_difficulty(pattern)
		if pattern_difficulty <= difficulty + 0.2:  # Allow some variance
			available_patterns.append(pattern)

	if available_patterns.is_empty():
		return pattern_templates[0]  # Fallback to simple pattern

	return available_patterns[randi() % available_patterns.size()]

func calculate_pattern_difficulty(pattern: Dictionary) -> float:
	"""Calculate difficulty rating for a pattern"""
	var difficulty = 0.0
	var obstacle_count = pattern.obstacles.size()

	for obstacle in pattern.obstacles:
		difficulty += obstacle.height / 1000.0  # Height factor
		difficulty += (200.0 - obstacle.gap_after) / 1000.0  # Gap size factor

	return difficulty / obstacle_count

func get_simple_pattern(available_width: float) -> Dictionary:
	"""Get a simple pattern that fits in available width"""
	return {
		"name": "simple",
		"width": available_width,
		"obstacles": [
			{"type": "volcano", "x": 0.0, "height": randf_range(200, 350), "gap_after": randf_range(min_gap_size, max_gap_size)}
		]
	}

func generate_obstacles_from_pattern(pattern: Dictionary, base_x: float, chunk_data: Dictionary):
	"""Generate obstacles from a pattern template"""
	for obstacle_data in pattern.obstacles:
		var obstacle_x = base_x + obstacle_data.x
		var obstacle_height = min(obstacle_data.height * difficulty_multiplier, 800.0)
		var obstacle_type = obstacle_data.type

		# Create obstacle
		var obstacle = create_obstacle(obstacle_type, Vector2(obstacle_x, 540), obstacle_height)
		if obstacle:
			chunk_data.obstacles.append(obstacle)
			emit_signal("obstacle_spawned", obstacle, obstacle_type)

func generate_chunk_procedurally(chunk_data: Dictionary):
	"""Generate chunk using procedural methods"""
	var chunk_position = chunk_data.position
	var obstacle_count = int(chunk_width / 400.0 * obstacle_density)  # Base obstacle count

	var current_x = chunk_position
	var safe_gap_positions = []

	for i in obstacle_count:
		# Use noise to determine obstacle placement
		var noise_value = terrain_noise.get_noise_2d(current_x, 0)
		var should_place = noise_value > (0.2 - obstacle_density)

		if should_place:
			# Choose obstacle type based on noise
			var obstacle_type = "volcano" if noise_value > 0 else "spire"

			# Determine height using noise
			var height_noise = terrain_noise.get_noise_2d(current_x, 100)
			var height_range = volcano_height_range if obstacle_type == "volcano" else spire_height_range
			var obstacle_height = min(lerp(height_range.x, height_range.y, (height_noise + 1.0) / 2.0), 800.0)

			# Create obstacle
			var obstacle = create_obstacle(obstacle_type, Vector2(current_x, 540), obstacle_height)
			if obstacle:
				chunk_data.obstacles.append(obstacle)
				emit_signal("obstacle_spawned", obstacle, obstacle_type)

			# Record safe gap position
			safe_gap_positions.append(current_x + randf_range(min_gap_size, max_gap_size))

		current_x += randf_range(200, 400)  # Spacing between potential obstacles

func ensure_navigable_path(chunk_data: Dictionary):
	"""Ensure there's always a navigable path through the chunk"""
	if chunk_data.obstacles.is_empty():
		return

	var path_y = 400.0  # Target flight altitude
	var path_width = 100.0  # Required clear width

	# Sort obstacles by x position
	var sorted_obstacles = chunk_data.obstacles.duplicate()
	sorted_obstacles.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)

	# Check for gaps that are too small
	for i in range(sorted_obstacles.size() - 1):
		var current_obstacle = sorted_obstacles[i]
		var next_obstacle = sorted_obstacles[i + 1]

		var gap_size = next_obstacle.global_position.x - current_obstacle.global_position.x
		if gap_size < min_gap_size:
			# Move one of the obstacles to create adequate gap
			next_obstacle.global_position.x = current_obstacle.global_position.x + min_gap_size + randf() * 50.0

func create_obstacle(type: String, position: Vector2, height: float) -> Node2D:
	"""Create an obstacle of the specified type"""
	var obstacle: Node2D

	match type:
		"volcano":
			obstacle = create_volcano_obstacle(position, height)
		"spire":
			obstacle = create_spire_obstacle(position, height)
		_:
			print("Unknown obstacle type: ", type)
			return null

	if obstacle:
		if not is_instance_valid(terrain_container):
			push_warning("TerrainGenerator: terrain_container is null, cannot add obstacle")
			obstacle.queue_free()
			return null
		terrain_container.add_child(obstacle)

	return obstacle

func create_volcano_obstacle(position: Vector2, height: float) -> Node2D:
	"""Create a volcano obstacle using the enhanced VolcanoObstacle scene"""
	if not volcano_prefab:
		print("Error: Volcano prefab not loaded")
		return null

	var volcano = volcano_prefab.instantiate()
	volcano.position = position
	volcano.height = height
	volcano.width = randf_range(80, 140)

	# Configure volcano properties based on difficulty
	volcano.has_lava_flow = randf() < (0.2 + difficulty_multiplier * 0.3)
	volcano.danger_radius = 120.0 + (difficulty_multiplier * 30.0)

	# Connect signals for scoring and feedback
	volcano.obstacle_passed.connect(_on_volcano_passed)
	volcano.obstacle_approached.connect(_on_obstacle_approached)

	print("Created enhanced volcano at ", position, " height: ", height, " lava: ", volcano.has_lava_flow)
	return volcano

func create_spire_obstacle(position: Vector2, height: float) -> Node2D:
	"""Create a spire obstacle using the enhanced SpireObstacle scene"""
	if not spire_prefab:
		print("Error: Spire prefab not loaded")
		return null

	var spire = spire_prefab.instantiate()
	spire.position = position
	spire.height = height
	spire.width = randf_range(30, 70)

	# Choose spire type based on difficulty and randomness
	var type_roll = randf()
	if difficulty_multiplier > 1.5 and type_roll < 0.1:
		spire.spire_type = SpireObstacle.SpireType.CRYSTAL  # Rare, high difficulty
	elif difficulty_multiplier > 1.2 and type_roll < 0.2:
		spire.spire_type = SpireObstacle.SpireType.CLUSTER  # Challenging clusters
	elif type_roll < 0.15:
		spire.spire_type = SpireObstacle.SpireType.ARCH     # Provides navigation opportunity
	elif type_roll < 0.25:
		spire.spire_type = SpireObstacle.SpireType.LEANING  # Moderate difficulty
	else:
		spire.spire_type = SpireObstacle.SpireType.SINGLE   # Most common

	spire.rock_hardness = 0.8 + (difficulty_multiplier * 0.2)

	# Connect signals
	spire.obstacle_passed.connect(_on_spire_passed)
	spire.obstacle_approached.connect(_on_obstacle_approached)

	print("Created enhanced spire at ", position, " type: ", SpireObstacle.SpireType.keys()[spire.spire_type])
	return spire

# Public interface
func set_obstacle_density(density: float):
	"""Set obstacle generation density"""
	obstacle_density = clamp(density, 0.1, 1.0)

func set_gap_size_range(min_size: float, max_size: float):
	"""Set navigable gap size range"""
	min_gap_size = min_size
	max_gap_size = max_size

func get_generation_stats() -> Dictionary:
	"""Get current generation statistics"""
	return {
		"difficulty_multiplier": difficulty_multiplier,
		"obstacle_density": obstacle_density,
		"min_gap_size": min_gap_size,
		"max_gap_size": max_gap_size,
		"pattern_count": pattern_templates.size()
	}

# Signal handlers for obstacle events
func _on_volcano_passed(volcano: VolcanoObstacle):
	"""Handle volcano being successfully passed"""
	print("Volcano passed! Difficulty: ", volcano.get_difficulty_rating())

	# Base pass scores 3 points, lava flows score 5 — routed through the combo system
	# so chained passes multiply and a single collision resets the streak.
	var base_points := 5 if volcano.has_lava_flow else 3
	GameManager.register_obstacle_pass(base_points)

func _on_spire_passed(spire: SpireObstacle):
	"""Handle spire being successfully passed"""
	print("Spire passed! Type: ", SpireObstacle.SpireType.keys()[spire.spire_type])

	var base_points := 3
	match spire.spire_type:
		SpireObstacle.SpireType.CRYSTAL:
			base_points = 10  # Big bonus for crystal spires
		SpireObstacle.SpireType.CLUSTER:
			base_points = 5   # Bonus for cluster navigation
	GameManager.register_obstacle_pass(base_points)

func _on_obstacle_approached(obstacle: Node, distance: float):
	"""Handle player approaching any obstacle"""
	# Could trigger proximity warnings, environmental effects, etc.
	if distance < 80.0:  # Very close approach
		# Award style points for close navigation
		GameManager.add_score(2)

# Strategic obstacle placement functions
func create_strategic_challenge(chunk_data: Dictionary, challenge_type: String):
	"""Create specific strategic challenges"""
	match challenge_type:
		"precision_course":
			create_precision_course(chunk_data)
		"altitude_challenge":
			create_altitude_challenge(chunk_data)
		"speed_section":
			create_speed_section(chunk_data)

func create_precision_course(chunk_data: Dictionary):
	"""Create a course requiring precise navigation"""
	var position = chunk_data.position + 400.0

	# Series of narrow spires requiring weaving
	for i in 3:
		var spire_x = position + (i * 200.0)
		var spire_y = 540.0 + (sin(i * PI / 2.0) * 100.0)  # Vertical offset pattern

		var spire = create_spire_obstacle(Vector2(spire_x, spire_y), randf_range(250, 350))
		if spire:
			spire.spire_type = SpireObstacle.SpireType.SINGLE
			spire.width = 35.0  # Make them narrow for precision
			chunk_data.obstacles.append(spire)

func create_altitude_challenge(chunk_data: Dictionary):
	"""Create a challenge requiring altitude management"""
	var position = chunk_data.position + 600.0

	# High volcano followed by low passage
	var high_volcano = create_volcano_obstacle(Vector2(position, 540), 450.0)
	var low_spire = create_spire_obstacle(Vector2(position + 300.0, 200), 150.0)

	if high_volcano and low_spire:
		chunk_data.obstacles.append(high_volcano)
		chunk_data.obstacles.append(low_spire)

func create_speed_section(chunk_data: Dictionary):
	"""Create a section encouraging speed"""
	var position = chunk_data.position + 200.0

	# Wide gaps but with time pressure from following obstacles
	for i in 2:
		var volcano = create_volcano_obstacle(Vector2(position + (i * 400.0), 540), randf_range(200, 300))
		if volcano:
			volcano.width = 60.0  # Make them narrower to encourage speed
			chunk_data.obstacles.append(volcano)