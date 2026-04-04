extends StaticBody2D
class_name RocketLauncher

# Ground-based rocket launcher with multiple firing patterns
signal rocket_launched(rocket: Rocket, launcher: RocketLauncher)
signal launcher_reloading(reload_time: float)
signal warning_activated(launcher: RocketLauncher, warning_time: float)

# Launcher types with different behaviors
enum LauncherType {
	SINGLE_SHOT,     # Fires one rocket at a time
	RAPID_FIRE,      # Quick succession of rockets
	BARRAGE,         # Fires multiple rockets simultaneously
	TRACKING_SITE,   # Launches tracking rockets
	CLUSTER_LAUNCHER, # Fires cluster rockets
	SMOKE_LAUNCHER,  # Creates smoke barriers
	DEFENSE_TURRET,  # Rapid defensive fire
	MEGA_LAUNCHER    # Boss-level launcher with mixed attacks
}

# Launch patterns
enum LaunchPattern {
	STRAIGHT_UP,     # Direct vertical launch
	ANGLED_SHOT,     # Angled toward player path
	PREDICTIVE,      # Aims where player will be
	SPRAY_PATTERN,   # Multiple angles
	WAVE_PATTERN,    # Sequential angled shots
	AMBUSH,          # Waits for player proximity
	BARRAGE_WALL     # Creates wall of rockets
}

# Launcher configuration
@export var launcher_type: LauncherType = LauncherType.SINGLE_SHOT
@export var launch_pattern: LaunchPattern = LaunchPattern.STRAIGHT_UP
@export var rockets_per_salvo: int = 1
@export var reload_time: float = 3.0
@export var warning_time: float = 2.0
@export var detection_range: float = 400.0
@export var max_range: float = 800.0

# Targeting and timing
var player_reference: SugarGlider
var is_armed: bool = true
var is_reloading: bool = false
var is_warning: bool = false
var last_fire_time: float = 0.0
var warning_start_time: float = 0.0

# Visual components
var launcher_base: Polygon2D
var launcher_barrel: Polygon2D
var warning_light: Sprite2D
var steam_vent: GPUParticles2D
var targeting_laser: Line2D

# Audio components
var warning_sound: AudioStreamPlayer2D
var launch_sound: AudioStreamPlayer2D

# Rocket prefab
var rocket_scene: PackedScene = preload("res://scenes/hazards/Rocket.tscn")

# Launch parameters
var current_target_position: Vector2
var launch_angles: Array[float] = []
var salvo_index: int = 0
var salvo_timer: float = 0.0
var salvo_interval: float = 0.2

func _ready():
	collision_layer = 8  # Launcher layer
	collision_mask = 0   # Doesn't need collision detection

	player_reference = get_tree().get_first_node_in_group("player")

	setup_visual_components()
	setup_audio_components()
	configure_launcher_type()

	print("Rocket launcher deployed: ", LauncherType.keys()[launcher_type])

func _process(delta):
	if not is_armed or GameManager.is_paused():
		return

	update_targeting(delta)
	update_warning_state(delta)
	update_firing_logic(delta)
	update_visual_effects(delta)

func setup_visual_components():
	"""Create visual representation of the launcher"""
	# Launcher base
	launcher_base = Polygon2D.new()
	launcher_base.color = Color(0.4, 0.4, 0.3, 1.0)
	var base_points = create_launcher_base_shape()
	launcher_base.polygon = base_points
	add_child(launcher_base)

	# Launcher barrel
	launcher_barrel = Polygon2D.new()
	launcher_barrel.color = Color(0.3, 0.3, 0.2, 1.0)
	var barrel_points = create_launcher_barrel_shape()
	launcher_barrel.polygon = barrel_points
	add_child(launcher_barrel)

	# Warning light
	warning_light = Sprite2D.new()
	var warning_texture = ImageTexture.new()
	var warning_image = Image.create(12, 12, false, Image.FORMAT_RGBA8)
	warning_image.fill(Color.RED)
	warning_texture.set_image(warning_image)
	warning_light.texture = warning_texture
	warning_light.position = Vector2(0, -30)
	warning_light.visible = false
	add_child(warning_light)

	# Steam vent for launch effects
	setup_steam_vent()

	# Targeting laser for advanced launchers
	if launcher_type in [LauncherType.TRACKING_SITE, LauncherType.DEFENSE_TURRET]:
		setup_targeting_laser()

func create_launcher_base_shape() -> PackedVector2Array:
	"""Create the launcher base polygon"""
	var points = PackedVector2Array()
	var width = 40.0
	var height = 20.0

	points.append(Vector2(-width / 2, 0))
	points.append(Vector2(width / 2, 0))
	points.append(Vector2(width / 3, -height))
	points.append(Vector2(-width / 3, -height))

	return points

func create_launcher_barrel_shape() -> PackedVector2Array:
	"""Create the launcher barrel polygon"""
	var points = PackedVector2Array()

	match launcher_type:
		LauncherType.BARRAGE, LauncherType.DEFENSE_TURRET:
			# Multiple barrels
			for i in range(3):
				var barrel_x = (i - 1) * 15.0
				points.append(Vector2(barrel_x - 3, -20))
				points.append(Vector2(barrel_x + 3, -20))
				points.append(Vector2(barrel_x + 2, -40))
				points.append(Vector2(barrel_x - 2, -40))

		_:
			# Single barrel
			points.append(Vector2(-6, -20))
			points.append(Vector2(6, -20))
			points.append(Vector2(4, -35))
			points.append(Vector2(-4, -35))

	return points

func setup_steam_vent():
	"""Set up steam/smoke effects for launches"""
	steam_vent = GPUParticles2D.new()
	steam_vent.position = Vector2(0, -35)
	steam_vent.emitting = false
	steam_vent.amount = 20
	steam_vent.lifetime = 1.0

	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, -1, 0)
	material.initial_velocity_min = 80.0
	material.initial_velocity_max = 120.0
	material.gravity = Vector3(0, -20, 0)
	material.scale_min = 0.5
	material.scale_max = 1.2
	material.color = Color(0.8, 0.8, 0.8, 0.7)

	steam_vent.process_material = material
	add_child(steam_vent)

func setup_targeting_laser():
	"""Set up targeting laser for advanced launchers"""
	targeting_laser = Line2D.new()
	targeting_laser.width = 2.0
	targeting_laser.default_color = Color.RED
	targeting_laser.visible = false
	add_child(targeting_laser)

func setup_audio_components():
	"""Set up audio for launcher"""
	warning_sound = AudioStreamPlayer2D.new()
	warning_sound.bus = "SFX"
	# Would set warning sound here
	add_child(warning_sound)

	launch_sound = AudioStreamPlayer2D.new()
	launch_sound.bus = "SFX"
	# Would set launch sound here
	add_child(launch_sound)

func configure_launcher_type():
	"""Configure specific behavior based on launcher type"""
	match launcher_type:
		LauncherType.SINGLE_SHOT:
			reload_time = 4.0
			warning_time = 2.0

		LauncherType.RAPID_FIRE:
			rockets_per_salvo = 3
			reload_time = 5.0
			warning_time = 1.5
			salvo_interval = 0.3

		LauncherType.BARRAGE:
			rockets_per_salvo = 5
			reload_time = 8.0
			warning_time = 3.0
			salvo_interval = 0.1

		LauncherType.TRACKING_SITE:
			reload_time = 6.0
			warning_time = 2.5
			detection_range = 500.0

		LauncherType.CLUSTER_LAUNCHER:
			reload_time = 10.0
			warning_time = 4.0

		LauncherType.SMOKE_LAUNCHER:
			rockets_per_salvo = 2
			reload_time = 6.0
			warning_time = 1.0

		LauncherType.DEFENSE_TURRET:
			rockets_per_salvo = 4
			reload_time = 3.0
			warning_time = 1.0
			detection_range = 300.0
			salvo_interval = 0.15

		LauncherType.MEGA_LAUNCHER:
			rockets_per_salvo = 8
			reload_time = 15.0
			warning_time = 5.0
			detection_range = 600.0

	# Guard reload_time against zero/negative values after all configuration
	reload_time = max(reload_time, 0.1)

func update_targeting(delta):
	"""Update targeting system"""
	if not is_instance_valid(player_reference):
		return

	var distance_to_player = global_position.distance_to(player_reference.global_position)

	# Check if player is in range
	if distance_to_player > max_range:
		return

	# Calculate target position based on launch pattern
	match launch_pattern:
		LaunchPattern.STRAIGHT_UP:
			current_target_position = global_position + Vector2(0, -500)

		LaunchPattern.ANGLED_SHOT:
			var angle_to_player = global_position.angle_to_point(player_reference.global_position)
			current_target_position = global_position + Vector2.from_angle(angle_to_player) * 400

		LaunchPattern.PREDICTIVE:
			# Predict where player will be
			var player_velocity = player_reference.velocity
			var time_to_target = distance_to_player / 400.0  # Assume rocket speed
			current_target_position = player_reference.global_position + player_velocity * time_to_target

		LaunchPattern.SPRAY_PATTERN:
			# Will be handled during launch
			pass

		LaunchPattern.AMBUSH:
			if distance_to_player < detection_range:
				current_target_position = player_reference.global_position

	# Update targeting laser
	if targeting_laser and is_warning:
		targeting_laser.visible = true
		targeting_laser.points = [Vector2.ZERO, current_target_position - global_position]

func update_warning_state(delta):
	"""Update warning indicators and timing"""
	if is_reloading:
		return

	var distance_to_player = global_position.distance_to(player_reference.global_position) if is_instance_valid(player_reference) else 1000.0

	# Check if we should start warning
	if not is_warning and should_start_warning(distance_to_player):
		start_warning()

	# Update warning duration
	if is_warning:
		var warning_elapsed = Time.get_ticks_msec() / 1000.0 - warning_start_time
		if warning_elapsed >= warning_time:
			fire_rockets()

func should_start_warning(distance: float) -> bool:
	"""Determine if we should start warning sequence"""
	if distance > detection_range:
		return false

	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_fire_time < reload_time:
		return false

	# Pattern-specific conditions
	match launch_pattern:
		LaunchPattern.AMBUSH:
			return distance < detection_range / 2.0
		_:
			return true

func start_warning():
	"""Start warning sequence"""
	is_warning = true
	warning_start_time = Time.get_ticks_msec() / 1000.0

	# Visual warning
	if warning_light:
		warning_light.visible = true
		animate_warning_light()

	# Audio warning
	AudioManager.play_rocket_warning()

	# Targeting laser
	if targeting_laser:
		targeting_laser.visible = true

	emit_signal("warning_activated", self, warning_time)

	print("Launcher warning started")

func animate_warning_light():
	"""Animate the warning light"""
	if not warning_light:
		return

	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(warning_light, "modulate", Color.TRANSPARENT, 0.2)
	tween.tween_property(warning_light, "modulate", Color.RED, 0.2)

func update_firing_logic(delta):
	"""Update firing sequence logic"""
	if not is_warning:
		return

	# Handle salvo firing
	if salvo_index < rockets_per_salvo:
		salvo_timer += delta
		if salvo_timer >= salvo_interval:
			fire_single_rocket()
			salvo_timer = 0.0

func fire_rockets():
	"""Fire rockets according to launcher type and pattern"""
	if is_reloading:
		return

	print("Firing rockets from ", LauncherType.keys()[launcher_type])

	# Calculate launch angles
	calculate_launch_angles()

	# Start salvo sequence
	salvo_index = 0
	salvo_timer = 0.0

	# Fire first rocket immediately
	fire_single_rocket()

func calculate_launch_angles():
	"""Calculate launch angles based on pattern"""
	launch_angles.clear()

	match launch_pattern:
		LaunchPattern.STRAIGHT_UP:
			launch_angles.append(-PI / 2.0)  # Straight up

		LaunchPattern.ANGLED_SHOT:
			var angle_to_target = global_position.angle_to_point(current_target_position)
			launch_angles.append(angle_to_target)

		LaunchPattern.PREDICTIVE:
			var angle_to_predicted = global_position.angle_to_point(current_target_position)
			launch_angles.append(angle_to_predicted)

		LaunchPattern.SPRAY_PATTERN:
			# Set a valid target position for spray pattern
			if is_instance_valid(player_reference):
				current_target_position = player_reference.global_position
			elif current_target_position == Vector2.ZERO:
				current_target_position = global_position + Vector2(0, -500)  # Default upward
			var base_angle = -PI / 2.0
			var spread = PI / 3.0
			for i in rockets_per_salvo:
				var angle = base_angle + (spread / rockets_per_salvo) * (i - rockets_per_salvo / 2.0)
				launch_angles.append(angle)

		LaunchPattern.WAVE_PATTERN:
			var base_angle = global_position.angle_to_point(current_target_position)
			for i in rockets_per_salvo:
				var offset = (i - rockets_per_salvo / 2.0) * 0.3
				launch_angles.append(base_angle + offset)

		LaunchPattern.BARRAGE_WALL:
			for i in rockets_per_salvo:
				var angle = -PI / 2.0 + (PI / 6.0) * (i - rockets_per_salvo / 2.0) / rockets_per_salvo
				launch_angles.append(angle)

	# Ensure we have enough angles
	while launch_angles.size() < rockets_per_salvo:
		launch_angles.append(-PI / 2.0)

func fire_single_rocket():
	"""Fire a single rocket in the sequence"""
	if salvo_index >= rockets_per_salvo or salvo_index >= launch_angles.size():
		finish_firing_sequence()
		return

	var rocket = rocket_scene.instantiate()
	rocket.global_position = global_position + Vector2(0, -35)

	# Configure rocket based on launcher type
	configure_rocket(rocket, launch_angles[salvo_index])

	# Add to scene
	get_parent().add_child(rocket)

	# Launch effects
	create_launch_effects()

	# Audio
	AudioManager.play_rocket_launch()

	# Emit signal
	emit_signal("rocket_launched", rocket, self)

	salvo_index += 1

	print("Rocket fired: angle ", rad_to_deg(launch_angles[salvo_index - 1]))

func configure_rocket(rocket: Rocket, launch_angle: float):
	"""Configure individual rocket based on launcher type"""
	# Set initial velocity
	var launch_speed = 400.0
	var velocity = Vector2.from_angle(launch_angle) * launch_speed
	rocket.set_initial_velocity(velocity)

	# Configure rocket type
	match launcher_type:
		LauncherType.SINGLE_SHOT:
			rocket.rocket_type = Rocket.RocketType.BASIC

		LauncherType.RAPID_FIRE:
			rocket.rocket_type = Rocket.RocketType.FAST

		LauncherType.BARRAGE:
			rocket.rocket_type = Rocket.RocketType.BASIC

		LauncherType.TRACKING_SITE:
			rocket.rocket_type = Rocket.RocketType.TRACKING
			rocket.set_target(current_target_position)

		LauncherType.CLUSTER_LAUNCHER:
			rocket.rocket_type = Rocket.RocketType.CLUSTER

		LauncherType.SMOKE_LAUNCHER:
			rocket.rocket_type = Rocket.RocketType.SMOKE_TRAIL

		LauncherType.DEFENSE_TURRET:
			rocket.rocket_type = Rocket.RocketType.FAST if salvo_index % 2 == 0 else Rocket.RocketType.BASIC

		LauncherType.MEGA_LAUNCHER:
			# Mix of different rocket types
			var rocket_types = [
				Rocket.RocketType.BASIC,
				Rocket.RocketType.TRACKING,
				Rocket.RocketType.FAST,
				Rocket.RocketType.CLUSTER
			]
			rocket.rocket_type = rocket_types[salvo_index % rocket_types.size()]

func create_launch_effects():
	"""Create visual and particle effects for launch"""
	# Steam vent burst
	if steam_vent:
		steam_vent.emitting = true
		get_tree().create_timer(0.5).timeout.connect(func(): steam_vent.emitting = false)

	# Flash effect
	if launcher_barrel:
		var original_color = launcher_barrel.color
		launcher_barrel.color = Color.ORANGE
		var tween = create_tween()
		tween.tween_property(launcher_barrel, "color", original_color, 0.2)

func finish_firing_sequence():
	"""Complete the firing sequence and start reload"""
	is_warning = false
	is_reloading = true
	last_fire_time = Time.get_ticks_msec() / 1000.0

	# Hide warning indicators
	if warning_light:
		warning_light.visible = false

	if targeting_laser:
		targeting_laser.visible = false

	emit_signal("launcher_reloading", reload_time)

	# Start reload timer
	get_tree().create_timer(reload_time).timeout.connect(finish_reload)

	print("Launcher reloading for ", reload_time, " seconds")

func finish_reload():
	"""Complete reload sequence"""
	is_reloading = false
	print("Launcher ready to fire")

func update_visual_effects(delta):
	"""Update ongoing visual effects"""
	# Pulse warning light during warning
	if is_warning and warning_light and warning_light.visible:
		var pulse_speed = 5.0
		var alpha = sin(Time.get_ticks_msec() / 1000.0 * pulse_speed) * 0.5 + 0.5
		warning_light.modulate.a = alpha

# Strategic launcher placement and behavior
func set_ambush_trigger(trigger_distance: float):
	"""Configure ambush behavior"""
	if launch_pattern == LaunchPattern.AMBUSH:
		detection_range = trigger_distance

func set_defensive_mode(defend_radius: float):
	"""Set up defensive firing pattern"""
	detection_range = defend_radius
	launch_pattern = LaunchPattern.SPRAY_PATTERN

func get_threat_level() -> float:
	"""Get threat level rating for this launcher"""
	var threat = 0.5

	# Launcher type factor
	match launcher_type:
		LauncherType.MEGA_LAUNCHER:
			threat = 2.0
		LauncherType.TRACKING_SITE:
			threat = 1.5
		LauncherType.BARRAGE:
			threat = 1.3
		LauncherType.DEFENSE_TURRET:
			threat = 1.2
		_:
			threat = 1.0

	# Pattern factor
	match launch_pattern:
		LaunchPattern.PREDICTIVE, LaunchPattern.BARRAGE_WALL:
			threat *= 1.3
		LaunchPattern.SPRAY_PATTERN:
			threat *= 1.1

	return threat

func get_safe_approach_angles() -> Array[float]:
	"""Get recommended safe approach angles"""
	var safe_angles = []

	# Base safe angles (sides)
	safe_angles.append(0.0)      # From right
	safe_angles.append(PI)       # From left

	# Avoid direct approach from below for most launchers
	if launcher_type != LauncherType.DEFENSE_TURRET:
		safe_angles.append(PI / 2.0)  # From below

	return safe_angles

func disable_launcher():
	"""Disable launcher (for special events)"""
	is_armed = false
	if warning_light:
		warning_light.visible = false
	if targeting_laser:
		targeting_laser.visible = false

func enable_launcher():
	"""Re-enable launcher"""
	is_armed = true

func get_launcher_info() -> Dictionary:
	"""Get launcher information for debugging"""
	return {
		"type": LauncherType.keys()[launcher_type],
		"pattern": LaunchPattern.keys()[launch_pattern],
		"position": global_position,
		"is_armed": is_armed,
		"is_reloading": is_reloading,
		"is_warning": is_warning,
		"threat_level": get_threat_level()
	}