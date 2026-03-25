extends Node

# Game state management for Sugar Glider Adventure
signal game_state_changed(new_state: GameState)
signal score_updated(new_score: int)
signal distance_updated(distance: float)
signal difficulty_changed(new_level: float)

enum GameState {
	MENU,
	PLAYING,
	PAUSED,
	GAME_OVER,
	TRANSITIONING
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
var difficulty_distance_interval: float = 1000.0 # Every 1000 units

# Game settings
var game_speed_multiplier: float = 1.0
var sound_enabled: bool = true
var music_enabled: bool = true

# Platform detection
var platform: String = ""

func _ready():
	detect_platform()
	load_game_data()
	set_process(true)

	print("GameManager initialized - Platform: ", platform)

func _process(delta):
	if current_state == GameState.PLAYING:
		update_game_progression(delta)

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
	"""Initialize a new game session"""
	print("Starting new game...")

	current_score = 0
	distance_traveled = 0.0
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
		get_tree().paused = true
		print("Game paused")

func resume_game() -> void:
	"""Resume from pause"""
	if current_state == GameState.PAUSED:
		change_state(GameState.PLAYING)
		get_tree().paused = false
		print("Game resumed")

func end_game() -> void:
	"""End the current game and show results"""
	print("Game ended - Score: ", current_score, " Distance: ", distance_traveled)

	is_game_active = false
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
	get_tree().paused = false
	change_state(GameState.MENU)
	print("Returned to menu")

func change_state(new_state: GameState) -> void:
	"""Change the game state and emit signal"""
	var old_state = current_state
	current_state = new_state

	print("Game state changed: ", GameState.keys()[old_state], " -> ", GameState.keys()[new_state])
	emit_signal("game_state_changed", new_state)

func add_score(points: int) -> void:
	"""Add points to the current score"""
	current_score += points
	emit_signal("score_updated", current_score)

func update_distance(new_distance: float) -> void:
	"""Update the distance traveled"""
	distance_traveled = new_distance
	emit_signal("distance_updated", distance_traveled)

	# Check for difficulty scaling
	var difficulty_level = floor(distance_traveled / difficulty_distance_interval)
	var new_difficulty = base_difficulty + (difficulty_level * difficulty_increase_rate)

	if new_difficulty != current_difficulty:
		current_difficulty = new_difficulty
		emit_signal("difficulty_changed", current_difficulty)

func update_game_progression(delta: float) -> void:
	"""Update game progression during gameplay"""
	if not is_game_active:
		return

	# This will be called by the scrolling system to update distance
	# The actual distance calculation happens in the scrolling manager

func get_game_data() -> Dictionary:
	"""Get current game data for saving"""
	return {
		"high_score": high_score,
		"games_played": games_played,
		"sound_enabled": sound_enabled,
		"music_enabled": music_enabled,
		"game_speed_multiplier": game_speed_multiplier
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