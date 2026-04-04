extends Node

# Game state management for Sugar Glider Adventure
signal game_state_changed(new_state: GameState)
signal score_updated(new_score: int)
signal distance_updated(distance: float)
signal difficulty_changed(new_level: float)
signal difficulty_preset_changed(preset: int)
signal animal_selected(animal_type: int)

enum GameState {
	MENU,
	PLAYING,
	PAUSED,
	GAME_OVER,
	TRANSITIONING
}

enum DifficultyPreset {
	EASY,
	NORMAL,
	HARD,
	EXTREME
}

enum AnimalType {
	SUGAR_GLIDER,
	SPARROW,
	FALCON
}

# Game state variables
var current_state: GameState = GameState.MENU
var is_game_active: bool = false

# Score and progression
var current_score: int = 0
var distance_traveled: float = 0.0
var high_score: int = 0
var games_played: int = 0

# Difficulty scaling
var base_difficulty: float = 1.0
var current_difficulty: float = 1.0
var difficulty_increase_rate: float = 0.1
var difficulty_distance_interval: float = 1000.0  # Every 1000 units

# Difficulty preset
var difficulty_preset: int = DifficultyPreset.NORMAL
var _difficulty_configs: Array[Dictionary] = []

# Animal selection
var selected_animal: int = AnimalType.SUGAR_GLIDER
var _animal_configs: Array[Dictionary] = []

# Game settings
var game_speed_multiplier: float = 1.0
var sound_enabled: bool = true
var music_enabled: bool = true

# Platform detection
var platform: String = ""

func _ready():
	detect_platform()
	_init_difficulty_configs()
	_init_animal_configs()
	load_game_data()
	set_process(true)

	print("GameManager initialized - Platform: ", platform)

func _process(delta):
	if current_state == GameState.PLAYING:
		update_game_progression(delta)

func _init_difficulty_configs():
	"""Initialize the per-preset multiplier configuration table"""
	_difficulty_configs = [
		# EASY
		{
			"base_difficulty": 0.6,
			"scroll_speed_multiplier": 0.75,
			"energy_drain_multiplier": 0.6,
			"rocket_base_difficulty": 0.5,
			"warning_time_multiplier": 1.8,
			"score_multiplier": 0.75
		},
		# NORMAL
		{
			"base_difficulty": 1.0,
			"scroll_speed_multiplier": 1.0,
			"energy_drain_multiplier": 1.0,
			"rocket_base_difficulty": 1.0,
			"warning_time_multiplier": 1.0,
			"score_multiplier": 1.0
		},
		# HARD
		{
			"base_difficulty": 1.4,
			"scroll_speed_multiplier": 1.2,
			"energy_drain_multiplier": 1.3,
			"rocket_base_difficulty": 1.5,
			"warning_time_multiplier": 0.6,
			"score_multiplier": 1.5
		},
		# EXTREME
		{
			"base_difficulty": 2.0,
			"scroll_speed_multiplier": 1.5,
			"energy_drain_multiplier": 1.7,
			"rocket_base_difficulty": 2.0,
			"warning_time_multiplier": 0.3,
			"score_multiplier": 2.5
		}
	]

func _init_animal_configs():
	"""Initialize the per-animal physics profile table"""
	_animal_configs = [
		# SUGAR_GLIDER — balanced speed and agility
		{
			"display_name": "Sugar Glider",
			"description": "Balanced speed and agility",
			"max_glide_speed": 600.0,
			"min_glide_speed": 100.0,
			"input_force": 450.0,
			"air_resistance": 0.98,
			"glide_resistance": 0.995,
			"glide_lift_coefficient": 0.3,
			"max_fall_speed": 800.0,
		},
		# SPARROW — less top speed, more maneuverability
		{
			"display_name": "Sparrow",
			"description": "Swift turns, modest top speed",
			"max_glide_speed": 450.0,
			"min_glide_speed": 80.0,
			"input_force": 580.0,
			"air_resistance": 0.985,
			"glide_resistance": 0.997,
			"glide_lift_coefficient": 0.38,
			"max_fall_speed": 700.0,
		},
		# FALCON — highest top speed, least agility
		{
			"display_name": "Falcon",
			"description": "Blazing speed, heavy handling",
			"max_glide_speed": 780.0,
			"min_glide_speed": 130.0,
			"input_force": 300.0,
			"air_resistance": 0.972,
			"glide_resistance": 0.991,
			"glide_lift_coefficient": 0.22,
			"max_fall_speed": 980.0,
		},
	]

func set_animal(animal_type: int) -> void:
	"""Set the active animal and emit signal"""
	selected_animal = clamp(animal_type, 0, AnimalType.FALCON)
	emit_signal("animal_selected", selected_animal)
	print("Animal selected: ", AnimalType.keys()[selected_animal])

func get_animal_config() -> Dictionary:
	if _animal_configs.is_empty() or selected_animal < 0 or selected_animal >= _animal_configs.size():
		print("Warning: Invalid animal config access, returning default")
		return {
			"display_name": "Sugar Glider",
			"description": "Balanced speed and agility",
			"max_glide_speed": 600.0,
			"min_glide_speed": 100.0,
			"input_force": 450.0,
			"air_resistance": 0.98,
			"glide_resistance": 0.995,
			"glide_lift_coefficient": 0.3,
			"max_fall_speed": 800.0,
		}
	return _animal_configs[selected_animal]

func get_animal_display_name() -> String:
	return get_animal_config().display_name

func set_difficulty_preset(preset: int) -> void:
	"""Set the difficulty preset and apply its base configuration"""
	difficulty_preset = clamp(preset, 0, DifficultyPreset.EXTREME)
	if not _difficulty_configs.is_empty() and difficulty_preset < _difficulty_configs.size():
		base_difficulty = _difficulty_configs[difficulty_preset].base_difficulty
	emit_signal("difficulty_preset_changed", difficulty_preset)
	print("Difficulty preset set to: ", DifficultyPreset.keys()[difficulty_preset])

func _get_difficulty_config_value(key: String, default_value: float = 1.0) -> float:
	"""Safely retrieve a value from the active difficulty config"""
	if _difficulty_configs.is_empty() or difficulty_preset < 0 or difficulty_preset >= _difficulty_configs.size():
		print("Warning: Invalid difficulty config access for '", key, "', returning ", default_value)
		return default_value
	return _difficulty_configs[difficulty_preset].get(key, default_value)

func get_scroll_speed_multiplier() -> float:
	return _get_difficulty_config_value("scroll_speed_multiplier", 1.0)

func get_energy_drain_multiplier() -> float:
	return _get_difficulty_config_value("energy_drain_multiplier", 1.0)

func get_rocket_base_difficulty() -> float:
	return _get_difficulty_config_value("rocket_base_difficulty", 1.0)

func get_warning_time_multiplier() -> float:
	return _get_difficulty_config_value("warning_time_multiplier", 1.0)

func get_score_multiplier() -> float:
	return _get_difficulty_config_value("score_multiplier", 1.0)

func detect_platform() -> void:
	if OS.get_name() == "Windows":
		platform = "windows"
	elif OS.get_name() == "macOS":
		platform = "macos"
	elif OS.get_name() == "Linux":
		platform = "linux"
	else:
		platform = "unknown"

func start_new_game() -> void:
	"""Initialize a new game session using the active difficulty preset"""
	print("Starting new game...")

	current_score = 0
	distance_traveled = 0.0
	if not _difficulty_configs.is_empty() and difficulty_preset < _difficulty_configs.size():
		base_difficulty = _difficulty_configs[difficulty_preset].base_difficulty
	current_difficulty = base_difficulty
	is_game_active = true
	games_played += 1

	change_state(GameState.PLAYING)

	emit_signal("score_updated", current_score)
	emit_signal("distance_updated", distance_traveled)
	emit_signal("difficulty_changed", current_difficulty)

func pause_game() -> void:
	"""Pause the current game"""
	if current_state == GameState.PLAYING:
		change_state(GameState.PAUSED)
		if is_inside_tree():
			get_tree().paused = true
		print("Game paused")

func resume_game() -> void:
	"""Resume from pause"""
	if current_state == GameState.PAUSED:
		change_state(GameState.PLAYING)
		if is_inside_tree():
			get_tree().paused = false
		print("Game resumed")

func end_game() -> void:
	"""End the current game and show results"""
	print("Game ended - Score: ", current_score, " Distance: ", distance_traveled)

	is_game_active = false
	if is_inside_tree():
		get_tree().paused = false

	# Update high score
	if current_score > high_score:
		high_score = current_score
		print("New high score: ", high_score)

	change_state(GameState.GAME_OVER)
	save_game_data()

func restart_game() -> void:
	"""Restart the current game"""
	print("Restarting game...")
	start_new_game()

func return_to_menu() -> void:
	"""Return to the main menu"""
	is_game_active = false
	if is_inside_tree():
		get_tree().paused = false
	current_score = 0
	distance_traveled = 0.0
	current_difficulty = base_difficulty
	change_state(GameState.MENU)
	print("Returned to menu")

func _is_valid_transition(from_state: GameState, to_state: GameState) -> bool:
	"""Check whether a state transition is allowed"""
	match from_state:
		GameState.MENU:
			return to_state in [GameState.PLAYING, GameState.TRANSITIONING]
		GameState.PLAYING:
			return to_state in [GameState.PLAYING, GameState.PAUSED, GameState.GAME_OVER, GameState.MENU]
		GameState.PAUSED:
			return to_state in [GameState.PLAYING, GameState.MENU]
		GameState.GAME_OVER:
			return to_state in [GameState.PLAYING, GameState.MENU, GameState.TRANSITIONING]
		GameState.TRANSITIONING:
			return to_state in [GameState.MENU, GameState.PLAYING]
	return false

func change_state(new_state: GameState) -> void:
	"""Change the game state and emit signal"""
	var old_state = current_state

	if not _is_valid_transition(old_state, new_state):
		print("Warning: Invalid state transition from ", GameState.keys()[old_state], " to ", GameState.keys()[new_state], " — ignoring")
		return

	current_state = new_state

	print("Game state changed: ", GameState.keys()[old_state], " -> ", GameState.keys()[new_state])
	emit_signal("game_state_changed", new_state)

func add_score(points: int) -> void:
	"""Add points scaled by the active difficulty preset's score multiplier"""
	var scaled_points = int(points * get_score_multiplier())
	current_score += scaled_points
	if current_score < 0:
		current_score = 0
	emit_signal("score_updated", current_score)

func update_distance(new_distance: float) -> void:
	"""Update the distance traveled"""
	distance_traveled = new_distance
	emit_signal("distance_updated", distance_traveled)

func update_game_progression(delta: float) -> void:
	"""Update game progression during gameplay — distance-based difficulty scaling"""
	if not is_game_active:
		return

	# Scale difficulty based on distance traveled
	var difficulty_level = floor(distance_traveled / difficulty_distance_interval)
	var new_difficulty = base_difficulty + (difficulty_level * difficulty_increase_rate)

	if new_difficulty != current_difficulty:
		current_difficulty = new_difficulty
		emit_signal("difficulty_changed", current_difficulty)

func get_game_data() -> Dictionary:
	"""Get current game data for saving"""
	return {
		"high_score": high_score,
		"games_played": games_played,
		"sound_enabled": sound_enabled,
		"music_enabled": music_enabled,
		"game_speed_multiplier": game_speed_multiplier,
		"difficulty_preset": difficulty_preset,
		"selected_animal": selected_animal
	}

func save_game_data() -> void:
	"""Save game data to user preferences"""
	var save_data = get_game_data()
	var file = FileAccess.open("user://save_game.dat", FileAccess.WRITE)

	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()
		print("Game data saved")
	else:
		print("Failed to save game data")

func load_game_data() -> void:
	"""Load game data from user preferences"""
	if not FileAccess.file_exists("user://save_game.dat"):
		print("No save data found, using defaults")
		return

	var file = FileAccess.open("user://save_game.dat", FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()

		var json = JSON.new()
		var parse_result = json.parse(json_string)

		if parse_result == OK:
			var save_data = json.data
			high_score = save_data.get("high_score", 0)
			games_played = save_data.get("games_played", 0)
			sound_enabled = save_data.get("sound_enabled", true)
			music_enabled = save_data.get("music_enabled", true)
			game_speed_multiplier = save_data.get("game_speed_multiplier", 1.0)
			difficulty_preset = save_data.get("difficulty_preset", DifficultyPreset.NORMAL)
			selected_animal = save_data.get("selected_animal", AnimalType.SUGAR_GLIDER)

			# Validate and clamp to valid ranges
			high_score = max(0, high_score)
			games_played = max(0, games_played)
			difficulty_preset = clampi(difficulty_preset, 0, DifficultyPreset.EXTREME)
			selected_animal = clampi(selected_animal, 0, AnimalType.FALCON)

			print("Game data loaded - High Score: ", high_score)
		else:
			print("Failed to parse save data")
	else:
		print("Failed to load game data")

# Utility functions for other systems
func is_playing() -> bool:
	return current_state == GameState.PLAYING

func is_paused() -> bool:
	return current_state == GameState.PAUSED

func is_game_over() -> bool:
	return current_state == GameState.GAME_OVER

func get_difficulty_multiplier() -> float:
	return current_difficulty

func get_current_score() -> int:
	return current_score

func get_distance_traveled() -> float:
	return distance_traveled
