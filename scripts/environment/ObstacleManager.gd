extends Node
class_name ObstacleManager

# Strategic obstacle management and navigation assistance
signal strategic_hint_available(hint_text: String, hint_type: String)
signal navigation_path_calculated(safe_points: Array[Vector2])
signal obstacle_cluster_detected(cluster_center: Vector2, difficulty: float)

# Obstacle tracking
var active_obstacles: Array[Node2D] = []
var upcoming_obstacles: Array[Node2D] = []
var obstacle_clusters: Array[Dictionary] = []

# Strategic analysis
var lookahead_distance: float = 800.0
var cluster_detection_radius: float = 300.0
var hint_cooldown_time: float = 3.0
var last_hint_time: float = 0.0

# Navigation assistance
var show_navigation_hints: bool = true
var adaptive_difficulty: bool = true
var player_skill_level: float = 1.0

# Performance tracking
var obstacles_passed: int = 0
var perfect_navigations: int = 0
var close_calls: int = 0

# References
var player: SugarGlider
var scrolling_manager: ScrollingManager

func _ready():
	# Find required components
	setup_references()

	# Connect to relevant systems
	setup_connections()

	print("ObstacleManager initialized")

func _process(delta):
	if GameManager.is_playing():
		update_obstacle_tracking()
		analyze_upcoming_challenges()
		update_player_skill_assessment(delta)

func setup_references():
	"""Find and cache references to required components"""
	player = get_tree().get_first_node_in_group("player")
	scrolling_manager = get_node_or_null("../ScrollingManager")

func setup_connections():
	"""Set up signal connections"""
	# Connect to GameManager for player performance tracking
	GameManager.score_updated.connect(_on_score_updated)

	# Find terrain generator for obstacle creation events
	var terrain_generator = get_node_or_null("../ScrollingManager/TerrainGenerator")
	if terrain_generator:
		terrain_generator.obstacle_spawned.connect(_on_obstacle_spawned)

func update_obstacle_tracking():
	"""Update tracking of active and upcoming obstacles"""
	if not is_instance_valid(player):
		return

	var player_x = player.global_position.x

	# Update active obstacles list (obstacles near player)
	active_obstacles.clear()
	upcoming_obstacles.clear()

	# Find all obstacles in the game world
	var all_obstacles = get_tree().get_nodes_in_group("obstacles")
	if all_obstacles.is_empty():
		# Fallback: search for obstacles by type
		all_obstacles = []
		var terrain_container = get_tree().get_first_node_in_group("terrain_container")
		if terrain_container:
			for child in terrain_container.get_children():
				if child is VolcanoObstacle or child is SpireObstacle:
					all_obstacles.append(child)

	for obstacle in all_obstacles:
		if not is_instance_valid(obstacle):
			continue

		var obstacle_x = obstacle.global_position.x
		var distance_ahead = obstacle_x - player_x

		if distance_ahead > -200 and distance_ahead < lookahead_distance:
			if distance_ahead > 0:
				upcoming_obstacles.append(obstacle)
			else:
				active_obstacles.append(obstacle)

	# Sort upcoming obstacles by distance
	upcoming_obstacles.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)

func analyze_upcoming_challenges():
	"""Analyze upcoming obstacles for strategic hints"""
	if not show_navigation_hints or upcoming_obstacles.is_empty():
		return

	# Check for obstacle clusters
	detect_obstacle_clusters()

	# Generate navigation hints
	generate_navigation_hints()

func detect_obstacle_clusters():
	"""Detect clusters of obstacles that require strategic navigation"""
	obstacle_clusters.clear()

	if upcoming_obstacles.size() < 2:
		return

	var current_cluster = []
	var cluster_start_x = upcoming_obstacles[0].global_position.x

	for i in range(upcoming_obstacles.size()):
		var obstacle = upcoming_obstacles[i]
		var obstacle_x = obstacle.global_position.x

		# If obstacle is within cluster radius, add to current cluster
		if obstacle_x - cluster_start_x <= cluster_detection_radius:
			current_cluster.append(obstacle)
		else:
			# Finalize current cluster if it has multiple obstacles
			if current_cluster.size() >= 2:
				finalize_obstacle_cluster(current_cluster)

			# Start new cluster
			current_cluster = [obstacle]
			cluster_start_x = obstacle_x

	# Don't forget the last cluster
	if current_cluster.size() >= 2:
		finalize_obstacle_cluster(current_cluster)

func finalize_obstacle_cluster(cluster_obstacles: Array):
	"""Finalize and analyze an obstacle cluster"""
	var cluster_center = Vector2.ZERO
	var total_difficulty = 0.0

	# Calculate cluster center and difficulty
	for obstacle in cluster_obstacles:
		cluster_center += obstacle.global_position
		if obstacle.has_method("get_difficulty_rating"):
			total_difficulty += obstacle.get_difficulty_rating()

	cluster_center /= cluster_obstacles.size()
	total_difficulty /= cluster_obstacles.size()

	var cluster_data = {
		"center": cluster_center,
		"obstacles": cluster_obstacles,
		"difficulty": total_difficulty,
		"type": determine_cluster_type(cluster_obstacles)
	}

	obstacle_clusters.append(cluster_data)
	emit_signal("obstacle_cluster_detected", cluster_center, total_difficulty)

func determine_cluster_type(cluster_obstacles: Array) -> String:
	"""Determine the strategic type of an obstacle cluster"""
	var volcano_count = 0
	var spire_count = 0
	var has_special = false

	for obstacle in cluster_obstacles:
		if obstacle is VolcanoObstacle:
			volcano_count += 1
			if obstacle.has_lava_flow:
				has_special = true
		elif obstacle is SpireObstacle:
			spire_count += 1
			if obstacle.spire_type != SpireObstacle.SpireType.SINGLE:
				has_special = true

	if volcano_count > spire_count:
		return "volcanic_field" if has_special else "volcano_cluster"
	elif spire_count > volcano_count:
		return "spire_maze" if has_special else "spire_cluster"
	else:
		return "mixed_hazards"

func generate_navigation_hints():
	"""Generate strategic navigation hints for upcoming challenges"""
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_hint_time < hint_cooldown_time:
		return

	# Analyze the most immediate challenge
	if upcoming_obstacles.is_empty():
		return

	var next_obstacle = upcoming_obstacles[0]
	if not is_instance_valid(player):
		return
	var distance_to_obstacle = next_obstacle.global_position.distance_to(player.global_position)

	# Only give hints for reasonably close obstacles
	if distance_to_obstacle > 400.0:
		return

	var hint = generate_hint_for_obstacle(next_obstacle)
	if hint != "":
		emit_signal("strategic_hint_available", hint, "navigation")
		last_hint_time = current_time

func generate_hint_for_obstacle(obstacle: Node2D) -> String:
	"""Generate a strategic hint for a specific obstacle"""
	if obstacle is VolcanoObstacle:
		return generate_volcano_hint(obstacle)
	elif obstacle is SpireObstacle:
		return generate_spire_hint(obstacle)

	# Fallback for unknown obstacle types
	return "OBSTACLE AHEAD"

func generate_volcano_hint(volcano: VolcanoObstacle) -> String:
	"""Generate hint for volcano navigation"""
	var hints = []

	if volcano.height > 400.0:
		hints.append("High volcano ahead - consider side approach")
	if volcano.has_lava_flow:
		hints.append("Lava flow detected - maintain safe distance")
	if volcano.width > 120.0:
		hints.append("Wide volcano - plan your route early")

	# Consider player's energy level
	if is_instance_valid(player) and player.is_low_energy():
		hints.append("Low energy - choose efficient path")

	return hints[0] if not hints.is_empty() else ""

func generate_spire_hint(spire: SpireObstacle) -> String:
	"""Generate hint for spire navigation"""
	match spire.spire_type:
		SpireObstacle.SpireType.SINGLE:
			if spire.height > 350.0:
				return "Tall spire - fly around or gain altitude"
		SpireObstacle.SpireType.CLUSTER:
			return "Spire cluster ahead - wide approach recommended"
		SpireObstacle.SpireType.ARCH:
			return "Arch spire - threading the gap possible"
		SpireObstacle.SpireType.LEANING:
			return "Leaning spire - avoid the lean side"
		SpireObstacle.SpireType.CRYSTAL:
			return "Crystal spire - beware wind effects"

	return ""

func calculate_optimal_path(target_distance: float) -> Array[Vector2]:
	"""Calculate optimal navigation path through upcoming obstacles"""
	var safe_points = []
	var current_pos = player.global_position if is_instance_valid(player) else Vector2.ZERO

	# Get safe passage points from upcoming obstacles
	for obstacle in upcoming_obstacles:
		if obstacle.global_position.x > current_pos.x + target_distance:
			break

		if obstacle.has_method("get_safe_passage_points"):
			var obstacle_safe_points = obstacle.get_safe_passage_points()
			safe_points.append_array(obstacle_safe_points)

	# Filter and optimize the path
	return optimize_navigation_path(safe_points, current_pos)

func optimize_navigation_path(safe_points: Array[Vector2], start_pos: Vector2) -> Array[Vector2]:
	"""Optimize a navigation path for smooth gliding"""
	if safe_points.is_empty():
		return []

	# Sort points by x-coordinate (forward progress)
	safe_points.sort_custom(func(a, b): return a.x < b.x)

	# Select best points considering energy efficiency and safety
	var optimized_path = []
	var last_point = start_pos

	for point in safe_points:
		# Only add points that represent forward progress
		if point.x > last_point.x + 50.0:  # Minimum forward distance
			# Prefer points that don't require excessive altitude changes
			var altitude_change = abs(point.y - last_point.y)
			if altitude_change < 200.0:  # Reasonable altitude change
				optimized_path.append(point)
				last_point = point

	return optimized_path

func update_player_skill_assessment(delta: float):
	"""Update assessment of player skill for adaptive difficulty"""
	if not is_instance_valid(player):
		return

	# Track various skill metrics
	var player_energy_ratio = player.get_energy_percentage()
	var current_score = GameManager.get_current_score()

	# Assess skill based on performance
	if player_energy_ratio > 0.7:
		player_skill_level += 0.1 * delta  # Good energy management
	if close_calls > 0 and obstacles_passed > 0:
		var close_call_ratio = float(close_calls) / obstacles_passed
		if close_call_ratio < 0.3:  # Low close call ratio = skillful
			player_skill_level += 0.05 * delta

	# Adaptive hint frequency based on skill
	if player_skill_level > 1.5:
		hint_cooldown_time = 5.0  # Less frequent hints for skilled players
	else:
		hint_cooldown_time = 2.0  # More frequent hints for beginners

	player_skill_level = clamp(player_skill_level, 0.5, 3.0)

# Signal handlers
func _on_obstacle_spawned(obstacle: Node2D, type: String):
	"""Handle new obstacle creation"""
	# Add obstacle to appropriate group for tracking
	if obstacle:
		obstacle.add_to_group("obstacles")

func _on_score_updated(new_score: int):
	"""Track scoring patterns for skill assessment"""
	# Could analyze scoring patterns to assess player performance
	pass

# Public interface functions
func get_navigation_hint_for_position(position: Vector2) -> String:
	"""Get navigation hint for a specific position"""
	# Find nearest upcoming obstacle
	var nearest_obstacle = null
	var min_distance = INF

	for obstacle in upcoming_obstacles:
		var distance = obstacle.global_position.distance_to(position)
		if distance < min_distance:
			min_distance = distance
			nearest_obstacle = obstacle

	if nearest_obstacle:
		return generate_hint_for_obstacle(nearest_obstacle)

	return ""

func get_safe_altitude_range() -> Vector2:
	"""Get recommended safe altitude range considering upcoming obstacles"""
	var min_safe = 200.0
	var max_safe = 800.0

	var obstacles_to_check = upcoming_obstacles.slice(0, min(3, upcoming_obstacles.size()))
	for obstacle in obstacles_to_check:
		if obstacle.has_method("get_safe_passage_points"):
			var safe_points = obstacle.get_safe_passage_points()
			for point in safe_points:
				min_safe = min(min_safe, point.y - 50)
				max_safe = max(max_safe, point.y + 50)

	return Vector2(max(min_safe, 100), min(max_safe, 900))

func enable_navigation_assistance(enabled: bool):
	"""Enable or disable navigation assistance"""
	show_navigation_hints = enabled

func get_performance_stats() -> Dictionary:
	"""Get performance statistics"""
	return {
		"obstacles_passed": obstacles_passed,
		"perfect_navigations": perfect_navigations,
		"close_calls": close_calls,
		"skill_level": player_skill_level,
		"active_obstacles": active_obstacles.size(),
		"upcoming_obstacles": upcoming_obstacles.size()
	}