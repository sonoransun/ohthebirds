extends Node

# Audio management for Sugar Glider Adventure
signal audio_settings_changed

# Audio players
@onready var music_player: AudioStreamPlayer
@onready var sfx_player: AudioStreamPlayer
@onready var ambient_player: AudioStreamPlayer

# Audio settings
var master_volume: float = 1.0
var music_volume: float = 0.7
var sfx_volume: float = 0.8
var ambient_volume: float = 0.5

var music_enabled: bool = true
var sfx_enabled: bool = true
var ambient_enabled: bool = true

# Current audio state
var current_music_track: String = ""
var is_music_playing: bool = false
var music_fade_tween: Tween

# Audio resource cache
var music_tracks: Dictionary = {}
var sound_effects: Dictionary = {}
var ambient_sounds: Dictionary = {}

# Volume bus indices (set up in Godot audio bus layout)
var master_bus_index: int = 0
var music_bus_index: int = 1
var sfx_bus_index: int = 2
var ambient_bus_index: int = 3

func _ready():
	setup_audio_players()
	setup_audio_buses()
	load_audio_resources()
	apply_audio_settings()

	print("AudioManager initialized")

func setup_audio_players():
	"""Create and configure audio stream players"""
	# Music player
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.bus = "Music"
	add_child(music_player)

	# SFX player
	sfx_player = AudioStreamPlayer.new()
	sfx_player.name = "SFXPlayer"
	sfx_player.bus = "SFX"
	add_child(sfx_player)

	# Ambient player
	ambient_player = AudioStreamPlayer.new()
	ambient_player.name = "AmbientPlayer"
	ambient_player.bus = "Ambient"
	ambient_player.stream = null
	add_child(ambient_player)

	# Create tween for smooth audio transitions
	music_fade_tween = Tween.new()
	add_child(music_fade_tween)

func setup_audio_buses():
	"""Set up audio bus configuration"""
	# Note: In a real project, you'd set up the audio buses in Godot's audio bus layout
	# This is just setting the indices for reference
	master_bus_index = AudioServer.get_bus_index("Master")

	# Create buses if they don't exist (in practice, these would be set up in the editor)
	if AudioServer.get_bus_count() <= 3:
		AudioServer.add_bus(1)  # Music
		AudioServer.add_bus(2)  # SFX
		AudioServer.add_bus(3)  # Ambient

		AudioServer.set_bus_name(1, "Music")
		AudioServer.set_bus_name(2, "SFX")
		AudioServer.set_bus_name(3, "Ambient")

	music_bus_index = AudioServer.get_bus_index("Music")
	sfx_bus_index = AudioServer.get_bus_index("SFX")
	ambient_bus_index = AudioServer.get_bus_index("Ambient")

func load_audio_resources():
	"""Load audio files into cache (placeholder - would load actual files)"""
	# Note: In a real implementation, you'd load actual audio files here
	# For now, we'll set up the structure for the audio system

	print("Audio resources loaded (placeholder)")

func play_music(track_name: String, fade_in: bool = true):
	"""Play a music track with optional fade in"""
	if not music_enabled:
		return

	# Stop current music if playing
	if is_music_playing and fade_in:
		fade_out_music()
		await get_tree().create_timer(0.5).timeout

	# Load and play new track
	var music_resource = get_music_resource(track_name)
	if music_resource:
		music_player.stream = music_resource
		current_music_track = track_name

		if fade_in:
			music_player.volume_db = -80
			music_player.play()
			fade_in_music()
		else:
			music_player.volume_db = linear_to_db(music_volume)
			music_player.play()

		is_music_playing = true
		print("Playing music: ", track_name)

func stop_music(fade_out: bool = true):
	"""Stop current music with optional fade out"""
	if not is_music_playing:
		return

	if fade_out:
		fade_out_music()
	else:
		music_player.stop()
		is_music_playing = false
		current_music_track = ""

func play_sfx(sound_name: String, volume_modifier: float = 1.0):
	"""Play a sound effect"""
	if not sfx_enabled:
		return

	var sound_resource = get_sfx_resource(sound_name)
	if sound_resource:
		# Create a new AudioStreamPlayer for this sound effect
		var temp_player = AudioStreamPlayer.new()
		temp_player.bus = "SFX"
		temp_player.stream = sound_resource
		temp_player.volume_db = linear_to_db(sfx_volume * volume_modifier)
		add_child(temp_player)

		temp_player.play()

		# Remove the player after the sound finishes
		temp_player.finished.connect(_on_temp_sfx_finished.bind(temp_player))

		print("Playing SFX: ", sound_name)

func play_ambient(sound_name: String, loop: bool = true):
	"""Play ambient sound"""
	if not ambient_enabled:
		return

	var ambient_resource = get_ambient_resource(sound_name)
	if ambient_resource:
		ambient_player.stream = ambient_resource
		ambient_player.volume_db = linear_to_db(ambient_volume)

		if loop and ambient_resource.has_method("set_loop"):
			ambient_resource.set_loop(true)

		ambient_player.play()
		print("Playing ambient: ", sound_name)

func stop_ambient(fade_out: bool = true):
	"""Stop ambient sound"""
	if fade_out:
		var tween = create_tween()
		tween.tween_property(ambient_player, "volume_db", -80, 1.0)
		tween.tween_callback(ambient_player.stop)
	else:
		ambient_player.stop()

func fade_in_music():
	"""Fade in the current music track"""
	var tween = create_tween()
	tween.tween_property(music_player, "volume_db", linear_to_db(music_volume), 1.0)

func fade_out_music():
	"""Fade out the current music track"""
	var tween = create_tween()
	tween.tween_property(music_player, "volume_db", -80, 1.0)
	tween.tween_callback(stop_music_immediate)

func stop_music_immediate():
	"""Stop music immediately without fade"""
	music_player.stop()
	is_music_playing = false
	current_music_track = ""

func set_master_volume(volume: float):
	"""Set master volume (0.0 to 1.0)"""
	master_volume = clamp(volume, 0.0, 1.0)
	apply_audio_settings()

func set_music_volume(volume: float):
	"""Set music volume (0.0 to 1.0)"""
	music_volume = clamp(volume, 0.0, 1.0)
	apply_audio_settings()

func set_sfx_volume(volume: float):
	"""Set SFX volume (0.0 to 1.0)"""
	sfx_volume = clamp(volume, 0.0, 1.0)
	apply_audio_settings()

func set_ambient_volume(volume: float):
	"""Set ambient volume (0.0 to 1.0)"""
	ambient_volume = clamp(volume, 0.0, 1.0)
	apply_audio_settings()

func set_music_enabled(enabled: bool):
	"""Enable or disable music"""
	music_enabled = enabled
	if not enabled and is_music_playing:
		stop_music()
	emit_signal("audio_settings_changed")

func set_sfx_enabled(enabled: bool):
	"""Enable or disable sound effects"""
	sfx_enabled = enabled
	emit_signal("audio_settings_changed")

func set_ambient_enabled(enabled: bool):
	"""Enable or disable ambient sounds"""
	ambient_enabled = enabled
	if not enabled:
		stop_ambient(false)
	emit_signal("audio_settings_changed")

func apply_audio_settings():
	"""Apply current audio settings to buses"""
	AudioServer.set_bus_volume_db(master_bus_index, linear_to_db(master_volume))
	AudioServer.set_bus_volume_db(music_bus_index, linear_to_db(music_volume))
	AudioServer.set_bus_volume_db(sfx_bus_index, linear_to_db(sfx_volume))
	AudioServer.set_bus_volume_db(ambient_bus_index, linear_to_db(ambient_volume))

func get_music_resource(track_name: String) -> AudioStream:
	"""Get music resource by name (placeholder)"""
	# In a real implementation, this would load from files or preloaded resources
	# For now, return null to avoid errors
	print("Loading music track: ", track_name, " (placeholder)")
	return null

func get_sfx_resource(sound_name: String) -> AudioStream:
	"""Get SFX resource by name (placeholder)"""
	# In a real implementation, this would load from files or preloaded resources
	print("Loading SFX: ", sound_name, " (placeholder)")
	return null

func get_ambient_resource(sound_name: String) -> AudioStream:
	"""Get ambient resource by name (placeholder)"""
	# In a real implementation, this would load from files or preloaded resources
	print("Loading ambient sound: ", sound_name, " (placeholder)")
	return null

func _on_temp_sfx_finished(player: AudioStreamPlayer):
	"""Clean up temporary SFX players"""
	player.queue_free()

# Convenience functions for common game sounds
func play_glide_sound():
	play_sfx("glide_whoosh", 0.6)

func play_collision_sound():
	play_sfx("collision_impact", 1.0)

func play_rocket_warning():
	play_sfx("rocket_warning", 0.8)

func play_rocket_launch():
	play_sfx("rocket_launch", 1.0)

func play_explosion():
	play_sfx("explosion", 0.9)

func play_score_sound():
	play_sfx("score_pickup", 0.7)

# Audio settings persistence
func save_audio_settings():
	"""Save audio settings to user preferences"""
	var settings = {
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"ambient_volume": ambient_volume,
		"music_enabled": music_enabled,
		"sfx_enabled": sfx_enabled,
		"ambient_enabled": ambient_enabled
	}

	var file = FileAccess.open("user://audio_settings.dat", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings))
		file.close()

func load_audio_settings():
	"""Load audio settings from user preferences"""
	if not FileAccess.file_exists("user://audio_settings.dat"):
		return

	var file = FileAccess.open("user://audio_settings.dat", FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()

		var json = JSON.new()
		var parse_result = json.parse(json_string)

		if parse_result == OK:
			var settings = json.data
			master_volume = settings.get("master_volume", 1.0)
			music_volume = settings.get("music_volume", 0.7)
			sfx_volume = settings.get("sfx_volume", 0.8)
			ambient_volume = settings.get("ambient_volume", 0.5)
			music_enabled = settings.get("music_enabled", true)
			sfx_enabled = settings.get("sfx_enabled", true)
			ambient_enabled = settings.get("ambient_enabled", true)

			apply_audio_settings()