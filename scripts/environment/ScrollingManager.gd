extends Node
class_name ScrollingManager

# Scrolling environment management for Sugar Glider Adventure
signal scroll_speed_changed(new_speed: float)
signal chunk_loaded(chunk_position: float)
signal chunk_unloaded(chunk_position: float)

# Scrolling configuration
var base_scroll_speed: float = 200.0
var current_scroll_speed: float = 200.0
var max_scroll_speed: float = 500.0
var scroll_acceleration: float = 10.0  # Speed increase per second

# Parallax layers
var parallax_background: ParallaxBackground
var parallax_layers: Array[ParallaxLayer] = []

# Layer configuration (speed multipliers)
var layer_speeds: Array[float] = [0.1, 0.3, 0.6, 1.0, 1.2]
var layer_names: Array[String] = ["DistantMountains", "MiddleVolcanoes", "ForegroundSpires", "GameplayLayer", "ForegroundEffects"]

# Chunk management
var chunk_width: float = 2000.0
var active_chunks: Dictionary = {}
var chunk_preload_distance: float = 3000.0
var chunk_cleanup_distance: float = 1000.0

# Player tracking
var player_position: Vector2 = Vector2.ZERO
var camera_position: Vector2 = Vector2.ZERO
var distance_traveled: float = 0.0
var start_position: float = 0.0

# Environmental effects
var wind_strength: float = 0.0
var wind_direction: Vector2 = Vector2.ZERO
var thermal_zones: Array[Rect2] = []
var _thermal_zones_generated_for_chunk: int = -999999  # Track which chunk thermals were generated for

# References
var terrain_generator: TerrainGenerator
var game_world: Node2D

func _ready():
	# Find required nodes
	setup_node_references()

	# Initialize scrolling system
	initialize_scrolling()

	# Connect to game systems
	setup_connections()

	print("ScrollingManager initialized")

func _process(delta):
	if GameManager.is_playing():
		update_scrolling(delta)
		update_distance_tracking(delta)
		manage_chunks()
		update_environmental_effects(delta)

func setup_node_references():
	"""Find and cache references to required nodes"""
	# Find the game world node
	game_world = get_tree().get_first_node_in_group("game_world")
	if not game_world:
		game_world = get_parent()

	# Find parallax background
	parallax_background = game_world.get_node_or_null("Background")

	if parallax_background:
		# Get all parallax layers
		for child in parallax_background.get_children():
			if child is ParallaxLayer:
				parallax_layers.append(child)

	# Find terrain generator
	terrain_generator = get_node_or_null("../TerrainGenerator")

func initialize_scrolling():
	"""Initialize the scrolling system"""
	current_scroll_speed = base_scroll_speed
	start_position = camera_position.x

	# Configure parallax layers
	setup_parallax_layers()

	print("Scrolling initialized - Base speed: ", base_scroll_speed)

func setup_parallax_layers():
	"""Configure parallax layer motion scales"""
	if not parallax_background:
		print("Warning: No ParallaxBackground found")
		return

	var layer_index = 0
	for layer in parallax_layers:
		if layer_index < layer_speeds.size():
			layer.motion_scale = Vector2(layer_speeds[layer_index], layer_speeds[layer_index])
			layer.motion_mirroring = Vector2(chunk_width * 2, 0)  # Enable horizontal wrapping

			print("Layer ", layer.name, " - Motion scale: ", layer.motion_scale.x)
		layer_index += 1

func setup_connections():
	"""Set up signal connections"""
	# Connect to GameManager
	GameManager.game_state_changed.connect(_on_game_state_changed)
	GameManager.difficulty_changed.connect(_on_difficulty_changed)

	# Find and connect to player
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		# Try to find player through scene structure
		var game_world_node = get_tree().get_first_node_in_group("game_world")
		if game_world_node:
			player = game_world_node.get_node_or_null("PlayArea/SugarGlider")

	if is_instance_valid(player) and player.has_signal("position_changed"):
		player.position_changed.connect(_on_player_position_changed)
		print("Connected to player")

func update_scrolling(delta):
	"""Update scrolling speed and parallax motion"""
	# Gradually increase scroll speed based on difficulty
	var target_speed = base_scroll_speed * GameManager.get_difficulty_multiplier() * GameManager.get_scroll_speed_multiplier()
	target_speed = min(target_speed, max_scroll_speed)

	# Smooth speed transition
	if current_scroll_speed != target_speed:
		current_scroll_speed = lerp(current_scroll_speed, target_speed, scroll_acceleration * delta)
		emit_signal("scroll_speed_changed", current_scroll_speed)

	# Update parallax background motion
	if parallax_background:
		parallax_background.scroll_offset.x -= current_scroll_speed * delta

func update_distance_tracking(delta):
	"""Track distance traveled for progression"""
	var distance_increment = current_scroll_speed * delta
	distance_traveled += distance_increment

	# Update GameManager with distance
	GameManager.update_distance(distance_traveled)

func manage_chunks():
	"""Manage loading and unloading of terrain chunks"""
	if not terrain_generator:
		return

	var current_chunk = int(camera_position.x / chunk_width)

	# Load chunks ahead of player
	for i in range(-1, 4):  # Load current chunk and 3 ahead
		var chunk_id = current_chunk + i
		var chunk_position = chunk_id * chunk_width

		if not active_chunks.has(chunk_id):
			load_chunk(chunk_id, chunk_position)

	# Unload chunks behind player
	var chunks_to_remove = []
	for chunk_id in active_chunks.keys():
		var chunk_position = chunk_id * chunk_width
		if chunk_position < camera_position.x - chunk_cleanup_distance:
			chunks_to_remove.append(chunk_id)

	for chunk_id in chunks_to_remove:
		unload_chunk(chunk_id)

func load_chunk(chunk_id: int, position: float):
	"""Load a terrain chunk at the specified position"""
	if active_chunks.has(chunk_id):
		return

	# Create chunk data
	var chunk_data = {
		"id": chunk_id,
		"position": position,
		"obstacles": [],
		"hazards": [],
		"effects": []
	}

	# Generate terrain for this chunk
	if terrain_generator:
		terrain_generator.generate_chunk(chunk_data)

	active_chunks[chunk_id] = chunk_data
	emit_signal("chunk_loaded", position)

	print("Loaded chunk ", chunk_id, " at position ", position)

func unload_chunk(chunk_id: int):
	"""Unload a terrain chunk"""
	if not active_chunks.has(chunk_id):
		return

	var chunk_data = active_chunks[chunk_id]

	# Clean up chunk objects
	for obstacle in chunk_data.obstacles:
		if is_instance_valid(obstacle):
			obstacle.queue_free()

	for hazard in chunk_data.hazards:
		if is_instance_valid(hazard):
			hazard.queue_free()

	for effect in chunk_data.effects:
		if is_instance_valid(effect):
			effect.queue_free()

	active_chunks.erase(chunk_id)
	emit_signal("chunk_unloaded", chunk_data.position)

	print("Unloaded chunk ", chunk_id)

func update_environmental_effects(delta):
	"""Update environmental effects like wind and thermals"""
	# Update wind effects (simple sinusoidal pattern)
	var time = Time.get_ticks_msec() / 1000.0
	wind_strength = sin(time * 0.5) * 50.0
	wind_direction = Vector2(cos(time * 0.3), sin(time * 0.7)) * wind_strength

	# Update thermal zones (placeholder - would be more sophisticated)
	update_thermal_zones()

	# Apply effects to player
	apply_environmental_effects_to_player()

func update_thermal_zones():
	"""Update thermal updraft zones — only regenerate when the camera enters a new chunk"""
	var current_chunk = int(camera_position.x / chunk_width)
	if current_chunk == _thermal_zones_generated_for_chunk:
		return  # Thermals already generated for this chunk; skip redundant work

	_thermal_zones_generated_for_chunk = current_chunk
	thermal_zones.clear()

	var thermal_spacing = 800.0
	var thermal_start = camera_position.x - 500.0
	var thermal_count = 5

	for i in thermal_count:
		var thermal_x = thermal_start + (i * thermal_spacing)
		var thermal_y = randf_range(300, 700)
		var thermal_size = Vector2(150, 200)

		thermal_zones.append(Rect2(thermal_x, thermal_y, thermal_size.x, thermal_size.y))

func apply_environmental_effects_to_player():
	"""Apply wind and thermal effects to the player"""
	var player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player) or not player.has_method("set_wind_effect"):
		return

	# Apply wind effect
	player.set_wind_effect(wind_direction)

	# Check if player is in thermal zone
	var in_thermal = false
	if is_instance_valid(player):
		for thermal in thermal_zones:
			if thermal.has_point(player.global_position):
				in_thermal = true
				break

	if player.has_method("set_in_thermal"):
		player.set_in_thermal(in_thermal)

# Signal handlers
func _on_game_state_changed(new_state):
	"""Handle game state changes"""
	match new_state:
		GameManager.GameState.PLAYING:
			# Resume scrolling
			set_process(true)
		GameManager.GameState.PAUSED:
			# Pause scrolling
			set_process(false)
		GameManager.GameState.GAME_OVER:
			# Stop scrolling
			current_scroll_speed = 0.0

func _on_difficulty_changed(new_difficulty: float):
	"""Handle difficulty changes"""
	print("ScrollingManager: Difficulty changed to ", new_difficulty)

func _on_player_position_changed(new_position: Vector2):
	"""Update player position tracking"""
	player_position = new_position
	camera_position = new_position  # Simplified - in full game would use actual camera position

# Public interface functions
func get_scroll_speed() -> float:
	return current_scroll_speed

func get_distance_traveled() -> float:
	return distance_traveled

func set_scroll_speed_multiplier(multiplier: float):
	"""Set scroll speed multiplier for special effects"""
	current_scroll_speed = base_scroll_speed * multiplier

func pause_scrolling():
	"""Pause all scrolling"""
	set_process(false)

func resume_scrolling():
	"""Resume scrolling"""
	set_process(true)

func get_active_chunk_count() -> int:
	return active_chunks.size()

func get_wind_effect() -> Vector2:
	return wind_direction

func is_position_in_thermal(position: Vector2) -> bool:
	"""Check if a position is in a thermal zone"""
	for thermal in thermal_zones:
		if thermal.has_point(position):
			return true
	return false

# Debug functions
func get_debug_info() -> Dictionary:
	return {
		"scroll_speed": current_scroll_speed,
		"distance_traveled": distance_traveled,
		"active_chunks": active_chunks.size(),
		"wind_strength": wind_strength,
		"thermal_zones": thermal_zones.size(),
		"camera_position": camera_position
	}