extends CharacterBody2D
class_name SugarGlider

# Signals for communication with other systems
signal energy_changed(new_energy: float, max_energy: float)
signal position_changed(new_position: Vector2)
signal collision_occurred(collision_body: Node)
signal animation_state_changed(new_state: AnimationState)

# Animation states
enum AnimationState {
	IDLE_GLIDE,      # Neutral gliding pose
	TURNING_LEFT,    # Banking left
	TURNING_RIGHT,   # Banking right
	DIVING,          # Steep downward angle
	CLIMBING,        # Upward movement (energy active)
	LOW_ENERGY,      # Tired/struggling animation
	STUNNED          # After collision
}

# Physics constants
const GRAVITY: float = 980.0  # Pixels per second squared
const MAX_FALL_SPEED: float = 800.0
const AIR_RESISTANCE: float = 0.98
const GLIDE_RESISTANCE: float = 0.995  # Less resistance when gliding

# Gliding mechanics
const GLIDE_LIFT_COEFFICIENT: float = 0.3  # How much speed converts to lift
const MIN_GLIDE_SPEED: float = 100.0  # Minimum horizontal speed for gliding
const MAX_GLIDE_SPEED: float = 600.0
const GLIDE_ANGLE_RANGE: float = 45.0  # Degrees up/down from horizontal

# Energy system
const MAX_ENERGY: float = 100.0
const ENERGY_DRAIN_RATE: float = 15.0  # Per second during active input
const ENERGY_REGEN_RATE: float = 8.0   # Per second during gliding
const LOW_ENERGY_THRESHOLD: float = 20.0

# Input and control
var input_direction: Vector2 = Vector2.ZERO
var is_input_active: bool = false
var input_force: float = 450.0

# Energy state
var current_energy: float = MAX_ENERGY
var energy_recovery_multiplier: float = 1.0

# Animation and visual state
var current_animation_state: AnimationState = AnimationState.IDLE_GLIDE
var visual_tilt: float = 0.0
var tilt_speed: float = 3.0
var max_tilt_angle: float = 30.0

# Collision and status effects
var is_stunned: bool = false
var stun_timer: float = 0.0
var collision_particles_active: bool = false

# Node references (will be set up when scene is loaded)
var animated_sprite: AnimatedSprite2D
var collision_shape: CollisionShape2D
var particle_effects: Node2D
var glide_trail: GPUParticles2D
var collision_sparks: GPUParticles2D
var glider_light: PointLight2D

# Environmental effects
var wind_effect: Vector2 = Vector2.ZERO
var in_thermal: bool = false

# Rocket evasion mechanics
var evasion_mode: bool = false
var evasion_timer: float = 0.0
var evasion_duration: float = 1.5
var evasion_speed_boost: float = 1.4
var evasion_energy_drain_multiplier: float = 2.0

func _ready():
	# Set up node references
	setup_node_references()

	# Connect to input manager
	InputManager.input_direction_changed.connect(_on_input_direction_changed)
	InputManager.input_active_changed.connect(_on_input_active_changed)

	# Set up initial state
	current_energy = MAX_ENERGY
	velocity = Vector2(MIN_GLIDE_SPEED, 0)  # Start with minimum gliding speed

	print("Sugar Glider initialized")

func setup_node_references():
	"""Set up references to child nodes"""
	animated_sprite = get_node_or_null("VisualLayer/SpriteContainer/AnimatedSprite2D")
	collision_shape = get_node_or_null("CollisionShape2D")
	particle_effects = get_node_or_null("VisualLayer/ParticleEffects")
	glide_trail = get_node_or_null("VisualLayer/ParticleEffects/GlideTrail")
	collision_sparks = get_node_or_null("VisualLayer/ParticleEffects/CollisionSparks")

	if animated_sprite:
		animated_sprite.play("idle_glide")

	# Evasion glow light (off by default, enabled during evasion mode)
	glider_light = PointLight2D.new()
	glider_light.color = Color(0.6, 0.9, 1.0)
	glider_light.energy = 0.0
	glider_light.texture_scale = 1.5
	glider_light.shadow_enabled = false
	add_child(glider_light)

	print("Node references set up - AnimatedSprite2D: ", animated_sprite != null)

func _physics_process(delta):
	if is_stunned:
		handle_stun_state(delta)
		return

	# Poll smoothed input each frame instead of relying on signal cache
	input_direction = InputManager.get_input_direction()
	is_input_active = InputManager.is_input_active()

	update_energy(delta)
	update_rocket_evasion(delta)
	calculate_glide_physics(delta)
	apply_environmental_effects(delta)
	handle_movement_and_collision(delta)
	update_visual_state(delta)

	# Emit position updates for other systems
	emit_signal("position_changed", global_position)

func _on_input_direction_changed(direction: Vector2):
	"""Handle input direction changes from InputManager"""
	input_direction = direction

func _on_input_active_changed(active: bool):
	"""Handle input active state changes from InputManager"""
	is_input_active = active


func calculate_glide_physics(delta):
	"""Calculate gliding physics and movement"""
	# Apply gravity - always pulling down
	velocity.y += GRAVITY * delta

	# Cap falling speed
	velocity.y = min(velocity.y, MAX_FALL_SPEED)

	# Handle gliding mechanics
	if is_gliding():
		apply_gliding_forces(delta)
	else:
		apply_free_fall_resistance(delta)

	# Player input for directional control
	if is_input_active and current_energy > 0:
		apply_player_input(delta)

func is_gliding() -> bool:
	"""Check if the glider is in gliding state"""
	return velocity.x >= MIN_GLIDE_SPEED and abs(velocity.y) < velocity.x

func apply_gliding_forces(delta):
	"""Apply forces during gliding"""
	# Convert horizontal speed to lift
	var lift_force = velocity.x * GLIDE_LIFT_COEFFICIENT
	velocity.y -= lift_force * delta

	# Apply glide resistance (maintains momentum better)
	velocity *= GLIDE_RESISTANCE

	# Ensure we don't gain infinite speed
	velocity.x = min(velocity.x, MAX_GLIDE_SPEED)

func apply_free_fall_resistance(delta):
	"""Apply air resistance during free fall"""
	velocity *= AIR_RESISTANCE


func apply_environmental_effects(delta):
	"""Apply environmental effects like wind and thermals"""
	# Wind resistance/assistance
	velocity += wind_effect * delta

	# Thermal updrafts provide energy recovery bonus
	if in_thermal:
		energy_recovery_multiplier = 1.5
		velocity.y -= 100.0 * delta  # Lift effect
	else:
		energy_recovery_multiplier = 1.0

func handle_movement_and_collision(delta):
	"""Handle physics movement and collision detection"""
	# Store previous velocity for collision response
	var previous_velocity = velocity

	# Move with Godot's physics system
	move_and_slide()

	# Check for collisions
	if get_slide_collision_count() > 0:
		for i in get_slide_collision_count():
			var collision = get_slide_collision(i)
			handle_collision(collision, previous_velocity)

func handle_collision(collision: KinematicCollision2D, previous_velocity: Vector2):
	"""Handle collision with obstacles"""
	var collision_body = collision.get_collider()

	# Emit collision signal
	emit_signal("collision_occurred", collision_body)

	# Determine collision response based on object type
	match collision_body.get_collision_layer():
		2:  # Obstacles (volcanoes, spires)
			handle_obstacle_collision(collision, previous_velocity)
		3:  # Rockets
			handle_rocket_collision(collision_body)
		5:  # Boundaries
			handle_boundary_collision(collision)

func handle_obstacle_collision(collision: KinematicCollision2D, previous_velocity: Vector2):
	"""Handle collision with static obstacles"""
	# Bounce effect with energy loss
	var collision_normal = collision.get_normal()
	velocity = previous_velocity.bounce(collision_normal) * 0.6

	# Energy penalty and temporary stun
	current_energy -= 25.0
	enter_stunned_state(1.0)  # 1 second stun

	# Visual/audio feedback
	create_collision_particles()
	AudioManager.play_collision_sound()

	print("Obstacle collision - Energy: ", current_energy)


func handle_boundary_collision(collision: KinematicCollision2D):
	"""Handle collision with world boundaries"""
	# Prevent going outside play area
	var normal = collision.get_normal()
	if normal.x != 0:  # Side boundaries
		velocity.x = -velocity.x * 0.5
	if normal.y != 0:  # Top/bottom boundaries
		velocity.y = -velocity.y * 0.3

func enter_stunned_state(duration: float):
	"""Enter stunned state after collision"""
	is_stunned = true
	is_input_active = false
	stun_timer = duration
	current_animation_state = AnimationState.STUNNED

func handle_stun_state(delta):
	"""Handle stunned state behavior"""
	stun_timer -= delta
	if stun_timer <= 0.0:
		is_stunned = false
		print("Recovered from stun")

	# Apply basic physics during stun
	velocity.y += GRAVITY * delta
	velocity *= AIR_RESISTANCE
	move_and_slide()

func update_visual_state(delta):
	"""Update animation state and visual effects"""
	update_animation_state()
	update_visual_tilt(delta)
	update_particle_effects()

func update_animation_state():
	"""Determine and set animation state"""
	var new_state = determine_animation_state()

	if new_state != current_animation_state:
		current_animation_state = new_state
		emit_signal("animation_state_changed", new_state)

		# Set animation if sprite node exists
		if animated_sprite:
			play_animation_for_state(new_state)

func determine_animation_state() -> AnimationState:
	"""Determine which animation state should be active"""
	# Stun state takes highest priority
	if is_stunned:
		return AnimationState.STUNNED

	# Energy-based states
	if current_energy <= LOW_ENERGY_THRESHOLD:
		return AnimationState.LOW_ENERGY

	if is_input_active:
		# Determine direction of movement
		if input_direction.y < -0.3:
			return AnimationState.CLIMBING
		elif input_direction.x < -0.5:
			return AnimationState.TURNING_LEFT
		elif input_direction.x > 0.5:
			return AnimationState.TURNING_RIGHT

	# Velocity-based states
	if velocity.y > 300:
		return AnimationState.DIVING

	return AnimationState.IDLE_GLIDE

func play_animation_for_state(state: AnimationState):
	"""Play the appropriate animation for the given state"""
	if not animated_sprite:
		return

	match state:
		AnimationState.IDLE_GLIDE:
			animated_sprite.play("idle_glide")
		AnimationState.TURNING_LEFT:
			animated_sprite.play("turn_left")
		AnimationState.TURNING_RIGHT:
			animated_sprite.play("turn_right")
		AnimationState.DIVING:
			animated_sprite.play("diving")
		AnimationState.CLIMBING:
			animated_sprite.play("climbing")
		AnimationState.LOW_ENERGY:
			animated_sprite.play("low_energy")
		AnimationState.STUNNED:
			animated_sprite.play("stunned")

func update_visual_tilt(delta):
	"""Update visual tilt based on movement"""
	var target_tilt = 0.0

	if is_input_active:
		target_tilt = input_direction.x * max_tilt_angle

	visual_tilt = lerp(visual_tilt, target_tilt, tilt_speed * delta)

	# Apply tilt to visual representation
	if animated_sprite:
		animated_sprite.rotation_degrees = visual_tilt

func update_particle_effects():
	"""Update particle effects based on state"""
	if not particle_effects:
		return

	# Glide trail effect
	if glide_trail:
		glide_trail.emitting = is_gliding() and velocity.length() > 200.0

	# Collision sparks
	if collision_sparks:
		if collision_particles_active:
			collision_sparks.emitting = true
			collision_particles_active = false

func create_collision_particles():
	"""Create particle effect for collision"""
	collision_particles_active = true

# Environmental effect setters (called by environment manager)
func set_wind_effect(wind_velocity: Vector2):
	"""Set current wind effect"""
	wind_effect = wind_velocity

func set_in_thermal(thermal_state: bool):
	"""Set whether the glider is in a thermal updraft"""
	in_thermal = thermal_state

# Getter functions for external systems
func get_current_energy() -> float:
	return current_energy

func get_energy_percentage() -> float:
	return current_energy / MAX_ENERGY

func is_low_energy() -> bool:
	return current_energy <= LOW_ENERGY_THRESHOLD

func get_gliding_speed() -> float:
	return velocity.x if is_gliding() else 0.0

func get_current_state() -> AnimationState:
	return current_animation_state

# Debug information
func update_rocket_evasion(delta):
	"""Update rocket evasion mechanics"""
	if evasion_mode:
		evasion_timer -= delta
		if evasion_timer <= 0.0:
			exit_evasion_mode()

	# Auto-detect nearby rockets and enter evasion mode
	if not evasion_mode and detect_nearby_rockets():
		enter_evasion_mode()

func detect_nearby_rockets() -> bool:
	"""Detect rockets in the immediate vicinity"""
	var rockets = get_tree().get_nodes_in_group("rockets")
	var danger_threshold = 150.0

	for rocket in rockets:
		if is_instance_valid(rocket):
			var distance = global_position.distance_to(rocket.global_position)
			if distance < danger_threshold:
				# Check if rocket is heading towards player
				var rocket_velocity = rocket.linear_velocity if rocket.has_method("linear_velocity") else Vector2.ZERO
				var to_player = (global_position - rocket.global_position).normalized()
				var rocket_direction = rocket_velocity.normalized()

				# If rocket is generally moving towards player
				if rocket_direction.dot(to_player) > 0.5:
					return true

	return false

func enter_evasion_mode():
	"""Enter enhanced evasion mode with speed boost"""
	evasion_mode = true
	evasion_timer = evasion_duration

	# Visual feedback
	if animated_sprite:
		var tween = create_tween()
		tween.tween_property(animated_sprite, "modulate", Color.CYAN, 0.2)

	if glider_light:
		var light_tween = create_tween()
		light_tween.tween_property(glider_light, "energy", 1.2, 0.2)

	# Audio feedback
	AudioManager.play_sfx("evasion_mode", 0.8)

	print("Sugar glider entering evasion mode!")

func exit_evasion_mode():
	"""Exit evasion mode and return to normal"""
	evasion_mode = false

	# Reset visual effects
	if animated_sprite:
		var tween = create_tween()
		tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.5)

	if glider_light:
		var light_tween = create_tween()
		light_tween.tween_property(glider_light, "energy", 0.0, 0.5)

	print("Sugar glider exiting evasion mode")

func apply_player_input(delta):
	"""Apply player input to movement (enhanced version with evasion)"""
	var effective_input_force = input_force

	# Evasion mode bonuses
	if evasion_mode:
		effective_input_force *= evasion_speed_boost
		# Slightly different physics during evasion
		velocity *= 1.05  # Momentum conservation bonus

	# Reduce force when energy is low
	if current_energy < LOW_ENERGY_THRESHOLD:
		effective_input_force *= 0.5

	# Apply input in desired direction
	velocity += input_direction * effective_input_force * delta

	# Enhanced speed limits during evasion
	var max_speed_x = MAX_GLIDE_SPEED * (evasion_speed_boost if evasion_mode else 1.0)
	var max_speed_y = 400.0 * (evasion_speed_boost if evasion_mode else 1.0)

	# Clamp x to [0, max] — left input decelerates but never reverses in this auto-scroller
	velocity.x = clamp(velocity.x, 0, max_speed_x)
	velocity.y = clamp(velocity.y, -max_speed_y, MAX_FALL_SPEED)

func update_energy(delta):
	"""Update energy system (enhanced with evasion costs)"""
	if is_input_active and not is_stunned:
		# Drain energy during active control
		var drain_multiplier = 1.0

		# More energy drain for upward movement
		if input_direction.y < 0:
			drain_multiplier = 1.5

		# Less drain for gliding with wind
		if is_gliding():
			drain_multiplier = 0.7

		# Evasion mode increases energy drain
		if evasion_mode:
			drain_multiplier *= evasion_energy_drain_multiplier

		current_energy -= ENERGY_DRAIN_RATE * drain_multiplier * delta * GameManager.get_energy_drain_multiplier()
	else:
		# Recover energy during passive gliding
		var recovery_rate = ENERGY_REGEN_RATE * energy_recovery_multiplier

		# Slower recovery during evasion mode
		if evasion_mode:
			recovery_rate *= 0.5

		current_energy += recovery_rate * delta

	# Clamp energy values
	current_energy = clamp(current_energy, 0.0, MAX_ENERGY)

	# Update UI
	emit_signal("energy_changed", current_energy, MAX_ENERGY)

# Enhanced collision handling for rockets
func handle_rocket_collision(rocket_body: Node):
	"""Handle collision with rockets - enhanced with evasion mechanics"""
	if evasion_mode:
		# Small chance to survive rocket collision during evasion mode
		if randf() < 0.1:  # 10% survival chance
			print("Miraculous evasion! Rocket grazed the sugar glider!")

			# Heavy energy penalty instead of death
			current_energy -= 50.0
			enter_stunned_state(2.0)

			# Award massive bonus for survival
			GameManager.add_score(500)
			return

	print("Rocket collision - Game Over!")
	GameManager.end_game()

func get_debug_info() -> Dictionary:
	return {
		"position": global_position,
		"velocity": velocity,
		"energy": current_energy,
		"is_gliding": is_gliding(),
		"animation_state": AnimationState.keys()[current_animation_state],
		"input_direction": input_direction,
		"is_input_active": is_input_active,
		"is_stunned": is_stunned,
		"evasion_mode": evasion_mode
	}