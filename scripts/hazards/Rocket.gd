extends RigidBody2D
class_name Rocket

# Dynamic rocket projectile with multiple behavior types
signal rocket_exploded(position: Vector2, damage_radius: float)
signal rocket_near_miss(rocket: Rocket, distance: float)
signal rocket_destroyed(rocket: Rocket)

# Rocket types with different behaviors
enum RocketType {
	BASIC,           # Straight trajectory with gravity
	FAST,            # High speed, low tracking
	TRACKING,        # Mild homing behavior
	CLUSTER,         # Splits into smaller rockets
	EXPLOSIVE,       # Large blast radius
	SMOKE_TRAIL,     # Creates smoke screen
	PENETRATOR,      # Punches through obstacles
	SPIRAL           # Corkscrew flight pattern
}

# Rocket configuration
@export var rocket_type: RocketType = RocketType.BASIC
@export var launch_speed: float = 400.0
@export var max_speed: float = 600.0
@export var tracking_strength: float = 0.0
@export var lifetime: float = 8.0
@export var explosion_radius: float = 80.0

# Physics and movement
var initial_velocity: Vector2
var target_position: Vector2
var has_target: bool = false
var launch_time: float
var is_armed: bool = false
var arm_delay: float = 0.5

# Tracking behavior
var player_reference: SugarGlider
var tracking_update_rate: float = 0.1
var tracking_timer: float = 0.0

# Visual and audio components
var rocket_sprite: Sprite2D
var trail_particles: GPUParticles2D
var warning_light: Sprite2D
var engine_sound: AudioStreamPlayer2D
var explosion_prefab: PackedScene

# Rocket state
var current_speed: float
var spiral_angle: float = 0.0
var spiral_radius: float = 20.0
var cluster_split_triggered: bool = false

# Environmental effects
var smoke_trail_nodes: Array[Node2D] = []

func _ready():
	launch_time = Time.get_ticks_msec() / 1000.0
	current_speed = launch_speed

	# Set up physics
	gravity_scale = 0.3  # Affected by gravity but not too much
	collision_layer = 4  # Rocket layer
	collision_mask = 31  # Can hit player, obstacles, world bounds

	# Find player reference
	player_reference = get_tree().get_first_node_in_group("player")

	setup_visual_components()
	setup_audio()
	configure_rocket_type()

	# Arm after delay for safety
	get_tree().create_timer(arm_delay).timeout.connect(_on_arm_timer)

	print("Rocket launched: ", RocketType.keys()[rocket_type])

func _physics_process(delta):
	if not is_armed:
		return

	var age = Time.get_ticks_msec() / 1000.0 - launch_time

	# Check lifetime
	if age > lifetime:
		explode()
		return

	# Update movement based on rocket type
	update_rocket_behavior(delta)
	update_visual_effects(delta)
	check_proximity_to_player()

func setup_visual_components():
	"""Create visual components for the rocket"""
	# Main rocket sprite (simple colored rectangle for now)
	rocket_sprite = Sprite2D.new()
	var texture = ImageTexture.new()
	var image = Image.create(16, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color.ORANGE_RED)
	texture.set_image(image)
	rocket_sprite.texture = texture
	rocket_sprite.rotation = PI / 2.0  # Point upward initially
	add_child(rocket_sprite)

	# Warning light for tracking rockets
	if rocket_type == RocketType.TRACKING:
		warning_light = Sprite2D.new()
		var warning_texture = ImageTexture.new()
		var warning_image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
		warning_image.fill(Color.YELLOW)
		warning_texture.set_image(warning_image)
		warning_light.texture = warning_texture
		warning_light.position = Vector2(0, -10)
		add_child(warning_light)

	# Trail particles
	setup_trail_particles()

func setup_trail_particles():
	"""Set up rocket trail particle effects"""
	trail_particles = GPUParticles2D.new()
	trail_particles.position = Vector2(0, 8)  # Behind the rocket
	trail_particles.emitting = true
	trail_particles.amount = 30
	trail_particles.lifetime = 1.5

	# Configure trail based on rocket type
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, 1, 0)  # Downward relative to rocket
	material.initial_velocity_min = 50.0
	material.initial_velocity_max = 100.0
	material.gravity = Vector3(0, 50, 0)
	material.scale_min = 0.3
	material.scale_max = 0.8

	# Customize trail color based on rocket type
	match rocket_type:
		RocketType.FAST:
			material.color = Color.CYAN
		RocketType.TRACKING:
			material.color = Color.YELLOW
		RocketType.EXPLOSIVE:
			material.color = Color.ORANGE
		_:
			material.color = Color.WHITE

	trail_particles.process_material = material
	add_child(trail_particles)

func setup_audio():
	"""Set up rocket engine sound"""
	engine_sound = AudioStreamPlayer2D.new()
	engine_sound.bus = "SFX"
	engine_sound.volume_db = -10
	# Would set actual engine sound here
	add_child(engine_sound)

func configure_rocket_type():
	"""Configure specific behavior based on rocket type"""
	match rocket_type:
		RocketType.BASIC:
			# Standard rocket - no special behavior
			pass

		RocketType.FAST:
			launch_speed = 600.0
			max_speed = 800.0
			lifetime = 5.0
			explosion_radius = 60.0

		RocketType.TRACKING:
			tracking_strength = 0.4
			tracking_update_rate = 0.05
			lifetime = 10.0
			if warning_light:
				animate_warning_light()

		RocketType.CLUSTER:
			explosion_radius = 120.0
			lifetime = 6.0

		RocketType.EXPLOSIVE:
			explosion_radius = 150.0
			launch_speed = 300.0
			max_speed = 400.0

		RocketType.SMOKE_TRAIL:
			setup_smoke_trail()

		RocketType.PENETRATOR:
			# Can punch through thin obstacles
			collision_mask = 17  # Only player and world bounds

		RocketType.SPIRAL:
			spiral_radius = 30.0

func animate_warning_light():
	"""Animate warning light for tracking rockets"""
	if not warning_light:
		return

	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(warning_light, "modulate", Color.TRANSPARENT, 0.3)
	tween.tween_property(warning_light, "modulate", Color.YELLOW, 0.3)

func setup_smoke_trail():
	"""Set up smoke trail effect"""
	# Enhanced smoke particles for smoke trail rockets
	if trail_particles:
		trail_particles.amount = 60
		trail_particles.lifetime = 3.0
		var material = trail_particles.process_material as ParticleProcessMaterial
		if material:
			material.color = Color.GRAY
			material.initial_velocity_min = 20.0
			material.initial_velocity_max = 40.0

func update_rocket_behavior(delta):
	"""Update rocket movement based on type"""
	var direction = Vector2.UP  # Default upward movement

	match rocket_type:
		RocketType.BASIC:
			direction = initial_velocity.normalized()

		RocketType.FAST:
			direction = initial_velocity.normalized()
			current_speed = min(current_speed + 100.0 * delta, max_speed)

		RocketType.TRACKING:
			direction = update_tracking_behavior(delta)

		RocketType.SPIRAL:
			direction = update_spiral_behavior(delta)

		_:
			direction = initial_velocity.normalized()

	# Apply movement
	linear_velocity = direction * current_speed

	# Update rotation to match direction
	if rocket_sprite:
		rocket_sprite.rotation = direction.angle() + PI / 2.0

	# Update trail direction
	if trail_particles:
		var trail_material = trail_particles.process_material as ParticleProcessMaterial
		if trail_material:
			trail_material.direction = Vector3(-direction.x, -direction.y, 0)

func update_tracking_behavior(delta) -> Vector2:
	"""Update tracking rocket behavior"""
	tracking_timer += delta

	if tracking_timer >= tracking_update_rate and player_reference:
		tracking_timer = 0.0

		# Calculate direction to player
		var to_player = (player_reference.global_position - global_position).normalized()
		var current_direction = linear_velocity.normalized()

		# Blend current direction with player direction
		var new_direction = current_direction.lerp(to_player, tracking_strength * delta)
		return new_direction.normalized()

	return linear_velocity.normalized()

func update_spiral_behavior(delta) -> Vector2:
	"""Update spiral rocket behavior"""
	spiral_angle += delta * 5.0  # Spiral speed

	# Base direction (upward)
	var base_direction = initial_velocity.normalized()

	# Add spiral offset
	var spiral_offset = Vector2(
		cos(spiral_angle) * spiral_radius,
		sin(spiral_angle) * spiral_radius
	)

	# Calculate final direction
	var target_pos = global_position + base_direction * 100.0 + spiral_offset
	return (target_pos - global_position).normalized()

func update_visual_effects(delta):
	"""Update visual effects based on rocket state"""
	# Pulse effect for explosive rockets
	if rocket_type == RocketType.EXPLOSIVE:
		var pulse = sin(Time.get_ticks_msec() / 100.0) * 0.2 + 0.8
		rocket_sprite.modulate = Color(1.0, pulse, pulse, 1.0)

	# Smoke trail creation
	if rocket_type == RocketType.SMOKE_TRAIL:
		create_smoke_puff()

func create_smoke_puff():
	"""Create smoke puff for smoke trail rockets"""
	# Periodically create smoke cloud nodes
	if randf() < 0.1:  # 10% chance per frame
		var smoke_puff = create_smoke_cloud(global_position)
		if smoke_puff:
			get_parent().add_child(smoke_puff)
			smoke_trail_nodes.append(smoke_puff)

func create_smoke_cloud(position: Vector2) -> Node2D:
	"""Create a smoke cloud node"""
	var smoke = Node2D.new()
	smoke.position = position

	# Visual representation
	var smoke_sprite = Sprite2D.new()
	var texture = ImageTexture.new()
	var image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.5, 0.5, 0.5, 0.6))
	texture.set_image(image)
	smoke_sprite.texture = texture
	smoke.add_child(smoke_sprite)

	# Fade out and expand
	var tween = create_tween()
	tween.parallel().tween_property(smoke_sprite, "modulate", Color.TRANSPARENT, 3.0)
	tween.parallel().tween_property(smoke_sprite, "scale", Vector2(2.0, 2.0), 3.0)
	tween.tween_callback(smoke.queue_free)

	return smoke

func check_proximity_to_player():
	"""Check for near misses and proximity warnings"""
	if not player_reference:
		return

	var distance = global_position.distance_to(player_reference.global_position)

	# Near miss detection
	if distance < 100.0 and distance > explosion_radius:
		emit_signal("rocket_near_miss", self, distance)

		# Award style points for close dodging
		if distance < 60.0:
			GameManager.add_score(5)  # Close dodge bonus

func _on_arm_timer():
	"""Arm the rocket for collision detection"""
	is_armed = true

	# Set up collision detection
	var collision_shape = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 8.0
	collision_shape.shape = shape
	add_child(collision_shape)

	# Connect collision signal
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	"""Handle collision with other bodies"""
	if not is_armed:
		return

	# Check what we hit
	if body.has_method("get_current_energy"):  # Hit player
		handle_player_collision(body)
	elif body.get_collision_layer() == 2:  # Hit obstacle
		handle_obstacle_collision(body)
	else:
		# Hit world boundary or other
		explode()

func handle_player_collision(player: Node):
	"""Handle direct hit on player"""
	print("Rocket hit player!")

	# Trigger game over
	GameManager.end_game()

	# Create explosion at impact point
	explode()

func handle_obstacle_collision(obstacle: Node):
	"""Handle collision with obstacles"""
	if rocket_type == RocketType.PENETRATOR:
		# Penetrator rockets punch through obstacles
		print("Penetrator rocket punched through obstacle")
		return

	# Normal rockets explode on obstacle hit
	explode()

func explode():
	"""Trigger rocket explosion"""
	print("Rocket exploded at ", global_position)

	# Emit explosion signal
	emit_signal("rocket_exploded", global_position, explosion_radius)

	# Handle cluster rocket splitting
	if rocket_type == RocketType.CLUSTER and not cluster_split_triggered:
		create_cluster_rockets()

	# Create explosion visual effect
	create_explosion_effect()

	# Audio feedback
	AudioManager.play_explosion()

	# Screen shake for nearby explosions
	if player_reference:
		var distance_to_player = global_position.distance_to(player_reference.global_position)
		if distance_to_player < 200.0:
			trigger_screen_shake(distance_to_player)

	# Clean up
	cleanup()

func create_cluster_rockets():
	"""Create smaller rockets from cluster explosion"""
	cluster_split_triggered = true
	var cluster_count = 3

	for i in cluster_count:
		var angle = (PI * 2.0 / cluster_count) * i
		var direction = Vector2(cos(angle), sin(angle))

		# Create smaller rocket
		var cluster_rocket = preload("res://scenes/hazards/Rocket.tscn").instantiate()
		cluster_rocket.global_position = global_position + direction * 20.0
		cluster_rocket.rocket_type = RocketType.BASIC
		cluster_rocket.launch_speed = 200.0
		cluster_rocket.explosion_radius = 40.0
		cluster_rocket.initial_velocity = direction * 200.0

		get_parent().add_child(cluster_rocket)

func create_explosion_effect():
	"""Create visual explosion effect"""
	var explosion = Node2D.new()
	explosion.position = global_position

	# Explosion sprite
	var explosion_sprite = Sprite2D.new()
	var texture = ImageTexture.new()
	var image = Image.create(int(explosion_radius * 2), int(explosion_radius * 2), false, Image.FORMAT_RGBA8)
	image.fill(Color.ORANGE)
	texture.set_image(image)
	explosion_sprite.texture = texture
	explosion.add_child(explosion_sprite)

	get_parent().add_child(explosion)

	# Animate explosion
	var tween = create_tween()
	tween.parallel().tween_property(explosion_sprite, "scale", Vector2(1.5, 1.5), 0.3)
	tween.parallel().tween_property(explosion_sprite, "modulate", Color.TRANSPARENT, 0.5)
	tween.tween_callback(explosion.queue_free)

func trigger_screen_shake(distance: float):
	"""Trigger screen shake effect based on distance"""
	var shake_strength = clamp(10.0 - (distance / 20.0), 2.0, 10.0)
	# Would trigger screen shake here - implement in main scene

func cleanup():
	"""Clean up rocket resources"""
	# Stop particles
	if trail_particles:
		trail_particles.emitting = false

	# Clean up smoke trail
	for smoke_node in smoke_trail_nodes:
		if is_instance_valid(smoke_node):
			smoke_node.queue_free()

	# Signal destruction
	emit_signal("rocket_destroyed", self)

	# Remove after brief delay for explosion effect
	get_tree().create_timer(0.1).timeout.connect(queue_free)

# Public interface functions
func set_target(target_pos: Vector2):
	"""Set target position for tracking rockets"""
	target_position = target_pos
	has_target = true

func set_initial_velocity(velocity: Vector2):
	"""Set initial launch velocity"""
	initial_velocity = velocity
	linear_velocity = velocity

func get_danger_radius() -> float:
	"""Get the danger radius for this rocket"""
	return explosion_radius + 20.0  # Safety margin

func get_rocket_info() -> Dictionary:
	"""Get rocket information for debugging"""
	return {
		"type": RocketType.keys()[rocket_type],
		"position": global_position,
		"velocity": linear_velocity,
		"armed": is_armed,
		"age": Time.get_ticks_msec() / 1000.0 - launch_time,
		"explosion_radius": explosion_radius
	}