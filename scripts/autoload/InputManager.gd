extends Node

# Cross-platform input management for Sugar Glider Adventure
signal input_direction_changed(direction: Vector2)
signal input_active_changed(is_active: bool)
signal game_action_triggered(action: String)

# Input state
var input_direction: Vector2 = Vector2.ZERO
var is_input_active: bool = false
var raw_input_direction: Vector2 = Vector2.ZERO

# Input smoothing and filtering
var input_smoothing: float = 0.15
var input_deadzone: float = 0.1
var input_sensitivity: float = 1.0

# Touch/Mouse input
var touch_active: bool = false
var touch_start_position: Vector2 = Vector2.ZERO
var touch_current_position: Vector2 = Vector2.ZERO
var mouse_active: bool = false

# Platform-specific settings
var is_mobile: bool = false
var is_desktop: bool = true

func _ready():
	setup_platform_specific()
	set_process_input(true)
	set_process(true)

	print("InputManager initialized - Desktop: ", is_desktop, ", Mobile: ", is_mobile)

func _process(delta):
	update_input_smoothing(delta)
	process_keyboard_input()

func setup_platform_specific():
	"""Configure input settings based on platform"""
	var os_name = OS.get_name()

	if os_name in ["Android", "iOS"]:
		is_mobile = true
		is_desktop = false
		input_sensitivity = 1.2  # Slightly higher sensitivity for touch
	else:
		is_mobile = false
		is_desktop = true
		input_sensitivity = 1.0

func _input(event):
	"""Handle all input events"""
	if event is InputEventScreenTouch:
		handle_touch_input(event)
	elif event is InputEventScreenDrag:
		handle_touch_drag(event)
	elif event is InputEventMouseButton:
		handle_mouse_input(event)
	elif event is InputEventMouseMotion:
		handle_mouse_motion(event)
	elif event is InputEventKey:
		handle_key_input(event)

func process_keyboard_input():
	"""Process continuous keyboard input"""
	if not is_desktop:
		return

	var keyboard_direction = Vector2.ZERO

	# Get input vector from action map
	keyboard_direction = Input.get_vector("glide_left", "glide_right", "glide_up", "glide_down")

	# Apply deadzone and sensitivity
	if keyboard_direction.length() > input_deadzone:
		keyboard_direction = keyboard_direction.normalized() * input_sensitivity
		set_input_direction(keyboard_direction, true)
	else:
		if not touch_active and not mouse_active:
			set_input_direction(Vector2.ZERO, false)

func handle_touch_input(event: InputEventScreenTouch):
	"""Handle touch screen input"""
	if not is_mobile:
		return

	if event.pressed:
		touch_active = true
		touch_start_position = event.position
		touch_current_position = event.position
		update_touch_direction()
	else:
		touch_active = false
		set_input_direction(Vector2.ZERO, false)

func handle_touch_drag(event: InputEventScreenDrag):
	"""Handle touch drag for directional input"""
	if not is_mobile or not touch_active:
		return

	touch_current_position = event.position
	update_touch_direction()

func handle_mouse_input(event: InputEventMouseButton):
	"""Handle mouse button input"""
	if not is_desktop:
		return

	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			mouse_active = true
			var mouse_pos = get_viewport().get_mouse_position()
			var screen_center = get_viewport().get_visible_rect().size / 2.0
			var direction = (mouse_pos - screen_center).normalized()
			set_input_direction(direction * input_sensitivity, true)
		else:
			mouse_active = false
			if not Input.is_anything_pressed():
				set_input_direction(Vector2.ZERO, false)

func handle_mouse_motion(event: InputEventMouseMotion):
	"""Handle mouse movement for directional input"""
	if not is_desktop or not mouse_active:
		return

	var screen_center = get_viewport().get_visible_rect().size / 2.0
	var direction = (event.position - screen_center).normalized()
	set_input_direction(direction * input_sensitivity, true)

func handle_key_input(event: InputEventKey):
	"""Handle special key inputs"""
	if not event.pressed:
		return

	# Check for game action keys
	if event.is_action_pressed("pause_game"):
		emit_signal("game_action_triggered", "pause")
	elif event.is_action_pressed("restart_game"):
		emit_signal("game_action_triggered", "restart")

func update_touch_direction():
	"""Calculate direction from touch input"""
	var touch_delta = touch_current_position - touch_start_position
	var touch_distance = touch_delta.length()

	if touch_distance > 50.0:  # Minimum distance for directional input
		var direction = touch_delta.normalized() * input_sensitivity
		set_input_direction(direction, true)
	else:
		set_input_direction(Vector2.ZERO, true)  # Keep touch active but no direction

func set_input_direction(new_direction: Vector2, active: bool):
	"""Set the input direction with validation"""
	# Clamp direction magnitude
	if new_direction.length() > 1.0:
		new_direction = new_direction.normalized()

	raw_input_direction = new_direction
	var was_active = is_input_active
	is_input_active = active

	# Emit signals if values changed
	if raw_input_direction != input_direction:
		emit_signal("input_direction_changed", raw_input_direction)

	if was_active != is_input_active:
		emit_signal("input_active_changed", is_input_active)

func update_input_smoothing(delta):
	"""Apply smoothing to input direction"""
	if input_smoothing > 0.0:
		input_direction = input_direction.lerp(raw_input_direction, delta / input_smoothing)
	else:
		input_direction = raw_input_direction

func get_input_direction() -> Vector2:
	"""Get the current smoothed input direction"""
	return input_direction

func get_raw_input_direction() -> Vector2:
	"""Get the raw unsmoothed input direction"""
	return raw_input_direction

func is_input_active() -> bool:
	"""Check if input is currently active"""
	return is_input_active

func set_input_sensitivity(sensitivity: float):
	"""Set input sensitivity"""
	input_sensitivity = clamp(sensitivity, 0.1, 3.0)

func set_input_smoothing(smoothing: float):
	"""Set input smoothing amount"""
	input_smoothing = clamp(smoothing, 0.0, 1.0)

func get_input_strength() -> float:
	"""Get the strength/magnitude of current input"""
	return input_direction.length()

# Convenience functions for specific input directions
func is_moving_up() -> bool:
	return input_direction.y < -input_deadzone

func is_moving_down() -> bool:
	return input_direction.y > input_deadzone

func is_moving_left() -> bool:
	return input_direction.x < -input_deadzone

func is_moving_right() -> bool:
	return input_direction.x > input_deadzone

func get_horizontal_input() -> float:
	return input_direction.x

func get_vertical_input() -> float:
	return input_direction.y

# Debug functions
func get_debug_info() -> Dictionary:
	return {
		"input_direction": input_direction,
		"raw_direction": raw_input_direction,
		"is_active": is_input_active,
		"touch_active": touch_active,
		"mouse_active": mouse_active,
		"platform": "mobile" if is_mobile else "desktop"
	}