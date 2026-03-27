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
var camera_offset: Vector2 = Vector2(300, 0)
var debug_enabled: bool = false

# Difficulty selection overlay (built in code)
var difficulty_overlay: CanvasLayer

func _ready():
	_initialize_visual_environment()
	setup_connections()
	_create_difficulty_menu()

	print("Main scene initialized")

func _input(event):
	"""Handle main scene input"""
	if event.is_action_pressed("pause_game"):
		toggle_pause()
	elif event.is_action_pressed("restart_game"):
		restart_game()
	elif event.is_action_pressed("ui_accept"):
		toggle_debug()

func _process(delta):
	update_camera(delta)
	update_rocket_ui()
	if debug_enabled:
		update_debug_info()

func _initialize_visual_environment():
	"""Add WorldEnvironment with glow for volcanic atmosphere"""
	var world_env = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.01, 0.01)  # Dark volcanic red-black
	env.glow_enabled = true
	env.glow_bloom = 0.2
	env.glow_intensity = 0.6
	env.glow_normalized = true
	world_env.environment = env
	add_child(world_env)

func _create_difficulty_menu():
	"""Build the difficulty selection overlay entirely in code"""
	difficulty_overlay = CanvasLayer.new()
	difficulty_overlay.layer = 10
	add_child(difficulty_overlay)

	# Semi-transparent dark background panel
	var panel = Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.78)
	panel.add_theme_stylebox_override("panel", style)
	difficulty_overlay.add_child(panel)

	# Centered vertical layout
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(440, 340)
	vbox.offset_left = -220
	vbox.offset_top = -170
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "SUGAR GLIDER ADVENTURE"
	title.add_theme_font_size_override("font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate = Color(1.0, 0.65, 0.2)
	vbox.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Select Difficulty"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate = Color(0.75, 0.75, 0.75)
	vbox.add_child(subtitle)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)

	var difficulty_data = [
		{"label": "EASY      [0.75x score]",   "color": Color(0.3, 0.9, 0.3),   "preset": GameManager.DifficultyPreset.EASY},
		{"label": "NORMAL    [1.0x score]",    "color": Color(0.9, 0.9, 0.9),   "preset": GameManager.DifficultyPreset.NORMAL},
		{"label": "HARD      [1.5x score]",    "color": Color(1.0, 0.55, 0.1),  "preset": GameManager.DifficultyPreset.HARD},
		{"label": "EXTREME   [2.5x score]",    "color": Color(1.0, 0.2, 0.2),   "preset": GameManager.DifficultyPreset.EXTREME}
	]

	for data in difficulty_data:
		var btn = Button.new()
		btn.text = data.label
		btn.custom_minimum_size = Vector2(400, 52)
		btn.add_theme_color_override("font_color", data.color)
		btn.add_theme_font_size_override("font_size", 18)
		var preset_value = data.preset
		btn.pressed.connect(func(): _on_difficulty_selected(preset_value))
		vbox.add_child(btn)

func _on_difficulty_selected(preset: int):
	"""Handle difficulty button press — set preset and start game"""
	GameManager.set_difficulty_preset(preset)
	difficulty_overlay.hide()
	initialize_game()

func setup_connections():
	"""Connect signals from game systems"""
	GameManager.game_state_changed.connect(_on_game_state_changed)
	GameManager.score_updated.connect(_on_score_updated)
	GameManager.distance_updated.connect(_on_distance_updated)

	if sugar_glider:
		sugar_glider.energy_changed.connect(_on_energy_changed)
		sugar_glider.collision_occurred.connect(_on_collision_occurred)

	if obstacle_manager:
		obstacle_manager.strategic_hint_available.connect(_on_strategic_hint_available)
		obstacle_manager.obstacle_cluster_detected.connect(_on_obstacle_cluster_detected)

	if rocket_manager:
		rocket_manager.challenge_wave_started.connect(_on_challenge_wave_started)
		rocket_manager.rocket_barrage_incoming.connect(_on_rocket_barrage_incoming)
		rocket_manager.all_clear_period.connect(_on_all_clear_period)

	InputManager.game_action_triggered.connect(_on_game_action_triggered)

func initialize_game():
	"""Initialize the game session"""
	camera_follow_speed = 2.0
	GameManager.start_new_game()

	if camera and sugar_glider:
		camera.position = sugar_glider.global_position + camera_offset

	update_ui_elements()

func update_camera(delta):
	"""Update camera to follow the player with dynamic zoom"""
	if not camera or not sugar_glider:
		return

	var target_position = sugar_glider.global_position + camera_offset
	camera.position = camera.position.lerp(target_position, camera_follow_speed * delta)

	# Dynamic zoom: zoom out slightly at high scroll speed
	var speed_ratio = 0.0
	var scrolling_manager = game_world.get_node_or_null("ScrollingManager") if game_world else null
	if scrolling_manager and scrolling_manager.has_method("get_scroll_speed"):
		speed_ratio = clamp(scrolling_manager.get_scroll_speed() / 500.0, 0.0, 1.0)
	var target_zoom = Vector2.ONE * lerp(1.0, 0.9, speed_ratio)
	camera.zoom = camera.zoom.lerp(target_zoom, 1.5 * delta)

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

		threat_level_bar.value = min(threat_count, 10.0)

		if threat_count > 6:
			threat_level_bar.modulate = Color.RED
		elif threat_count > 3:
			threat_level_bar.modulate = Color.ORANGE
		else:
			threat_level_bar.modulate = Color.GREEN

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

func toggle_pause():
	"""Toggle game pause state"""
	if GameManager.is_playing():
		GameManager.pause_game()
	elif GameManager.is_paused():
		GameManager.resume_game()

func restart_game():
	"""Restart — show difficulty menu so player can choose again"""
	if difficulty_overlay:
		GameManager.return_to_menu()
		difficulty_overlay.show()

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
			pass
		GameManager.GameState.PAUSED:
			pass
		GameManager.GameState.GAME_OVER:
			handle_game_over()

func _on_score_updated(new_score: int):
	if score_label:
		score_label.text = "Score: " + str(new_score)

func _on_distance_updated(new_distance: float):
	if distance_label:
		distance_label.text = "Distance: " + str(int(new_distance)) + "m"

func _on_energy_changed(new_energy: float, max_energy: float):
	if energy_bar:
		energy_bar.max_value = max_energy
		energy_bar.value = new_energy

		var energy_percentage = new_energy / max_energy
		if energy_percentage < 0.2:
			energy_bar.modulate = Color.RED
		elif energy_percentage < 0.5:
			energy_bar.modulate = Color.YELLOW
		else:
			energy_bar.modulate = Color.GREEN

func _on_collision_occurred(collision_body: Node):
	print("Main: Collision with ", collision_body.name)

	if collision_body.get_collision_layer() == 2:
		add_screen_shake(0.3, 5.0)

func _on_game_action_triggered(action: String):
	match action:
		"pause":
			toggle_pause()
		"restart":
			restart_game()

func _on_strategic_hint_available(hint_text: String, hint_type: String):
	if hint_label:
		hint_label.text = hint_text
		hint_label.modulate = Color.WHITE

		var tween = create_tween()
		tween.tween_delay(3.0)
		tween.tween_property(hint_label, "modulate", Color.TRANSPARENT, 1.0)

func _on_obstacle_cluster_detected(cluster_center: Vector2, difficulty: float):
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

		var tween = create_tween()
		tween.tween_delay(2.0)
		tween.tween_property(obstacle_info_label, "modulate", Color.TRANSPARENT, 1.0)

func _on_challenge_wave_started(wave_name: String, difficulty: float):
	if hint_label:
		var wave_text = "INCOMING: " + wave_name.replace("_", " ").to_upper()
		hint_label.text = wave_text
		hint_label.modulate = Color.ORANGE_RED

		var tween = create_tween()
		for i in 3:
			tween.tween_property(hint_label, "modulate", Color.TRANSPARENT, 0.2)
			tween.tween_property(hint_label, "modulate", Color.ORANGE_RED, 0.2)

		tween.tween_delay(3.0)
		tween.tween_property(hint_label, "modulate", Color.TRANSPARENT, 1.0)

	add_screen_shake(1.0, 8.0)
	AudioManager.play_sfx("rocket_warning_intense", 1.0)

func _on_rocket_barrage_incoming(launcher_count: int):
	if obstacle_info_label:
		obstacle_info_label.text = "ROCKET BARRAGE INCOMING!"
		obstacle_info_label.modulate = Color.RED

		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(obstacle_info_label, "scale", Vector2(1.2, 1.2), 0.3)
		tween.tween_property(obstacle_info_label, "scale", Vector2(1.0, 1.0), 0.3)

		get_tree().create_timer(4.0).timeout.connect(func():
			tween.kill()
			obstacle_info_label.modulate = Color.TRANSPARENT
			obstacle_info_label.scale = Vector2.ONE
		)

func _on_all_clear_period(duration: float):
	if hint_label:
		hint_label.text = "ALL CLEAR - SAFE PASSAGE"
		hint_label.modulate = Color.GREEN

		var tween = create_tween()
		tween.tween_delay(duration)
		tween.tween_property(hint_label, "modulate", Color.TRANSPARENT, 1.0)

func handle_game_over():
	"""Handle game over — freeze camera then show difficulty menu"""
	camera_follow_speed = 0.0

	print("Game Over! Final Score: ", GameManager.get_current_score())

	# Show difficulty menu after brief pause so player sees the moment
	get_tree().create_timer(1.5).timeout.connect(func():
		if difficulty_overlay:
			difficulty_overlay.show()
	)

func add_screen_shake(duration: float, strength: float):
	"""Add screen shake effect on collision"""
	if not camera:
		return

	var tween = create_tween()
	var original_position = camera.position

	for i in range(int(duration * 60)):
		var shake_offset = Vector2(
			randf_range(-strength, strength),
			randf_range(-strength, strength)
		)

		tween.tween_property(camera, "position", original_position + shake_offset, 0.016)

	tween.tween_property(camera, "position", original_position, 0.1)
