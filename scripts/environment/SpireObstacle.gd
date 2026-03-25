extends StaticBody2D
class_name SpireObstacle

# Spire obstacle - tall, narrow formations requiring precision navigation
signal obstacle_approached(obstacle: SpireObstacle, distance: float)
signal obstacle_passed(obstacle: SpireObstacle)

# Spire configuration
@export var height: float = 200.0
@export var width: float = 40.0
@export var spire_type: SpireType = SpireType.SINGLE
@export var rock_hardness: float = 1.0  # Affects bounce strength

enum SpireType {
	SINGLE,      # Single tall spire
	CLUSTER,     # Multiple spires close together
	ARCH,        # Spire with gap in middle
	LEANING,     # Angled spire
	CRYSTAL      # Special crystal spire with effects
}

# Visual components
var main_spire: Polygon2D
var crystal_glow: Polygon2D
var rock_texture: Polygon2D
var warning_area: Area2D
var wind_particles: GPUParticles2D

# Obstacle state
var player_nearby: bool = false
var has_been_passed: bool = false
var creation_time: float
var lean_angle: float = 0.0

# Crystal effects (for crystal spires)
var crystal_pulse_speed: float = 3.0
var has_wind_effect: bool = false

func _ready():
	creation_time = Time.get_ticks_msec() / 1000.0
	collision_layer = 2  # Obstacle layer
	collision_mask = 0   # Doesn't need to detect anything

	# Set lean angle for leaning spires
	if spire_type == SpireType.LEANING:
		lean_angle = randf_range(-15.0, 15.0)
		rotation_degrees = lean_angle

	create_visual_components()
	setup_collision()
	setup_warning_area()

	if spire_type == SpireType.CRYSTAL:
		setup_crystal_effects()

	print("Spire obstacle created at ", global_position, " type: ", SpireType.keys()[spire_type])

func _process(delta):
	if spire_type == SpireType.CRYSTAL:
		animate_crystal_effects(delta)

	check_player_proximity()

func create_visual_components():
	"""Create the visual representation based on spire type"""
	match spire_type:
		SpireType.SINGLE:
			create_single_spire()
		SpireType.CLUSTER:
			create_cluster_spires()
		SpireType.ARCH:
			create_arch_spire()
		SpireType.LEANING:
			create_single_spire()  # Same as single but rotated
		SpireType.CRYSTAL:
			create_crystal_spire()

func create_single_spire():
	"""Create a single tall spire"""
	main_spire = Polygon2D.new()
	main_spire.color = Color(0.3, 0.25, 0.2, 1.0)  # Dark rock color

	var points = create_spire_shape(width, height)
	main_spire.polygon = points
	add_child(main_spire)

	# Add texture variation
	add_rock_texture()

func create_cluster_spires():
	"""Create multiple spires close together"""
	var spire_count = randi_range(2, 4)
	var total_width = width * 1.5
	var spire_spacing = total_width / spire_count

	for i in spire_count:
		var spire = Polygon2D.new()
		spire.color = Color(0.3, 0.25, 0.2, 1.0)

		var spire_height = height + randf_range(-30, 30)
		var spire_width = width / 2.0 + randf_range(-5, 5)
		var spire_x = (i - spire_count / 2.0) * spire_spacing

		var points = create_spire_shape(spire_width, spire_height, Vector2(spire_x, 0))
		spire.polygon = points
		add_child(spire)

	# Set main spire reference to first one for collision
	main_spire = get_child(0)

func create_arch_spire():
	"""Create a spire with a gap in the middle"""
	# Left pillar
	var left_spire = Polygon2D.new()
	left_spire.color = Color(0.3, 0.25, 0.2, 1.0)
	var left_points = create_spire_shape(width / 3.0, height, Vector2(-width / 2.5, 0))
	left_spire.polygon = left_points
	add_child(left_spire)

	# Right pillar
	var right_spire = Polygon2D.new()
	right_spire.color = Color(0.3, 0.25, 0.2, 1.0)
	var right_points = create_spire_shape(width / 3.0, height, Vector2(width / 2.5, 0))
	right_spire.polygon = right_points
	add_child(right_spire)

	# Connecting arch (optional, for visual)
	var arch = Polygon2D.new()
	arch.color = Color(0.25, 0.2, 0.15, 1.0)
	var arch_points = create_arch_shape()
	arch.polygon = arch_points
	add_child(arch)

	main_spire = left_spire

func create_crystal_spire():
	"""Create a special crystal spire with glow effects"""
	main_spire = Polygon2D.new()
	main_spire.color = Color(0.6, 0.8, 1.0, 0.9)  # Crystal blue

	var points = create_crystal_shape(width, height)
	main_spire.polygon = points
	add_child(main_spire)

	# Crystal glow effect
	crystal_glow = Polygon2D.new()
	crystal_glow.color = Color(0.3, 0.6, 1.0, 0.3)  # Blue glow
	crystal_glow.polygon = create_crystal_shape(width * 1.3, height * 1.1)
	crystal_glow.z_index = -1
	add_child(crystal_glow)

func create_spire_shape(spire_width: float, spire_height: float, offset: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	"""Create a spire shape with rocky irregularities"""
	var points = PackedVector2Array()
	var half_width = spire_width / 2.0

	# Base
	points.append(offset + Vector2(-half_width, 0))
	points.append(offset + Vector2(half_width, 0))

	# Sides with some irregularity
	var segments = 6
	for i in range(segments):
		var progress = float(i + 1) / segments
		var side_height = -spire_height * progress
		var side_width = lerp(half_width, 2.0, progress)

		# Add rocky irregularity
		var variation = randf_range(-3.0, 3.0) * (1.0 - progress)
		side_width += variation

		points.insert(1 + i, offset + Vector2(side_width, side_height))
		points.append(offset + Vector2(-side_width, side_height))

	# Peak
	points.insert(1 + segments, offset + Vector2(randf_range(-2.0, 2.0), -spire_height))

	return points

func create_crystal_shape(crystal_width: float, crystal_height: float) -> PackedVector2Array:
	"""Create angular crystal shape"""
	var points = PackedVector2Array()
	var half_width = crystal_width / 2.0

	# Crystal base
	points.append(Vector2(-half_width, 0))
	points.append(Vector2(half_width, 0))

	# Crystal facets
	points.append(Vector2(half_width * 0.7, -crystal_height * 0.3))
	points.append(Vector2(half_width * 0.3, -crystal_height * 0.7))
	points.append(Vector2(0, -crystal_height))
	points.append(Vector2(-half_width * 0.3, -crystal_height * 0.7))
	points.append(Vector2(-half_width * 0.7, -crystal_height * 0.3))

	return points

func create_arch_shape() -> PackedVector2Array:
	"""Create an arch connecting two pillars"""
	var points = PackedVector2Array()
	var arch_height = height * 0.8

	points.append(Vector2(-width / 3.0, -arch_height))
	points.append(Vector2(-width / 6.0, -arch_height - 20))
	points.append(Vector2(0, -arch_height - 25))
	points.append(Vector2(width / 6.0, -arch_height - 20))
	points.append(Vector2(width / 3.0, -arch_height))
	points.append(Vector2(width / 4.0, -arch_height + 15))
	points.append(Vector2(-width / 4.0, -arch_height + 15))

	return points

func add_rock_texture():
	"""Add texture variation to rock spires"""
	rock_texture = Polygon2D.new()
	rock_texture.color = Color(0.35, 0.3, 0.25, 0.6)  # Slightly lighter rock

	# Create smaller texture polygons
	var texture_points = PackedVector2Array()
	var segments = 4

	for i in segments:
		var progress = float(i) / segments
		var tex_height = -height * progress * randf_range(0.8, 1.0)
		var tex_width = width * 0.3 * randf_range(0.5, 1.0)

		texture_points.append(Vector2(-tex_width / 2.0, tex_height))
		texture_points.append(Vector2(tex_width / 2.0, tex_height - 10))

	if texture_points.size() > 2:
		rock_texture.polygon = texture_points
		add_child(rock_texture)

func setup_collision():
	"""Set up collision detection based on spire type"""
	match spire_type:
		SpireType.ARCH:
			setup_arch_collision()
		SpireType.CLUSTER:
			setup_cluster_collision()
		_:
			setup_single_collision()

func setup_single_collision():
	"""Set up collision for single spire"""
	var collision_shape = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(width, height)
	collision_shape.shape = shape
	collision_shape.position.y = -height / 2.0
	add_child(collision_shape)

func setup_arch_collision():
	"""Set up collision for arch spire (two separate collision areas)"""
	# Left pillar
	var left_collision = CollisionShape2D.new()
	var left_shape = RectangleShape2D.new()
	left_shape.size = Vector2(width / 3.0, height)
	left_collision.shape = left_shape
	left_collision.position = Vector2(-width / 2.5, -height / 2.0)
	add_child(left_collision)

	# Right pillar
	var right_collision = CollisionShape2D.new()
	var right_shape = RectangleShape2D.new()
	right_shape.size = Vector2(width / 3.0, height)
	right_collision.shape = right_shape
	right_collision.position = Vector2(width / 2.5, -height / 2.0)
	add_child(right_collision)

	# Arch top collision
	var arch_collision = CollisionShape2D.new()
	var arch_shape = RectangleShape2D.new()
	arch_shape.size = Vector2(width, 20)
	arch_collision.shape = arch_shape
	arch_collision.position = Vector2(0, -height + 10)
	add_child(arch_collision)

func setup_cluster_collision():
	"""Set up collision for cluster spires"""
	var collision_shape = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(width * 1.5, height)
	collision_shape.shape = shape
	collision_shape.position.y = -height / 2.0
	add_child(collision_shape)

func setup_warning_area():
	"""Set up proximity detection"""
	warning_area = Area2D.new()
	warning_area.collision_layer = 0
	warning_area.collision_mask = 1  # Player layer

	var warning_shape = CollisionShape2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = 120.0
	warning_shape.shape = circle_shape
	warning_area.add_child(warning_shape)

	warning_area.body_entered.connect(_on_warning_area_entered)
	warning_area.body_exited.connect(_on_warning_area_exited)

	add_child(warning_area)

func setup_crystal_effects():
	"""Set up special crystal spire effects"""
	# Create wind particles around crystal
	wind_particles = GPUParticles2D.new()
	wind_particles.position = Vector2(0, -height / 2.0)
	wind_particles.emitting = true
	wind_particles.amount = 15

	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(1, 0, 0)
	material.initial_velocity_min = 30.0
	material.initial_velocity_max = 60.0
	material.gravity = Vector3(0, 0, 0)
	material.scale_min = 0.3
	material.scale_max = 0.8
	wind_particles.process_material = material

	add_child(wind_particles)
	has_wind_effect = true

func animate_crystal_effects(delta):
	"""Animate crystal spire effects"""
	if not crystal_glow:
		return

	var time = Time.get_ticks_msec() / 1000.0
	var pulse = sin(time * crystal_pulse_speed) * 0.3 + 0.7
	crystal_glow.modulate.a = pulse * 0.4

	# Color shifting
	var hue_shift = sin(time * crystal_pulse_speed * 0.5) * 0.1
	crystal_glow.modulate.b = 0.8 + hue_shift

func check_player_proximity():
	"""Monitor player for strategic feedback"""
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	var distance = global_position.distance_to(player.global_position)

	# Check if player passed this obstacle
	if not has_been_passed and player.global_position.x > global_position.x + width:
		has_been_passed = true
		emit_signal("obstacle_passed", self)

		# Award points based on spire type difficulty
		var score_bonus = get_score_bonus()
		GameManager.add_score(score_bonus)

	# Proximity warnings
	if distance < 150.0:
		emit_signal("obstacle_approached", self, distance)

func get_score_bonus() -> int:
	"""Get score bonus based on spire type and difficulty"""
	match spire_type:
		SpireType.SINGLE:
			return 5
		SpireType.CLUSTER:
			return 15
		SpireType.ARCH:
			return 8  # Easier due to gap
		SpireType.LEANING:
			return 12
		SpireType.CRYSTAL:
			return 20
	return 5

func _on_warning_area_entered(body):
	"""Handle player entering warning area"""
	if body.has_method("get_current_energy"):
		player_nearby = true

		# Visual feedback based on spire type
		apply_proximity_effect(true)

		# Audio feedback
		match spire_type:
			SpireType.CRYSTAL:
				AudioManager.play_sfx("crystal_chime", 0.6)
			_:
				AudioManager.play_sfx("rock_scrape", 0.4)

func _on_warning_area_exited(body):
	"""Handle player exiting warning area"""
	if body.has_method("get_current_energy"):
		player_nearby = false
		apply_proximity_effect(false)

func apply_proximity_effect(entering: bool):
	"""Apply visual effects when player approaches"""
	var target_modulate = Color(1.2, 1.2, 1.2, 1.0) if entering else Color(1.0, 1.0, 1.0, 1.0)

	if main_spire:
		var tween = create_tween()
		tween.tween_property(main_spire, "modulate", target_modulate, 0.3)

	# Special crystal effects
	if spire_type == SpireType.CRYSTAL and entering:
		if wind_particles:
			wind_particles.amount = 25  # Increase particle count

# Strategic navigation features
func get_safe_passage_points() -> Array[Vector2]:
	"""Get safe navigation points around this spire"""
	var safe_points = []

	match spire_type:
		SpireType.SINGLE, SpireType.LEANING:
			# Around the sides
			safe_points.append(global_position + Vector2(-width - 60, -height / 2.0))
			safe_points.append(global_position + Vector2(width + 60, -height / 2.0))
			# Above if not too tall
			if height < 350.0:
				safe_points.append(global_position + Vector2(0, -height - 50))

		SpireType.ARCH:
			# Through the arch gap
			safe_points.append(global_position + Vector2(0, -height * 0.6))
			# Around sides
			safe_points.append(global_position + Vector2(-width - 40, -height / 2.0))
			safe_points.append(global_position + Vector2(width + 40, -height / 2.0))

		SpireType.CLUSTER:
			# Requires wider clearance
			safe_points.append(global_position + Vector2(-width - 80, -height / 2.0))
			safe_points.append(global_position + Vector2(width + 80, -height / 2.0))

		SpireType.CRYSTAL:
			# Crystal creates wind effects, need more clearance
			safe_points.append(global_position + Vector2(-width - 70, -height / 2.0))
			safe_points.append(global_position + Vector2(width + 70, -height / 2.0))

	return safe_points

func get_wind_effect_strength() -> float:
	"""Get wind effect strength for environmental influence"""
	if spire_type == SpireType.CRYSTAL:
		return 30.0
	elif spire_type == SpireType.LEANING:
		return 10.0  # Slight wind deflection
	return 0.0

func get_difficulty_rating() -> float:
	"""Get difficulty rating for this spire"""
	var base_difficulty = height / 400.0

	match spire_type:
		SpireType.SINGLE:
			return base_difficulty
		SpireType.CLUSTER:
			return base_difficulty * 1.5
		SpireType.ARCH:
			return base_difficulty * 0.7  # Easier due to gap
		SpireType.LEANING:
			return base_difficulty * 1.2
		SpireType.CRYSTAL:
			return base_difficulty * 1.8

	return base_difficulty

func get_navigation_strategy() -> String:
	"""Get recommended navigation strategy"""
	match spire_type:
		SpireType.SINGLE:
			return "fly_around_sides"
		SpireType.CLUSTER:
			return "wide_approach"
		SpireType.ARCH:
			return "thread_gap"
		SpireType.LEANING:
			return "avoid_lean_side"
		SpireType.CRYSTAL:
			return "mind_wind_effects"

	return "navigate_carefully"

func cleanup():
	"""Clean up spire resources"""
	if wind_particles:
		wind_particles.emitting = false

	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.8)
	tween.tween_callback(queue_free)

func get_obstacle_info() -> Dictionary:
	"""Get detailed obstacle information"""
	return {
		"type": "spire",
		"spire_type": SpireType.keys()[spire_type],
		"height": height,
		"width": width,
		"position": global_position,
		"difficulty": get_difficulty_rating(),
		"strategy": get_navigation_strategy(),
		"passed": has_been_passed,
		"wind_effect": get_wind_effect_strength()
	}