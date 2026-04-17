extends Node
class_name RocketManager

# Manages rocket launchers and creates escalating challenge patterns
signal challenge_wave_started(wave_name: String, difficulty: float)
signal all_clear_period(duration: float)
signal rocket_barrage_incoming(launcher_count: int)

# Challenge escalation
var base_difficulty: float = 1.0
var current_difficulty: float = 1.0
var difficulty_increase_rate: float = 0.15
var challenge_distance_interval: float = 1500.0  # Every 1500 units

# Launcher management
var active_launchers: Array[RocketLauncher] = []
var launcher_spawn_queue: Array[Dictionary] = []
var launcher_prefab: PackedScene = preload("res://scenes/hazards/RocketLauncher.tscn")

# Challenge patterns
var challenge_patterns: Array[Dictionary] = []
var current_wave_index: int = 0
var wave_timer: float = 0.0
var in_challenge_wave: bool = false

# Positioning and spawning
var ground_level: float = 540.0
var launcher_spacing_min: float = 300.0
var launcher_spacing_max: float = 600.0
var spawn_lookahead: float = 1200.0

# Player tracking
var player_reference: SugarGlider
var player_position: Vector2
var distance_traveled: float = 0.0

# Performance tracking
var rockets_fired: int = 0
var rockets_dodged: int = 0
var near_misses: int = 0

# References
var terrain_generator: TerrainGenerator
var hazard_container: Node2D

func _ready():
	setup_challenge_patterns()
	find_required_nodes()
	setup_connections()
	# Apply preset difficulty immediately on startup
	base_difficulty = GameManager.get_rocket_base_difficulty()
	current_difficulty = base_difficulty

	print("RocketManager initialized")

func _process(delta):
	if GameManager.is_playing():
		update_difficulty_scaling()
		update_launcher_spawning()
		update_challenge_waves(delta)
		cleanup_distant_launchers()

func setup_challenge_patterns():
	"""Define escalating challenge patterns"""
	challenge_patterns = [
		# Early game - Learning phase
		{
			"name": "Introduction",
			"min_difficulty": 0.0,
			"launchers": [
				{"type": RocketLauncher.LauncherType.SINGLE_SHOT, "pattern": RocketLauncher.LaunchPattern.STRAIGHT_UP}
			],
			"spawn_rate": 0.3,
			"duration": 10.0
		},

		# Basic evasion
		{
			"name": "Basic Barrage",
			"min_difficulty": 0.5,
			"launchers": [
				{"type": RocketLauncher.LauncherType.SINGLE_SHOT, "pattern": RocketLauncher.LaunchPattern.ANGLED_SHOT},
				{"type": RocketLauncher.LauncherType.RAPID_FIRE, "pattern": RocketLauncher.LaunchPattern.STRAIGHT_UP}
			],
			"spawn_rate": 0.4,
			"duration": 12.0
		},

		# Predictive challenge
		{
			"name": "Smart Targeting",
			"min_difficulty": 1.0,
			"launchers": [
				{"type": RocketLauncher.LauncherType.TRACKING_SITE, "pattern": RocketLauncher.LaunchPattern.PREDICTIVE},
				{"type": RocketLauncher.LauncherType.RAPID_FIRE, "pattern": RocketLauncher.LaunchPattern.ANGLED_SHOT}
			],
			"spawn_rate": 0.5,
			"duration": 15.0
		},

		# Area denial
		{
			"name": "Area Denial",
			"min_difficulty": 1.3,
			"launchers": [
				{"type": RocketLauncher.LauncherType.BARRAGE, "pattern": RocketLauncher.LaunchPattern.SPRAY_PATTERN},
				{"type": RocketLauncher.LauncherType.SMOKE_LAUNCHER, "pattern": RocketLauncher.LaunchPattern.BARRAGE_WALL}
			],
			"spawn_rate": 0.6,
			"duration": 18.0
		},

		# Advanced patterns
		{
			"name": "Coordinated Strike",
			"min_difficulty": 1.6,
			"launchers": [
				{"type": RocketLauncher.LauncherType.DEFENSE_TURRET, "pattern": RocketLauncher.LaunchPattern.WAVE_PATTERN},
				{"type": RocketLauncher.LauncherType.CLUSTER_LAUNCHER, "pattern": RocketLauncher.LaunchPattern.PREDICTIVE},
				{"type": RocketLauncher.LauncherType.TRACKING_SITE, "pattern": RocketLauncher.LaunchPattern.AMBUSH}
			],
			"spawn_rate": 0.7,
			"duration": 20.0
		},

		# Expert level
		{
			"name": "Maximum Threat",
			"min_difficulty": 2.0,
			"launchers": [
				{"type": RocketLauncher.LauncherType.MEGA_LAUNCHER, "pattern": RocketLauncher.LaunchPattern.BARRAGE_WALL},
				{"type": RocketLauncher.LauncherType.DEFENSE_TURRET, "pattern": RocketLauncher.LaunchPattern.SPRAY_PATTERN},
				{"type": RocketLauncher.LauncherType.TRACKING_SITE, "pattern": RocketLauncher.LaunchPattern.PREDICTIVE}
			],
			"spawn_rate": 0.8,
			"duration": 25.0
		}
	]

func find_required_nodes():
	"""Find required node references"""
	player_reference = get_tree().get_first_node_in_group("player")
	terrain_generator = get_node_or_null("../TerrainGenerator")

	# Find hazard container
	var game_world = get_tree().get_first_node_in_group("game_world")
	if game_world:
		hazard_container = game_world.get_node_or_null("PlayArea/HazardContainer")

func setup_connections():
	"""Set up signal connections"""
	# Connect to GameManager for distance tracking
	GameManager.distance_updated.connect(_on_distance_updated)
	GameManager.difficulty_changed.connect(_on_difficulty_changed)
	GameManager.difficulty_preset_changed.connect(_on_difficulty_preset_changed)

	# Connect to terrain generator for chunk events
	if terrain_generator:
		terrain_generator.terrain_feature_created.connect(_on_terrain_feature_created)

func update_difficulty_scaling():
	"""Update difficulty based on player progress"""
	var distance_factor = distance_traveled / challenge_distance_interval
	current_difficulty = base_difficulty + (distance_factor * difficulty_increase_rate)
	current_difficulty = min(current_difficulty, 3.0)  # Cap at 3.0

func update_launcher_spawning():
	"""Update spawning of new launchers"""
	if not is_instance_valid(player_reference) or not hazard_container:
		return

	player_position = player_reference.global_position

	# Check if we need to spawn new launchers
	if should_spawn_launcher():
		spawn_launcher_ahead()

func should_spawn_launcher() -> bool:
	"""Determine if we should spawn a new launcher"""
	# Check current pattern requirements
	var current_pattern = get_current_challenge_pattern()
	if not current_pattern:
		return false

	# Check spawn rate
	var spawn_chance = current_pattern.spawn_rate * current_difficulty
	return randf() < spawn_chance * get_process_delta_time()  # Frame-rate independent probability

func get_current_challenge_pattern() -> Dictionary:
	"""Get the challenge pattern appropriate for current difficulty"""
	var suitable_patterns = []

	for pattern in challenge_patterns:
		if current_difficulty >= pattern.min_difficulty:
			suitable_patterns.append(pattern)

	if suitable_patterns.is_empty():
		return challenge_patterns[0]  # Fallback to first pattern

	# Return most advanced suitable pattern
	return suitable_patterns[-1]

func spawn_launcher_ahead():
	"""Spawn a launcher ahead of the player"""
	var spawn_x = player_position.x + spawn_lookahead + randf_range(200, 400)
	var spawn_y = ground_level + randf_range(-50, 20)  # Slightly varied ground level

	# Check for clear space
	if not is_spawn_position_clear(Vector2(spawn_x, spawn_y)):
		return

	var current_pattern = get_current_challenge_pattern()
	var launcher_config = choose_launcher_config(current_pattern)

	create_launcher(Vector2(spawn_x, spawn_y), launcher_config)

func is_spawn_position_clear(position: Vector2) -> bool:
	"""Check if spawn position is clear of obstacles"""
	var min_distance = launcher_spacing_min

	# Check distance from existing launchers
	for launcher in active_launchers:
		if is_instance_valid(launcher):
			if launcher.global_position.distance_to(position) < min_distance:
				return false

	# Could check for terrain obstacles here
	return true

func choose_launcher_config(pattern: Dictionary) -> Dictionary:
	"""Choose a launcher configuration from the pattern"""
	if pattern.launchers.is_empty():
		return {"type": RocketLauncher.LauncherType.SINGLE_SHOT, "pattern": RocketLauncher.LaunchPattern.STRAIGHT_UP}

	var launcher_configs = pattern.launchers
	return launcher_configs[randi() % launcher_configs.size()]

const MAX_ACTIVE_LAUNCHERS: int = 20

func create_launcher(position: Vector2, config: Dictionary):
	"""Create a rocket launcher at the specified position"""
	if not launcher_prefab:
		push_warning("RocketManager: launcher_prefab is null, cannot create launcher")
		return

	if active_launchers.size() >= MAX_ACTIVE_LAUNCHERS:
		return

	var launcher = launcher_prefab.instantiate()
	launcher.global_position = position
	launcher.launcher_type = config.type
	launcher.launch_pattern = config.pattern

	# Configure based on difficulty
	configure_launcher_for_difficulty(launcher, current_difficulty)

	# Connect signals
	launcher.rocket_launched.connect(_on_rocket_launched)
	launcher.warning_activated.connect(_on_launcher_warning_activated)

	hazard_container.add_child(launcher)
	active_launchers.append(launcher)

	print("Spawned launcher: ", RocketLauncher.LauncherType.keys()[config.type], " at ", position)

func configure_launcher_for_difficulty(launcher: RocketLauncher, difficulty: float):
	"""Configure launcher properties based on difficulty"""
	# Reduce reload times
	launcher.reload_time *= (2.0 - clamp(difficulty / 2.0, 0.0, 0.5))
	launcher.reload_time = max(launcher.reload_time, 0.1)  # Prevent infinite fire rate

	# Reduce warning times for higher difficulty, then apply preset multiplier
	launcher.warning_time *= (2.0 - clamp(difficulty / 3.0, 0.0, 0.7))
	launcher.warning_time *= GameManager.get_warning_time_multiplier()
	# Floor: ensure players always get a meaningful reaction window, even on EXTREME.
	launcher.warning_time = max(launcher.warning_time, 0.5)

	# Increase detection range
	launcher.detection_range *= (1.0 + clamp(difficulty / 4.0, 0.0, 0.5))

	# More rockets per salvo for some launcher types
	if launcher.launcher_type in [RocketLauncher.LauncherType.BARRAGE, RocketLauncher.LauncherType.MEGA_LAUNCHER]:
		launcher.rockets_per_salvo += int(difficulty)

func update_challenge_waves(delta):
	"""Update special challenge wave events"""
	wave_timer += delta

	# Check for wave events
	if not in_challenge_wave and wave_timer > 30.0:  # Every 30 seconds
		if randf() < 0.3:  # 30% chance
			start_challenge_wave()
			wave_timer = 0.0

func start_challenge_wave():
	"""Start a special challenge wave"""
	in_challenge_wave = true
	var wave_patterns = [
		"synchronized_barrage",
		"tracking_swarm",
		"cluster_bomb_field",
		"smoke_screen_assault",
		"mega_launcher_event"
	]

	var wave_name = wave_patterns[randi() % wave_patterns.size()]
	execute_challenge_wave(wave_name)

	emit_signal("challenge_wave_started", wave_name, current_difficulty)

func execute_challenge_wave(wave_name: String):
	"""Execute specific challenge wave patterns"""
	match wave_name:
		"synchronized_barrage":
			create_synchronized_barrage()
		"tracking_swarm":
			create_tracking_swarm()
		"cluster_bomb_field":
			create_cluster_bomb_field()
		"smoke_screen_assault":
			create_smoke_screen_assault()
		"mega_launcher_event":
			create_mega_launcher_event()

	# End wave after duration
	get_tree().create_timer(20.0).timeout.connect(end_challenge_wave)

func create_synchronized_barrage():
	"""Create multiple launchers that fire in sequence"""
	var launcher_count = 3 + int(current_difficulty)
	var base_x = player_position.x + 400.0

	for i in launcher_count:
		var launcher_x = base_x + (i * 200.0)
		var config = {"type": RocketLauncher.LauncherType.BARRAGE, "pattern": RocketLauncher.LaunchPattern.WAVE_PATTERN}

		create_launcher(Vector2(launcher_x, ground_level), config)

		# Stagger activation
		var launcher = active_launchers[-1]
		launcher.warning_time += i * 1.0

func create_tracking_swarm():
	"""Create multiple tracking launchers"""
	var launcher_count = 2 + int(current_difficulty / 1.5)

	for i in launcher_count:
		var angle = (PI * 2.0 / launcher_count) * i
		var launcher_pos = player_position + Vector2.from_angle(angle) * 600.0
		launcher_pos.y = ground_level

		var config = {"type": RocketLauncher.LauncherType.TRACKING_SITE, "pattern": RocketLauncher.LaunchPattern.PREDICTIVE}
		create_launcher(launcher_pos, config)

func create_cluster_bomb_field():
	"""Create field of cluster bomb launchers"""
	var launcher_count = 4

	for i in launcher_count:
		var launcher_x = player_position.x + 300.0 + (i * 150.0)
		var config = {"type": RocketLauncher.LauncherType.CLUSTER_LAUNCHER, "pattern": RocketLauncher.LaunchPattern.STRAIGHT_UP}

		create_launcher(Vector2(launcher_x, ground_level), config)

func create_smoke_screen_assault():
	"""Create smoke launchers followed by hidden threats"""
	# First wave: smoke launchers
	for i in 2:
		var launcher_x = player_position.x + 400.0 + (i * 300.0)
		var config = {"type": RocketLauncher.LauncherType.SMOKE_LAUNCHER, "pattern": RocketLauncher.LaunchPattern.BARRAGE_WALL}

		create_launcher(Vector2(launcher_x, ground_level), config)

	# Delayed second wave: hidden threats
	get_tree().create_timer(3.0).timeout.connect(func():
		for i in 2:
			var launcher_x = player_position.x + 600.0 + (i * 200.0)
			var config = {"type": RocketLauncher.LauncherType.RAPID_FIRE, "pattern": RocketLauncher.LaunchPattern.AMBUSH}

			create_launcher(Vector2(launcher_x, ground_level), config)
	)

func create_mega_launcher_event():
	"""Create a single mega launcher challenge"""
	var launcher_x = player_position.x + 800.0
	var config = {"type": RocketLauncher.LauncherType.MEGA_LAUNCHER, "pattern": RocketLauncher.LaunchPattern.BARRAGE_WALL}

	create_launcher(Vector2(launcher_x, ground_level), config)

	# Add supporting launchers
	for i in range(-1, 2):
		if i == 0:
			continue
		var support_x = launcher_x + (i * 400.0)
		var support_config = {"type": RocketLauncher.LauncherType.DEFENSE_TURRET, "pattern": RocketLauncher.LaunchPattern.SPRAY_PATTERN}

		create_launcher(Vector2(support_x, ground_level), support_config)

func end_challenge_wave():
	"""End the current challenge wave"""
	in_challenge_wave = false
	print("Challenge wave ended")

	# Brief respite period
	emit_signal("all_clear_period", 5.0)

func cleanup_distant_launchers():
	"""Remove launchers that are too far behind the player"""
	var cleanup_distance = 1000.0

	for i in range(active_launchers.size() - 1, -1, -1):
		var launcher = active_launchers[i]
		if not is_instance_valid(launcher):
			active_launchers.remove_at(i)
			continue

		if player_position.x - launcher.global_position.x > cleanup_distance:
			launcher.queue_free()
			active_launchers.remove_at(i)

# Signal handlers
func _on_distance_updated(distance: float):
	"""Update distance tracking"""
	distance_traveled = distance

func _on_difficulty_changed(difficulty: float):
	"""Handle difficulty changes from GameManager"""
	pass

func _on_difficulty_preset_changed(preset: int):
	"""Reset rocket base difficulty when player changes difficulty preset"""
	base_difficulty = GameManager.get_rocket_base_difficulty()
	current_difficulty = base_difficulty
	print("RocketManager: preset changed, base_difficulty = ", base_difficulty)

func _on_rocket_launched(rocket: Rocket, launcher: RocketLauncher):
	"""Handle rocket launch events"""
	if not is_instance_valid(rocket):
		return
	rockets_fired += 1

	# Connect to rocket signals
	rocket.rocket_near_miss.connect(_on_rocket_near_miss)
	rocket.rocket_exploded.connect(_on_rocket_exploded)

	print("Total rockets fired: ", rockets_fired)

func _on_rocket_near_miss(rocket: Rocket, distance: float):
	"""Handle rocket near miss events"""
	near_misses += 1

	# Award evasion points
	var points = int(100.0 / distance)  # Closer misses = more points
	GameManager.add_score(points)

func _on_rocket_exploded(position: Vector2, radius: float):
	"""Handle rocket explosion events"""
	# Could trigger screen shake or other effects
	pass

func _on_launcher_warning_activated(launcher: RocketLauncher, warning_time: float):
	"""Handle launcher warning activation"""
	# Could trigger UI warnings or audio cues
	emit_signal("rocket_barrage_incoming", 1)

func _on_terrain_feature_created(feature: Node2D, position: Vector2):
	"""Handle terrain features for launcher placement"""
	# Could place launchers near certain terrain features
	pass

# Public interface functions
func set_threat_level(level: float):
	"""Set overall threat level (0.0 to 2.0)"""
	base_difficulty = clamp(level, 0.0, 2.0)

func trigger_emergency_barrage():
	"""Trigger immediate emergency rocket barrage"""
	start_challenge_wave()

func get_active_threat_count() -> int:
	"""Get number of active rocket threats"""
	return active_launchers.size()

func disable_all_launchers():
	"""Disable all launchers (for special events)"""
	for launcher in active_launchers:
		if is_instance_valid(launcher):
			launcher.disable_launcher()

func enable_all_launchers():
	"""Re-enable all launchers"""
	for launcher in active_launchers:
		if is_instance_valid(launcher):
			launcher.enable_launcher()

func get_performance_stats() -> Dictionary:
	"""Get rocket performance statistics"""
	return {
		"rockets_fired": rockets_fired,
		"near_misses": near_misses,
		"active_launchers": active_launchers.size(),
		"current_difficulty": current_difficulty,
		"current_wave": in_challenge_wave
	}