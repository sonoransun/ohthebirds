extends Node

# Main game controller script
@onready var game_world: Node2D = $GameWorld
@onready var sugar_glider: SugarGlider = $GameWorld/PlayArea/SugarGlider
@onready var camera: Camera2D = $GameWorld/Camera2D

# System components
@onready var obstacle_manager: ObstacleManager = $GameWorld/ScrollingManager/ObstacleManager
@onready var rocket_manager: RocketManager = $GameWorld/ScrollingManager/RocketManager

# UI elements
@onready var energy_bar: ProgressBar = $UI/HUD/EnergyBar
@onready var score_label: Label = $UI/HUD/ScoreLabel
@onready var distance_label: Label = $UI/HUD/DistanceLabel

# Navigation hint UI
@onready var hint_label: Label = $UI/NavigationHints/HintLabel
@onready var obstacle_info_label: Label = $UI/NavigationHints/ObstacleInfo

# Rocket warning UI
@onready var rocket_warning_label: Label = $UI/RocketWarning/WarningLabel
@onready var threat_level_bar: ProgressBar = $UI/RocketWarning/ThreatLevel

# Debug UI
@onready var debug_info: VBoxContainer = $UI/DebugInfo
@onready var input_label: Label = $UI/DebugInfo/InputLabel
@onready var velocity_label: Label = $UI/DebugInfo/VelocityLabel
@onready var state_label: Label = $UI/DebugInfo/StateLabel

# Game state
var camera_follow_speed: float = 2.0
var camera_offset: Vector2 = Vector2(300, 0)  # Keep player left of center
var debug_enabled: bool = false

func _ready():
	setup_connections()
	initialize_game()

	print("Main scene initialized")

func _input(event):
	"""Handle main scene input"""
	if event.is_action_pressed("pause_game"):
		toggle_pause()
	elif event.is_action_pressed("restart_game"):
		restart_game()
	elif event.is_action_pressed("ui_accept"):  # F key for debug
		toggle_debug()

func _process(delta):
	update_camera(delta)
	update_rocket_ui()
	if debug_enabled:
		update_debug_info()

func setup_connections():
	"""Connect signals from game systems"""
	# Connect to GameManager signals
	GameManager.game_state_changed.connect(_on_game_state_changed)
	GameManager.score_updated.connect(_on_score_updated)
	GameManager.distance_updated.connect(_on_distance_updated)

	# Connect to SugarGlider signals
	if sugar_glider:
		sugar_glider.energy_changed.connect(_on_energy_changed)
		sugar_glider.collision_occurred.connect(_on_collision_occurred)

	# Connect to ObstacleManager signals
	if obstacle_manager:
		obstacle_manager.strategic_hint_available.connect(_on_strategic_hint_available)
		obstacle_manager.obstacle_cluster_detected.connect(_on_obstacle_cluster_detected)

	# Connect to RocketManager signals
	if rocket_manager:
		rocket_manager.challenge_wave_started.connect(_on_challenge_wave_started)
		rocket_manager.rocket_barrage_incoming.connect(_on_rocket_barrage_incoming)
		rocket_manager.all_clear_period.connect(_on_all_clear_period)

	# Connect to InputManager signals for game actions
	InputManager.game_action_triggered.connect(_on_game_action_triggered)

func initialize_game():
	"""Initialize the game session"""
	# Start the game
	GameManager.start_new_game()

	# Set initial camera position
	if camera and sugar_glider:
		camera.position = sugar_glider.global_position + camera_offset

	# Initialize UI
	update_ui_elements()

func update_camera(delta):
	"""Update camera to follow the player"""
	if not camera or not sugar_glider:
		return

	# Calculate target position
	var target_position = sugar_glider.global_position + camera_offset

	# Smooth camera movement
	camera.position = camera.position.lerp(target_position, camera_follow_speed * delta)

func update_ui_elements():
	"""Update all UI elements with current game state"""
	if score_label:
		score_label.text = "Score: " + str(GameManager.get_current_score())

	if distance_label:
		distance_label.text = "Distance: " + str(int(GameManager.get_distance_traveled())) + "m"

func update_rocket_ui():
	"""Update rocket-related UI elements"""
	if rocket_manager and threat_level_bar:
		var threat_count = rocket_manager.get_active_threat_count()
		var performance_stats = rocket_manager.get_performance_stats()

		# Update threat level bar
		threat_level_bar.value = min(threat_count, 10.0)

		# Color code the threat level
		if threat_count > 6:
			threat_level_bar.modulate = Color.RED
		elif threat_count > 3:
			threat_level_bar.modulate = Color.ORANGE
		else:
			threat_level_bar.modulate = Color.GREEN

		# Update warning text for high threats
		if rocket_warning_label:
			if threat_count > 5:
				rocket_warning_label.text = "EXTREME THREAT"
				rocket_warning_label.modulate = Color.RED
			elif threat_count > 2:
				rocket_warning_label.text = "High Threat Level"
				rocket_warning_label.modulate = Color.ORANGE
			else:
				rocket_warning_label.text = ""

func update_debug_info():
	"""Update debug information display"""
	if not sugar_glider:
		return

	var debug_data = sugar_glider.get_debug_info()
	var input_data = InputManager.get_debug_info()

	if input_label:
		input_label.text = "Input: " + str(input_data.input_direction) + " (Active: " + str(input_data.is_active) + ")"

	if velocity_label:
		velocity_label.text = "Velocity: " + str(debug_data.velocity).substr(0, 20)

	if state_label:
		state_label.text = "State: " + debug_data.animation_state + " (Energy: " + str(int(debug_data.energy)) + ")"

	# Add rocket debug info
	if rocket_manager:
		var rocket_stats = rocket_manager.get_performance_stats()
		print("Rockets fired: ", rocket_stats.rockets_fired, " Near misses: ", rocket_stats.near_misses)

func toggle_pause():
	"""Toggle game pause state"""
	if GameManager.is_playing():
		GameManager.pause_game()
	elif GameManager.is_paused():
		GameManager.resume_game()

func restart_game():
	"""Restart the current game"""
	GameManager.restart_game()

func toggle_debug():
	"""Toggle debug information display"""
	debug_enabled = not debug_enabled
	if debug_info:
		debug_info.visible = debug_enabled

	print("Debug mode: ", debug_enabled)

# Signal handlers
func _on_game_state_changed(new_state):
	"""Handle game state changes"""
	print("Main: Game state changed to ", GameManager.GameState.keys()[new_state])

	match new_state:
		GameManager.GameState.PLAYING:
			# Resume normal gameplay
			pass
		GameManager.GameState.PAUSED:
			# Show pause overlay if needed
			pass
		GameManager.GameState.GAME_OVER:
			# Handle game over state
			handle_game_over()

func _on_score_updated(new_score: int):
	"""Handle score updates"""
	if score_label:
		score_label.text = "Score: " + str(new_score)

func _on_distance_updated(new_distance: float):
	"""Handle distance updates"""
	if distance_label:
		distance_label.text = "Distance: " + str(int(new_distance)) + "m"

func _on_energy_changed(new_energy: float, max_energy: float):
	"""Handle energy changes"""
	if energy_bar:
		energy_bar.max_value = max_energy
		energy_bar.value = new_energy

		# Change color based on energy level
		var energy_percentage = new_energy / max_energy
		if energy_percentage < 0.2:
			energy_bar.modulate = Color.RED
		elif energy_percentage < 0.5:
			energy_bar.modulate = Color.YELLOW
		else:
			energy_bar.modulate = Color.GREEN

func _on_collision_occurred(collision_body: Node):
	"""Handle collision events"""
	print("Main: Collision with ", collision_body.name)

	# Add screen shake or other effects here
	if collision_body.get_collision_layer() == 2:  # Obstacles
		add_screen_shake(0.3, 5.0)

func _on_game_action_triggered(action: String):
	"""Handle game actions from InputManager"""
	match action:
		"pause":
			toggle_pause()
		"restart":
			restart_game()

func _on_strategic_hint_available(hint_text: String, hint_type: String):
	"""Handle strategic navigation hints"""
	if hint_label:
		hint_label.text = hint_text
		hint_label.modulate = Color.WHITE

		# Fade out hint after a few seconds
		var tween = create_tween()
		tween.tween_delay(3.0)
		tween.tween_property(hint_label, "modulate", Color.TRANSPARENT, 1.0)

	print("Navigation hint: ", hint_text)

func _on_obstacle_cluster_detected(cluster_center: Vector2, difficulty: float):
	"""Handle obstacle cluster detection"""
	if obstacle_info_label:
		var difficulty_text = ""
		if difficulty > 1.5:
			difficulty_text = "High difficulty cluster ahead!"
		elif difficulty > 1.0:
			difficulty_text = "Challenging obstacle group detected"
		else:
			difficulty_text = "Moderate obstacle cluster"

		obstacle_info_label.text = difficulty_text
		obstacle_info_label.modulate = Color.YELLOW if difficulty > 1.0 else Color.WHITE

		# Fade out after showing
		var tween = create_tween()
		tween.tween_delay(2.0)
		tween.tween_property(obstacle_info_label, "modulate", Color.TRANSPARENT, 1.0)

func _on_challenge_wave_started(wave_name: String, difficulty: float):
	"""Handle rocket challenge wave events"""
	if hint_label:
		var wave_text = "INCOMING: " + wave_name.replace("_", " ").to_upper()
		hint_label.text = wave_text
		hint_label.modulate = Color.ORANGE_RED

		# Flash effect for dramatic warnings
		var tween = create_tween()
		for i in 3:
			tween.tween_property(hint_label, "modulate", Color.TRANSPARENT, 0.2)
			tween.tween_property(hint_label, "modulate", Color.ORANGE_RED, 0.2)

		tween.tween_delay(3.0)
		tween.tween_property(hint_label, "modulate", Color.TRANSPARENT, 1.0)

	# Add intense screen effects
	add_screen_shake(1.0, 8.0)

	# Play dramatic warning sound
	AudioManager.play_sfx("rocket_warning_intense", 1.0)

	print("Challenge wave started: ", wave_name, " difficulty: ", difficulty)

func _on_rocket_barrage_incoming(launcher_count: int):
	"""Handle rocket barrage warnings"""
	if obstacle_info_label:
		obstacle_info_label.text = "ROCKET BARRAGE INCOMING!"
		obstacle_info_label.modulate = Color.RED

		# Urgent pulsing effect
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(obstacle_info_label, "scale", Vector2(1.2, 1.2), 0.3)
		tween.tween_property(obstacle_info_label, "scale", Vector2(1.0, 1.0), 0.3)

		# Stop after 4 seconds
		get_tree().create_timer(4.0).timeout.connect(func():
			tween.kill()
			obstacle_info_label.modulate = Color.TRANSPARENT
			obstacle_info_label.scale = Vector2.ONE
		)

func _on_all_clear_period(duration: float):
	"""Handle all-clear periods after intense waves"""
	if hint_label:
		hint_label.text = "ALL CLEAR - SAFE PASSAGE"
		hint_label.modulate = Color.GREEN

		var tween = create_tween()
		tween.tween_delay(duration)
		tween.tween_property(hint_label, "modulate", Color.TRANSPARENT, 1.0)

	print("All clear period: ", duration, " seconds")

func handle_game_over():
	"""Handle game over state"""
	print("Main: Handling game over")

	# Stop camera following
	camera_follow_speed = 0.0

	# Show game over UI (would create a proper game over screen in full implementation)
	print("Game Over! Final Score: ", GameManager.get_current_score())
	print("Press R to restart")

func add_screen_shake(duration: float, strength: float):
	"""Add screen shake effect on collision"""
	if not camera:
		return

	var tween = create_tween()
	var original_position = camera.position

	for i in range(int(duration * 60)):  # 60 FPS worth of shakes
		var shake_offset = Vector2(
			randf_range(-strength, strength),
			randf_range(-strength, strength)
		)

		tween.tween_property(camera, "position", original_position + shake_offset, 0.016)

	tween.tween_property(camera, "position", original_position, 0.1)