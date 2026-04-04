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

# Selection overlays (built in code)
var animal_overlay: CanvasLayer
var difficulty_overlay: CanvasLayer

# Intro screen
var intro_overlay: CanvasLayer
var intro_active: bool = true
var intro_pulse_tween: Tween

func _ready():
	_initialize_visual_environment()
	setup_connections()
	_create_intro_screen()
	_create_animal_menu()
	_create_difficulty_menu()
	# Hide selection menus until intro is dismissed
	animal_overlay.hide()
	difficulty_overlay.hide()

	print("Main scene initialized")

func _input(event):
	"""Handle main scene input"""
	if intro_active:
		if (event is InputEventKey and event.pressed and not event.echo) \
			or (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed) \
			or (event is InputEventJoypadButton and event.pressed):
			_dismiss_intro()
		return

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

func _create_animal_menu():
	"""Build the animal selection overlay entirely in code"""
	animal_overlay = CanvasLayer.new()
	animal_overlay.layer = 11
	add_child(animal_overlay)

	var panel = Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.78)
	panel.add_theme_stylebox_override("panel", style)
	animal_overlay.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(440, 320)
	vbox.offset_left = -220
	vbox.offset_top = -160
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "SUGAR GLIDER ADVENTURE"
	title.add_theme_font_size_override("font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate = Color(1.0, 0.65, 0.2)
	vbox.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Choose Your Animal"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate = Color(0.75, 0.75, 0.75)
	vbox.add_child(subtitle)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)

	var animal_data = [
		{"label": "SUGAR GLIDER  [balanced]",      "color": Color(0.6, 0.9, 1.0),  "type": GameManager.AnimalType.SUGAR_GLIDER},
		{"label": "SPARROW       [agile]",          "color": Color(0.4, 0.9, 0.4),  "type": GameManager.AnimalType.SPARROW},
		{"label": "FALCON        [speed]",          "color": Color(1.0, 0.55, 0.1), "type": GameManager.AnimalType.FALCON},
	]

	for data in animal_data:
		var btn = Button.new()
		btn.text = data.label
		btn.custom_minimum_size = Vector2(400, 52)
		btn.add_theme_color_override("font_color", data.color)
		btn.add_theme_font_size_override("font_size", 18)
		var animal_type = data.type
		btn.pressed.connect(func(): _on_animal_selected(animal_type))
		vbox.add_child(btn)

func _on_animal_selected(animal_type: int):
	"""Handle animal button press — set animal and show difficulty menu"""
	GameManager.set_animal(animal_type)
	animal_overlay.hide()
	difficulty_overlay.show()

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

func _exit_tree():
	if GameManager.game_state_changed.is_connected(_on_game_state_changed):
		GameManager.game_state_changed.disconnect(_on_game_state_changed)
	if GameManager.score_updated.is_connected(_on_score_updated):
		GameManager.score_updated.disconnect(_on_score_updated)
	if GameManager.distance_updated.is_connected(_on_distance_updated):
		GameManager.distance_updated.disconnect(_on_distance_updated)
	if InputManager.game_action_triggered.is_connected(_on_game_action_triggered):
		InputManager.game_action_triggered.disconnect(_on_game_action_triggered)

func initialize_game():
	"""Initialize the game session"""
	camera_follow_speed = 2.0
	GameManager.start_new_game()

	if sugar_glider:
		sugar_glider.apply_animal_profile()

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
	"""Restart — show animal menu so player can choose animal and difficulty again"""
	if animal_overlay:
		GameManager.return_to_menu()
		animal_overlay.show()

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
	if not energy_bar:
		return
	energy_bar.max_value = max_energy
	energy_bar.value = new_energy

	var energy_percentage = new_energy / max_energy if max_energy > 0.0 else 0.0
	if energy_percentage < 0.2:
		energy_bar.modulate = Color.RED
	elif energy_percentage < 0.5:
		var t = (energy_percentage - 0.2) / 0.3
		energy_bar.modulate = Color.RED.lerp(Color.YELLOW, t)
	else:
		var t = (energy_percentage - 0.5) / 0.5
		energy_bar.modulate = Color.YELLOW.lerp(Color.GREEN, t)

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
	if not obstacle_info_label:
		return
	obstacle_info_label.text = "ROCKET BARRAGE INCOMING!"
	obstacle_info_label.modulate = Color.RED

	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(obstacle_info_label, "scale", Vector2(1.2, 1.2), 0.3)
	tween.tween_property(obstacle_info_label, "scale", Vector2(1.0, 1.0), 0.3)

	get_tree().create_timer(4.0).timeout.connect(func():
		if tween and tween.is_valid():
			tween.kill()
		if is_instance_valid(obstacle_info_label):
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
	get_tree().create_timer(1.5).timeout.connect(func():
		if is_instance_valid(animal_overlay):
			animal_overlay.show()
	)

func add_screen_shake(duration: float, strength: float):
	"""Add screen shake effect on collision"""
	if not camera:
		return

	var shake_tween = create_tween()
	var elapsed = 0.0
	var step = 0.016
	var steps = int(duration / step)
	for i in steps:
		var t = float(i) / steps  # 0→1 progress
		var diminish = (1.0 - t) * strength
		shake_tween.tween_callback(func():
			camera.offset = Vector2(
				randf_range(-diminish, diminish),
				randf_range(-diminish, diminish)
			)
		)
		shake_tween.tween_interval(step)
	shake_tween.tween_callback(func(): camera.offset = Vector2.ZERO)

# ── Intro screen ──────────────────────────────────────────────────────────

func _create_intro_screen():
	"""Build the intro/title screen overlay"""
	intro_overlay = CanvasLayer.new()
	intro_overlay.layer = 12
	add_child(intro_overlay)

	# Full-screen dark volcanic panel
	var panel = Panel.new()
	panel.name = "IntroPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.01, 0.01, 0.95)
	panel.add_theme_stylebox_override("panel", style)
	intro_overlay.add_child(panel)

	# Centered vertical layout
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(1100, 850)
	vbox.offset_left = -550
	vbox.offset_top = -425
	vbox.add_theme_constant_override("separation", 10)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	# Title
	var title = Label.new()
	title.name = "IntroTitle"
	title.text = "SUGAR GLIDER ADVENTURE"
	title.add_theme_font_size_override("font_size", 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate = Color(1.0, 0.65, 0.2)
	vbox.add_child(title)

	# Subtitle
	var subtitle = Label.new()
	subtitle.text = "A Volcanic Flying Adventure"
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate = Color(0.7, 0.7, 0.7)
	vbox.add_child(subtitle)

	# Spacer
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer1)

	# Scene banner — terrain with glider in flight
	var scene_area = Control.new()
	scene_area.custom_minimum_size = Vector2(1100, 240)
	scene_area.clip_contents = true
	vbox.add_child(scene_area)
	_create_intro_scene(scene_area)

	# Spacer
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 14)
	vbox.add_child(spacer2)

	# "Choose Your Creature" label
	var creature_header = Label.new()
	creature_header.text = "Choose Your Creature"
	creature_header.add_theme_font_size_override("font_size", 22)
	creature_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	creature_header.modulate = Color(0.85, 0.85, 0.85)
	vbox.add_child(creature_header)

	# Creature showcase — 3 cards side by side
	var creature_hbox = HBoxContainer.new()
	creature_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	creature_hbox.add_theme_constant_override("separation", 50)
	vbox.add_child(creature_hbox)

	var creatures = [
		{"name": "Sugar Glider", "desc": "Balanced speed and agility", "color": Color(0.6, 0.9, 1.0), "type": "glider"},
		{"name": "Sparrow", "desc": "Swift turns, modest top speed", "color": Color(0.4, 0.9, 0.4), "type": "sparrow"},
		{"name": "Falcon", "desc": "Blazing speed, heavy handling", "color": Color(1.0, 0.55, 0.1), "type": "falcon"},
	]
	var creature_cards = []
	for data in creatures:
		var card = _create_creature_card(data)
		creature_hbox.add_child(card)
		creature_cards.append(card)

	# Spacer
	var spacer3 = Control.new()
	spacer3.custom_minimum_size = Vector2(0, 14)
	vbox.add_child(spacer3)

	# Control hints
	var controls = Label.new()
	controls.name = "ControlHints"
	controls.text = "W / \u2191 / SPACE = Fly Up      S / \u2193 = Dive      A / \u2190 = Slow      D / \u2192 = Speed Up"
	controls.add_theme_font_size_override("font_size", 16)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.modulate = Color(0.65, 0.65, 0.65)
	vbox.add_child(controls)

	# Spacer
	var spacer4 = Control.new()
	spacer4.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(spacer4)

	# Press any key prompt
	var prompt = Label.new()
	prompt.name = "PressAnyKey"
	prompt.text = "\u2014 Press Any Key to Begin \u2014"
	prompt.add_theme_font_size_override("font_size", 22)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.modulate = Color(0.6, 0.9, 1.0)
	vbox.add_child(prompt)

	# Entrance animations
	_animate_intro_entrance(title, subtitle, scene_area, creature_cards, controls, prompt)

func _create_intro_scene(container: Control):
	"""Build a procedural terrain scene with a glider flying over volcanoes"""
	var scene_root = Node2D.new()
	scene_root.position = Vector2(0, 0)
	container.add_child(scene_root)

	# Sky gradient background
	var sky = ColorRect.new()
	sky.color = Color(0.06, 0.02, 0.02, 1.0)
	sky.size = Vector2(1100, 240)
	container.add_child(sky)
	container.move_child(sky, 0)

	# Lava glow at horizon
	var glow = ColorRect.new()
	glow.color = Color(1.0, 0.25, 0.0, 0.15)
	glow.position = Vector2(0, 180)
	glow.size = Vector2(1100, 60)
	container.add_child(glow)

	# Far mountain ridge (dark)
	var far_mountains = Polygon2D.new()
	far_mountains.polygon = PackedVector2Array([
		Vector2(0, 240), Vector2(0, 170), Vector2(60, 140), Vector2(120, 160),
		Vector2(180, 120), Vector2(250, 150), Vector2(320, 110), Vector2(400, 145),
		Vector2(480, 100), Vector2(550, 135), Vector2(620, 115), Vector2(700, 140),
		Vector2(780, 105), Vector2(850, 130), Vector2(920, 95), Vector2(980, 125),
		Vector2(1040, 110), Vector2(1100, 140), Vector2(1100, 240),
	])
	far_mountains.color = Color(0.12, 0.04, 0.04)
	container.add_child(far_mountains)

	# Mid volcanoes (slightly brighter)
	var mid_volcanoes = Polygon2D.new()
	mid_volcanoes.polygon = PackedVector2Array([
		Vector2(0, 240), Vector2(0, 200),
		Vector2(80, 185), Vector2(150, 120), Vector2(220, 185),  # volcano 1
		Vector2(320, 195), Vector2(420, 100), Vector2(480, 140), Vector2(520, 190),  # volcano 2
		Vector2(620, 200), Vector2(720, 85), Vector2(820, 195),  # volcano 3
		Vector2(900, 175), Vector2(960, 130), Vector2(1020, 175),  # small peak
		Vector2(1100, 195), Vector2(1100, 240),
	])
	mid_volcanoes.color = Color(0.2, 0.08, 0.04)
	container.add_child(mid_volcanoes)

	# Foreground spires
	var fg_spires = Polygon2D.new()
	fg_spires.polygon = PackedVector2Array([
		Vector2(0, 240), Vector2(0, 210),
		Vector2(40, 195), Vector2(70, 165), Vector2(100, 200),
		Vector2(250, 215), Vector2(280, 180), Vector2(310, 215),
		Vector2(500, 220), Vector2(530, 190), Vector2(545, 155), Vector2(560, 190), Vector2(590, 220),
		Vector2(780, 210), Vector2(810, 170), Vector2(840, 210),
		Vector2(1000, 215), Vector2(1030, 185), Vector2(1060, 215),
		Vector2(1100, 210), Vector2(1100, 240),
	])
	fg_spires.color = Color(0.28, 0.12, 0.06)
	container.add_child(fg_spires)

	# Lava spots on volcano peaks
	var lava1 = Polygon2D.new()
	lava1.polygon = PackedVector2Array([
		Vector2(140, 125), Vector2(150, 120), Vector2(160, 125), Vector2(150, 130),
	])
	lava1.color = Color(1.0, 0.4, 0.0, 0.7)
	container.add_child(lava1)

	var lava2 = Polygon2D.new()
	lava2.polygon = PackedVector2Array([
		Vector2(410, 105), Vector2(420, 100), Vector2(430, 105), Vector2(420, 112),
	])
	lava2.color = Color(1.0, 0.35, 0.0, 0.8)
	container.add_child(lava2)

	var lava3 = Polygon2D.new()
	lava3.polygon = PackedVector2Array([
		Vector2(710, 90), Vector2(720, 85), Vector2(730, 90), Vector2(720, 97),
	])
	lava3.color = Color(1.0, 0.45, 0.0, 0.7)
	container.add_child(lava3)

	# Glider in flight
	var glider_node = Node2D.new()
	glider_node.position = Vector2(600, 80)
	glider_node.rotation_degrees = -8.0
	container.add_child(glider_node)

	var glider = _create_glider_silhouette()
	glider.scale = Vector2(0.8, 0.8)
	glider_node.add_child(glider)

	# Glider glow
	var glider_glow = Polygon2D.new()
	glider_glow.polygon = _make_circle_polygon(20.0, 12)
	glider_glow.color = Color(0.6, 0.9, 1.0, 0.15)
	glider_node.add_child(glider_glow)

func _create_creature_card(data: Dictionary) -> VBoxContainer:
	"""Build a single creature showcase card"""
	var card = VBoxContainer.new()
	card.custom_minimum_size = Vector2(300, 200)
	card.add_theme_constant_override("separation", 6)
	card.alignment = BoxContainer.ALIGNMENT_CENTER

	# Silhouette area
	var sil_area = Control.new()
	sil_area.custom_minimum_size = Vector2(300, 110)
	card.add_child(sil_area)

	var sil_node = Node2D.new()
	sil_node.position = Vector2(150, 55)
	sil_area.add_child(sil_node)

	var silhouette: Polygon2D
	match data.type:
		"glider":
			silhouette = _create_glider_silhouette()
		"sparrow":
			silhouette = _create_sparrow_silhouette()
		"falcon":
			silhouette = _create_falcon_silhouette()

	sil_node.add_child(silhouette)

	# Creature name
	var name_label = Label.new()
	name_label.text = data.name
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.modulate = data.color
	card.add_child(name_label)

	# Description
	var desc_label = Label.new()
	desc_label.text = data.desc
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.modulate = Color(0.6, 0.6, 0.6)
	card.add_child(desc_label)

	return card

func _create_glider_silhouette() -> Polygon2D:
	"""Procedural sugar glider shape — body with gliding membrane wings"""
	var poly = Polygon2D.new()
	# Body + membrane shape, centered at origin, ~120x60
	poly.polygon = PackedVector2Array([
		# Right wing tip
		Vector2(60, -8),
		# Right wing trailing edge
		Vector2(45, 12),
		# Body right
		Vector2(30, 14),
		# Tail
		Vector2(-55, 18), Vector2(-60, 12), Vector2(-50, 10),
		# Body bottom
		Vector2(-30, 10),
		# Left wing trailing edge
		Vector2(-45, 12),
		# Left wing tip
		Vector2(-60, -8),
		# Left wing leading edge
		Vector2(-40, -14),
		# Body left top
		Vector2(-20, -12),
		# Head
		Vector2(15, -16), Vector2(30, -18), Vector2(38, -14),
		Vector2(42, -8),
		# Right wing leading edge
		Vector2(50, -12),
	])
	poly.color = Color(0.6, 0.9, 1.0, 0.85)
	# Eye
	var eye = Polygon2D.new()
	eye.polygon = _make_circle_polygon(3.0, 8)
	eye.position = Vector2(34, -12)
	eye.color = Color(0.15, 0.15, 0.15)
	poly.add_child(eye)
	return poly

func _create_sparrow_silhouette() -> Polygon2D:
	"""Procedural sparrow shape — compact body with rounded wings"""
	var poly = Polygon2D.new()
	poly.polygon = PackedVector2Array([
		# Beak
		Vector2(45, -2), Vector2(50, 0), Vector2(45, 2),
		# Head top
		Vector2(30, -12), Vector2(20, -16),
		# Left wing up
		Vector2(-5, -22), Vector2(-25, -30), Vector2(-35, -26),
		# Left wing back
		Vector2(-30, -14),
		# Back
		Vector2(-35, -4),
		# Tail fork
		Vector2(-55, -8), Vector2(-50, 0), Vector2(-55, 8),
		# Body bottom
		Vector2(-35, 4),
		# Right wing back
		Vector2(-30, 14),
		# Right wing down
		Vector2(-35, 26), Vector2(-25, 30), Vector2(-5, 22),
		# Belly
		Vector2(20, 16), Vector2(30, 12),
		# Chin
		Vector2(40, 4),
	])
	poly.color = Color(0.4, 0.9, 0.4, 0.85)
	# Eye
	var eye = Polygon2D.new()
	eye.polygon = _make_circle_polygon(3.0, 8)
	eye.position = Vector2(32, -6)
	eye.color = Color(0.15, 0.15, 0.15)
	poly.add_child(eye)
	return poly

func _create_falcon_silhouette() -> Polygon2D:
	"""Procedural falcon shape — streamlined with swept-back angular wings"""
	var poly = Polygon2D.new()
	poly.polygon = PackedVector2Array([
		# Hooked beak
		Vector2(55, -2), Vector2(58, 0), Vector2(56, 3), Vector2(52, 2),
		# Head
		Vector2(38, -10), Vector2(25, -14),
		# Left wing leading edge
		Vector2(10, -18), Vector2(-20, -32), Vector2(-45, -38),
		# Left wing tip (swept back)
		Vector2(-60, -34),
		# Left wing trailing edge
		Vector2(-40, -16),
		# Back
		Vector2(-35, -4),
		# Tail
		Vector2(-58, -6), Vector2(-65, 0), Vector2(-58, 6),
		# Body bottom
		Vector2(-35, 4),
		# Right wing trailing edge
		Vector2(-40, 16),
		# Right wing tip (swept back)
		Vector2(-60, 34),
		# Right wing leading edge
		Vector2(-45, 38), Vector2(-20, 32), Vector2(10, 18),
		# Belly
		Vector2(25, 14), Vector2(38, 10),
		# Chin
		Vector2(48, 4),
	])
	poly.color = Color(1.0, 0.55, 0.1, 0.85)
	# Eye
	var eye = Polygon2D.new()
	eye.polygon = _make_circle_polygon(3.0, 8)
	eye.position = Vector2(40, -5)
	eye.color = Color(0.15, 0.15, 0.15)
	poly.add_child(eye)
	return poly

func _make_circle_polygon(radius: float, segments: int) -> PackedVector2Array:
	"""Generate a circle as PackedVector2Array"""
	var points = PackedVector2Array()
	for i in segments:
		var angle = TAU * i / segments
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points

func _animate_intro_entrance(title: Label, subtitle: Label, scene_area: Control, creature_cards: Array, controls: Label, prompt: Label):
	"""Apply staggered entrance animations to intro elements"""
	# Start everything invisible
	title.modulate.a = 0
	subtitle.modulate.a = 0
	scene_area.modulate = Color(1, 1, 1, 0)
	for card in creature_cards:
		card.modulate = Color(1, 1, 1, 0)
	controls.modulate.a = 0
	prompt.modulate.a = 0

	var tween = create_tween()
	tween.set_parallel(true)

	# Title fades in
	tween.tween_property(title, "modulate:a", title.modulate.a, 0.0)  # no-op anchor
	tween.tween_property(title, "modulate:a", 1.0, 0.6).set_delay(0.1)

	# Subtitle
	tween.tween_property(subtitle, "modulate:a", 1.0, 0.5).set_delay(0.3)

	# Scene area
	tween.tween_property(scene_area, "modulate:a", 1.0, 0.6).set_delay(0.4)

	# Creature cards stagger
	for i in creature_cards.size():
		tween.tween_property(creature_cards[i], "modulate:a", 1.0, 0.5).set_delay(0.6 + i * 0.15)

	# Controls
	tween.tween_property(controls, "modulate:a", 1.0, 0.4).set_delay(1.1)

	# Prompt
	tween.tween_property(prompt, "modulate:a", 1.0, 0.4).set_delay(1.3)

	# Start pulse tween on prompt after entrance completes
	tween.chain().tween_callback(func():
		_start_prompt_pulse(prompt)
	).set_delay(1.5)

func _start_prompt_pulse(prompt: Label):
	"""Start the looping pulse animation on the press-any-key prompt"""
	intro_pulse_tween = create_tween().set_loops()
	intro_pulse_tween.tween_property(prompt, "modulate:a", 0.3, 0.8).set_trans(Tween.TRANS_SINE)
	intro_pulse_tween.tween_property(prompt, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE)

func _dismiss_intro():
	"""Fade out intro screen and show animal selection"""
	if not intro_active:
		return
	intro_active = false

	if intro_pulse_tween and intro_pulse_tween.is_valid():
		intro_pulse_tween.kill()

	if intro_overlay and intro_overlay.get_child_count() > 0:
		var panel = intro_overlay.get_child(0)
		var fade = create_tween()
		fade.tween_property(panel, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fade.tween_callback(func():
			intro_overlay.hide()
			if is_instance_valid(animal_overlay):
				animal_overlay.show()
		)
	else:
		if intro_overlay:
			intro_overlay.hide()
		if is_instance_valid(animal_overlay):
			animal_overlay.show()
