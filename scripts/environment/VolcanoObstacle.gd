extends StaticBody2D
class_name VolcanoObstacle

# Enhanced volcano obstacle for strategic navigation
signal obstacle_approached(obstacle: VolcanoObstacle, distance: float)
signal obstacle_passed(obstacle: VolcanoObstacle)

# Volcano configuration
@export var height: float = 300.0
@export var width: float = 100.0
@export var has_lava_flow: bool = false
@export var danger_radius: float = 150.0

# Visual components
var main_body: Polygon2D
var lava_glow: Polygon2D
var steam_particles: GPUParticles2D
var warning_area: Area2D

# Obstacle state
var player_nearby: bool = false
var has_been_passed: bool = false
var creation_time: float

# Lava flow animation
var lava_glow_intensity: float = 1.0
var lava_pulse_speed: float = 2.0

func _ready():
	creation_time = Time.get_ticks_msec() / 1000.0
	collision_layer = 2  # Obstacle layer
	collision_mask = 0   # Doesn't need to detect anything

	create_visual_components()
	setup_collision()
	setup_warning_area()

	if has_lava_flow:
		setup_lava_effects()

	print("Volcano obstacle created at ", global_position, " height: ", height)

func _process(delta):
	if has_lava_flow:
		animate_lava_glow(delta)

	check_player_proximity()

func create_visual_components():
	"""Create the visual representation of the volcano"""
	# Main volcano body
	main_body = Polygon2D.new()
	main_body.color = Color(0.4, 0.2, 0.1, 1.0)  # Dark brown/volcanic

	# Create volcano shape (triangular with some irregularity)
	var points = create_volcano_shape()
	main_body.polygon = points
	add_child(main_body)

	# Lava glow effect (if has lava flow)
	if has_lava_flow:
		lava_glow = Polygon2D.new()
		lava_glow.color = Color(1.0, 0.3, 0.0, 0.6)  # Orange glow
		var lava_points = create_lava_shape()
		lava_glow.polygon = lava_points
		lava_glow.z_index = -1
		add_child(lava_glow)

	# Steam particles for active volcanoes
	create_steam_effects()

func create_volcano_shape() -> PackedVector2Array:
	"""Create an irregular volcano shape"""
	var points = PackedVector2Array()
	var half_width = width / 2.0

	# Base points
	points.append(Vector2(-half_width, 0))
	points.append(Vector2(half_width, 0))

	# Add some irregularity to the sides
	var segments = 8
	for i in range(segments):
		var progress = float(i) / segments
		var side_height = -height * progress
		var side_width = lerp(half_width, 5.0, progress)

		# Add some random variation
		var variation = randf_range(-10.0, 10.0)
		side_width += variation

		# Right side (going up)
		points.insert(1, Vector2(side_width, side_height))
		# Left side (going up)
		points.append(Vector2(-side_width, side_height))

	# Peak
	points.insert(segments + 1, Vector2(0, -height))

	return points

func create_lava_shape() -> PackedVector2Array:
	"""Create lava flow shape"""
	var points = PackedVector2Array()
	var half_width = width / 3.0

	# Lava flowing down the sides
	points.append(Vector2(-half_width, -height * 0.8))
	points.append(Vector2(-half_width * 1.5, -height * 0.3))
	points.append(Vector2(-half_width * 0.5, 0))
	points.append(Vector2(half_width * 0.5, 0))
	points.append(Vector2(half_width * 1.5, -height * 0.3))
	points.append(Vector2(half_width, -height * 0.8))

	return points

func create_steam_effects():
	"""Create particle effects for volcanic steam"""
	steam_particles = GPUParticles2D.new()
	steam_particles.position = Vector2(0, -height - 10)
	steam_particles.emitting = true
	steam_particles.amount = 25
	steam_particles.lifetime = 2.0

	# Configure particle material (basic settings)
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, -1, 0)
	material.initial_velocity_min = 20.0
	material.initial_velocity_max = 50.0
	material.gravity = Vector3(0, -50, 0)
	material.scale_min = 0.5
	material.scale_max = 1.5
	steam_particles.process_material = material

	add_child(steam_particles)

func setup_collision():
	"""Set up collision detection"""
	var collision_shape = CollisionShape2D.new()
	var shape = ConvexPolygonShape2D.new()

	# Simplified collision shape based on main body
	var collision_points = PackedVector2Array()
	var half_width = width / 2.0
	collision_points.append(Vector2(-half_width, 0))
	collision_points.append(Vector2(half_width, 0))
	collision_points.append(Vector2(half_width * 0.7, -height * 0.7))
	collision_points.append(Vector2(0, -height))
	collision_points.append(Vector2(-half_width * 0.7, -height * 0.7))

	shape.points = collision_points
	collision_shape.shape = shape
	add_child(collision_shape)

func setup_warning_area():
	"""Set up proximity warning area"""
	warning_area = Area2D.new()
	warning_area.collision_layer = 0
	warning_area.collision_mask = 1  # Player layer

	var warning_shape = CollisionShape2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = danger_radius
	warning_shape.shape = circle_shape
	warning_area.add_child(warning_shape)

	warning_area.body_entered.connect(_on_warning_area_entered)
	warning_area.body_exited.connect(_on_warning_area_exited)

	add_child(warning_area)

func setup_lava_effects():
	"""Set up lava flow visual effects"""
	if not lava_glow:
		return

	# Add subtle glow animation
	lava_glow.modulate = Color(1.0, 0.4, 0.0, 0.8)

func animate_lava_glow(delta):
	"""Animate lava glow effect"""
	if not lava_glow:
		return

	# Pulsing glow effect
	var time = Time.get_ticks_msec() / 1000.0
	var pulse = sin(time * lava_pulse_speed) * 0.2 + 0.8
	lava_glow.modulate.a = pulse * 0.6

	# Heat distortion effect (color shifting)
	var heat_intensity = sin(time * lava_pulse_speed * 1.5) * 0.1 + 0.9
	lava_glow.modulate.r = heat_intensity

func check_player_proximity():
	"""Check if player is approaching for strategic warnings"""
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	var distance = global_position.distance_to(player.global_position)

	# Check if player passed this obstacle
	if not has_been_passed and player.global_position.x > global_position.x + width / 2.0:
		has_been_passed = true
		emit_signal("obstacle_passed", self)

		# Award points for successful navigation
		GameManager.add_score(10)

	# Emit proximity signals for other systems
	if distance < danger_radius * 1.5:
		if not player_nearby:
			player_nearby = true
		emit_signal("obstacle_approached", self, distance)

func _on_warning_area_entered(body):
	"""Handle player entering warning area"""
	if body.has_method("get_current_energy"):  # It's the player
		player_nearby = true

		# Visual feedback - make volcano more prominent
		if main_body:
			var tween = create_tween()
			tween.tween_property(main_body, "modulate", Color(1.2, 1.0, 1.0, 1.0), 0.3)

		# Audio warning
		AudioManager.play_sfx("volcano_rumble", 0.5)

func _on_warning_area_exited(body):
	"""Handle player exiting warning area"""
	if body.has_method("get_current_energy"):  # It's the player
		player_nearby = false

		# Reset visual feedback
		if main_body:
			var tween = create_tween()
			tween.tween_property(main_body, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.3)

# Strategic navigation features
func get_safe_passage_points() -> Array[Vector2]:
	"""Get recommended safe passage points around this volcano"""
	var safe_points = []
	var clearance = 80.0  # Minimum clearance distance

	# Above the volcano
	if height < 400.0:  # If volcano isn't too tall
		safe_points.append(global_position + Vector2(0, -height - clearance))

	# Around the sides
	safe_points.append(global_position + Vector2(-width / 2.0 - clearance, -height / 2.0))
	safe_points.append(global_position + Vector2(width / 2.0 + clearance, -height / 2.0))

	# Below (if there's room)
	safe_points.append(global_position + Vector2(0, clearance))

	return safe_points

func get_difficulty_rating() -> float:
	"""Get difficulty rating for this obstacle"""
	var rating = 0.0

	# Height factor
	rating += height / 500.0

	# Width factor (wider = easier to avoid)
	rating += (200.0 - width) / 200.0

	# Lava flow makes it more dangerous
	if has_lava_flow:
		rating += 0.3

	return clamp(rating, 0.1, 1.0)

func get_navigation_hint() -> String:
	"""Get navigation hint for strategic players"""
	var hints = []

	if height < 250.0:
		hints.append("fly_over")
	if width < 80.0:
		hints.append("narrow_gap")
	if has_lava_flow:
		hints.append("avoid_lava")

	if hints.is_empty():
		return "navigate_around"
	else:
		return hints[0]

# Cleanup and optimization
func cleanup():
	"""Clean up resources when obstacle is no longer needed"""
	if steam_particles:
		steam_particles.emitting = false

	# Fade out before deletion
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 0.0), 1.0)
	tween.tween_callback(queue_free)

func get_obstacle_info() -> Dictionary:
	"""Get obstacle information for debugging and analytics"""
	return {
		"type": "volcano",
		"height": height,
		"width": width,
		"has_lava": has_lava_flow,
		"position": global_position,
		"difficulty": get_difficulty_rating(),
		"passed": has_been_passed,
		"navigation_hint": get_navigation_hint()
	}