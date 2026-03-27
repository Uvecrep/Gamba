extends Node
class_name AudioService

const MASTER_BUS: StringName = &"Master"

const SOUND_PATHS: Dictionary = {
	# UI
	&"ui_button_click": "res://assets/sounds/ui/button_click.ogg",
	&"ui_button_hover": "res://assets/sounds/ui/button_hover.ogg",
	&"ui_panel_open": "res://assets/sounds/ui/panel_open.ogg",
	&"ui_panel_close": "res://assets/sounds/ui/panel_close.ogg",
	&"ui_inventory_invalid": "res://assets/sounds/ui/inventory_invalid_action.ogg",
	&"ui_slot_hover_enter": "res://assets/sounds/ui/inventory_slot_hover_enter.ogg",
	&"ui_slot_hover_exit": "res://assets/sounds/ui/inventory_slot_hover_exit.ogg",
	&"ui_slot_select": "res://assets/sounds/ui/inventory_slot_select.ogg",
	&"ui_bestiary_unlock": "res://assets/sounds/ui/bestiary_unlock_notification.ogg",
	&"ui_bestiary_new": "res://assets/sounds/ui/bestiary_new_entry.ogg",
	&"ui_lootbox_tick": "res://assets/sounds/ui/lootbox_roll_ui_tick.ogg",
	&"ui_lootbox_reward": "res://assets/sounds/ui/lootbox_reward_cue.ogg",

	# Player
	&"player_interact_tree": "res://assets/sounds/player/player_interact_tree.ogg",
	&"player_interact_phone": "res://assets/sounds/player/player_interact_phone.ogg",
	&"player_interact_map": "res://assets/sounds/player/player_interact_map.ogg",
	&"player_interact_shop": "res://assets/sounds/player/player_interact_shop.ogg",
	&"player_lootbox_toss": "res://assets/sounds/player/lootbox_toss.ogg",
	&"player_sapling_toss": "res://assets/sounds/player/sapling_toss.ogg",
	&"player_damage_light": "res://assets/sounds/player/damage_taken_light.ogg",
	&"player_damage_medium": "res://assets/sounds/player/damage_taken_medium.ogg",
	&"player_damage_heavy": "res://assets/sounds/player/damage_taken_heavy.ogg",
	&"player_respawn": "res://assets/sounds/player/respawn.ogg",
	&"player_pickup_generic": "res://assets/sounds/player/generic_pickup.ogg",
	&"player_pickup_coin": "res://assets/sounds/player/pickup_coin.ogg",
	&"player_footstep_grass_1": "res://assets/sounds/player/footsteps_grass_variant_1.ogg",
	&"player_footstep_grass_2": "res://assets/sounds/player/footsteps_grass_variant_2.ogg",
	&"player_footstep_dirt": "res://assets/sounds/player/footsteps_dirt.ogg",

	# Combat
	&"combat_summon_death": "res://assets/sounds/combat/summon_death_generic.ogg",
	&"combat_summon_split": "res://assets/sounds/combat/summon_split_trigger_cue.ogg",

	# Enemy identity
	&"enemy_heavy_step": "res://assets/sounds/enemy/heavy_raider_step.ogg",
	&"enemy_ranged_shot": "res://assets/sounds/enemy/ranged_raider_shot_cue.ogg",
	&"enemy_healer_cast": "res://assets/sounds/enemy/healing_raider_cast_cue.ogg",
	&"enemy_trenchcoat_attack": "res://assets/sounds/enemy/trenchcoat_goblin_attack_cue.ogg",
	&"enemy_trenchcoat_death": "res://assets/sounds/enemy/trenchcoat_goblin_death_cue.ogg",
	&"enemy_goblin_attack": "res://assets/sounds/enemy/goblin_mini_attack_cue.ogg",
	&"enemy_goblin_death": "res://assets/sounds/enemy/goblin_mini_death_cue.ogg",

	# Summon themes
	&"summon_spawn_generic": "res://assets/sounds/summon/summon_spawn_generic.ogg",
	&"summon_spawn_rare": "res://assets/sounds/summon/summon_rare_accent.ogg",
	&"summon_chaos": "res://assets/sounds/summon/chaos_summon.ogg",
	&"summon_forest": "res://assets/sounds/summon/forest_summon.ogg",
	&"summon_elemental": "res://assets/sounds/summon/elemental_summon.ogg",
	&"summon_spirit": "res://assets/sounds/summon/spirit_summon.ogg",
	&"summon_greed": "res://assets/sounds/summon/greed_summon.ogg",

	# Lootbox
	&"lootbox_pickup": "res://assets/sounds/lootbox/lootbox_pickup.ogg",
	&"lootbox_open_start": "res://assets/sounds/lootbox/lootbox_open_start_cue.ogg",
	&"lootbox_settle": "res://assets/sounds/lootbox/lootbox_open_settle_cue.ogg",
	&"lootbox_reveal_common": "res://assets/sounds/lootbox/lootbox_common_reveal.ogg",
	&"lootbox_reveal_uncommon": "res://assets/sounds/lootbox/lootbox_uncommon_reveal.ogg",
	&"lootbox_reveal_rare": "res://assets/sounds/lootbox/lootbox_rare_reveal.ogg",
	&"lootbox_reveal_epic": "res://assets/sounds/lootbox/lootbox_epic_reveal.ogg",
	&"lootbox_reveal_special": "res://assets/sounds/lootbox/lootbox_special_reveal.ogg",

	# World and progression
	&"world_fruit_ready": "res://assets/sounds/world/fruit_ready_cue.ogg",
	&"world_crystal_interaction": "res://assets/sounds/world/crystal_interaction_cue.ogg",
	&"world_blood_purchase": "res://assets/sounds/world/blood_purchase_cue.ogg",
	&"world_boulder_harvest": "res://assets/sounds/world/boulder_harvest_cue.ogg",
	&"world_magnetized_pickup_loop": "res://assets/sounds/world/magnetized_pickup_loop.ogg",
	&"world_day_start": "res://assets/sounds/world/day_start_stinger.ogg",
	&"world_night_start": "res://assets/sounds/world/night_start_stinger.ogg",
	&"world_wave_coming": "res://assets/sounds/world/wave_coming.ogg",
	&"world_wave_mid": "res://assets/sounds/world/wave_mid_escalation_alert.ogg",
	&"world_wave_clear": "res://assets/sounds/world/wave_clear_cue.ogg",
	&"world_enemy_spawn": "res://assets/sounds/world/enemy_spawn_cue.ogg",
	&"world_house_under_attack": "res://assets/sounds/world/house_under_attack.ogg",
	&"world_game_over": "res://assets/sounds/world/game_over_stinger.ogg",

	# Ambience
	&"ambience_day": "res://assets/sounds/ambience/base_daytime_farm_ambience_loop.ogg",
	&"ambience_night": "res://assets/sounds/ambience/base_nighttime_farm_ambience_loop.ogg",
	&"ambience_combat_night": "res://assets/sounds/ambience/combat_night_tension_ambience.ogg",
	&"ambience_shop": "res://assets/sounds/ambience/shop_ambience_loop.ogg",

	# Music
	&"music_main_menu": "res://assets/sounds/music/main_menu_theme.ogg",
	&"music_day": "res://assets/sounds/music/day_exploration_theme.ogg",
	&"music_night_light": "res://assets/sounds/music/night_combat_theme_light_pressure.ogg",
	&"music_night_high": "res://assets/sounds/music/night_combat_theme_high_pressure.ogg",
	&"music_wave_peak": "res://assets/sounds/music/wave_peak_escalation.ogg",
	&"music_shop": "res://assets/sounds/music/shop_theme.ogg",
	&"music_game_over": "res://assets/sounds/music/game_over_theme.ogg",
}

var _stream_cache: Dictionary = {}
var _invalid_stream_keys: Dictionary = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_index: int = 0

var _music_player: AudioStreamPlayer
var _ambience_player: AudioStreamPlayer
var _sfx_loop_player: AudioStreamPlayer
var _footstep_player: AudioStreamPlayer
var _last_ui_tick_time_msec: int = 0
var _music_key: StringName = StringName()
var _ambience_key: StringName = StringName()
var _sfx_loop_key: StringName = StringName()
var _footstep_key: StringName = StringName()
var _sfx_key_by_player_id: Dictionary = {}
var _single_sfx_players: Dictionary = {}


func _ready() -> void:
	_music_player = _create_player(&"Music")
	add_child(_music_player)
	_ambience_player = _create_player(&"Ambience")
	add_child(_ambience_player)
	_sfx_loop_player = _create_player(&"SFX")
	add_child(_sfx_loop_player)
	_footstep_player = _create_player(&"SFX")
	add_child(_footstep_player)

	for i in range(20):
		var player: AudioStreamPlayer = _create_player(&"SFX")
		add_child(player)
		_sfx_players.append(player)


func play_ui(key: StringName, volume_db: float = 0.0) -> void:
	play_one_shot(key, volume_db, 1.0, &"UI")


func play_sfx(key: StringName, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	play_one_shot(key, volume_db, pitch_scale, &"SFX")


func play_sfx_if_not_playing(key: StringName, volume_db: float = 0.0, pitch_scale: float = 1.0, bus_name: StringName = &"SFX") -> bool:
	var stream: AudioStream = _get_stream(key)
	if stream == null:
		return false

	var player: AudioStreamPlayer = _single_sfx_players.get(key, null) as AudioStreamPlayer
	if player == null:
		player = _create_player(bus_name)
		add_child(player)
		_single_sfx_players[key] = player

	if player.playing:
		return false

	player.bus = _resolve_bus(bus_name)
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = maxf(pitch_scale, 0.01)
	player.play()
	return true


func play_player_footstep(key: StringName, volume_db: float = -12.0, pitch_scale: float = 1.0) -> void:
	var stream: AudioStream = _get_stream(key)
	if stream == null:
		return
	if _footstep_player == null:
		return

	_footstep_player.bus = _resolve_bus(&"SFX")
	_footstep_player.stop()
	_footstep_player.stream = stream
	_footstep_player.volume_db = volume_db
	_footstep_player.pitch_scale = maxf(pitch_scale, 0.01)
	_footstep_key = key
	_footstep_player.play()


func play_one_shot(key: StringName, volume_db: float = 0.0, pitch_scale: float = 1.0, bus_name: StringName = &"SFX") -> void:
	var stream: AudioStream = _get_stream(key)
	if stream == null:
		return

	if _sfx_players.is_empty():
		return

	var player: AudioStreamPlayer = _sfx_players[_sfx_index]
	_sfx_index = (_sfx_index + 1) % _sfx_players.size()
	player.bus = _resolve_bus(bus_name)
	player.stop()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = maxf(pitch_scale, 0.01)
	_sfx_key_by_player_id[player.get_instance_id()] = key
	player.play()


func play_music(key: StringName, volume_db: float = -6.0) -> void:
	var stream: AudioStream = _get_stream(key)
	if stream == null:
		return

	if _music_player.stream == stream and _music_player.playing:
		return

	_music_player.stream = stream
	_music_player.volume_db = volume_db
	_music_player.bus = _resolve_bus(&"Music")
	_music_key = key
	_music_player.play()


func stop_music() -> void:
	if _music_player != null:
		_music_player.stop()
	_music_key = StringName()


func play_ambience(key: StringName, volume_db: float = -12.0) -> void:
	var stream: AudioStream = _get_stream(key)
	if stream == null:
		return

	if _ambience_player.stream == stream and _ambience_player.playing:
		return

	_ambience_player.stream = stream
	_ambience_player.volume_db = volume_db
	_ambience_player.bus = _resolve_bus(&"Ambience")
	_ambience_key = key
	_ambience_player.play()


func stop_ambience() -> void:
	if _ambience_player != null:
		_ambience_player.stop()
	_ambience_key = StringName()


func start_sfx_loop(key: StringName, volume_db: float = 0.0) -> void:
	var stream: AudioStream = _get_stream(key)
	if stream == null:
		return
	if _sfx_loop_player.stream == stream and _sfx_loop_player.playing:
		return
	_sfx_loop_player.stream = stream
	_sfx_loop_player.volume_db = volume_db
	_sfx_loop_player.bus = _resolve_bus(&"SFX")
	_sfx_loop_key = key
	_sfx_loop_player.play()


func stop_sfx_loop() -> void:
	if _sfx_loop_player != null and _sfx_loop_player.playing:
		_sfx_loop_player.stop()
	_sfx_loop_key = StringName()


func get_currently_playing_sounds() -> Array[Dictionary]:
	var sounds: Array[Dictionary] = []

	if _music_player != null and _music_player.playing:
		sounds.append({
			"kind": "music",
			"key": String(_music_key),
			"bus": String(_music_player.bus),
			"volume_db": _music_player.volume_db,
			"pitch_scale": _music_player.pitch_scale,
		})

	if _ambience_player != null and _ambience_player.playing:
		sounds.append({
			"kind": "ambience",
			"key": String(_ambience_key),
			"bus": String(_ambience_player.bus),
			"volume_db": _ambience_player.volume_db,
			"pitch_scale": _ambience_player.pitch_scale,
		})

	if _sfx_loop_player != null and _sfx_loop_player.playing:
		sounds.append({
			"kind": "sfx_loop",
			"key": String(_sfx_loop_key),
			"bus": String(_sfx_loop_player.bus),
			"volume_db": _sfx_loop_player.volume_db,
			"pitch_scale": _sfx_loop_player.pitch_scale,
		})

	if _footstep_player != null and _footstep_player.playing:
		sounds.append({
			"kind": "footstep",
			"key": String(_footstep_key),
			"bus": String(_footstep_player.bus),
			"volume_db": _footstep_player.volume_db,
			"pitch_scale": _footstep_player.pitch_scale,
		})

	for single_key in _single_sfx_players.keys():
		var single_player: AudioStreamPlayer = _single_sfx_players[single_key] as AudioStreamPlayer
		if single_player == null or not single_player.playing:
			continue
		sounds.append({
			"kind": "sfx_single",
			"key": String(single_key),
			"bus": String(single_player.bus),
			"volume_db": single_player.volume_db,
			"pitch_scale": single_player.pitch_scale,
		})

	for player in _sfx_players:
		if player == null or not player.playing:
			continue
		var player_id: int = player.get_instance_id()
		var key: StringName = StringName()
		if _sfx_key_by_player_id.has(player_id):
			key = _sfx_key_by_player_id[player_id] as StringName
		sounds.append({
			"kind": "sfx",
			"key": String(key),
			"bus": String(player.bus),
			"volume_db": player.volume_db,
			"pitch_scale": player.pitch_scale,
		})

	return sounds


func play_lootbox_reveal_for_rarity(rarity_value: int) -> void:
	match rarity_value:
		0:
			play_sfx(&"lootbox_reveal_common")
		1:
			play_sfx(&"lootbox_reveal_uncommon")
		2:
			play_sfx(&"lootbox_reveal_rare")
		3:
			play_sfx(&"lootbox_reveal_epic")
		_:
			play_sfx(&"lootbox_reveal_special")


func play_ui_tick_throttled(min_interval_msec: int = 40) -> void:
	var now_msec: int = Time.get_ticks_msec()
	if now_msec - _last_ui_tick_time_msec < min_interval_msec:
		return
	_last_ui_tick_time_msec = now_msec
	play_ui(&"ui_lootbox_tick", -8.0)


func _get_stream(key: StringName) -> AudioStream:
	if _stream_cache.has(key):
		return _stream_cache[key] as AudioStream
	if _invalid_stream_keys.has(key):
		return null
	if not SOUND_PATHS.has(key):
		return null

	var path: String = String(SOUND_PATHS[key])
	if path.get_extension().to_lower() == "wav" and not _is_supported_wav_for_runtime(path):
		_invalid_stream_keys[key] = true
		push_warning("Audio: unsupported WAV encoding for key %s at %s. Expected PCM or IEEE float WAV." % [String(key), path])
		return null

	var loaded: AudioStream = load(path) as AudioStream
	if loaded == null:
		_invalid_stream_keys[key] = true
		push_warning("Audio: failed to load stream for key %s at %s" % [String(key), path])
		return null

	_stream_cache[key] = loaded
	return loaded


func _is_supported_wav_for_runtime(path: String) -> bool:
	var wav_file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if wav_file == null:
		return false

	if wav_file.get_length() < 16:
		return false

	wav_file.seek(12)
	while wav_file.get_position() + 8 <= wav_file.get_length():
		var chunk_id: PackedByteArray = wav_file.get_buffer(4)
		if chunk_id.size() < 4:
			return false
		var chunk_size: int = wav_file.get_32()
		var chunk_name: String = chunk_id.get_string_from_ascii()
		if chunk_name == "fmt ":
			if chunk_size < 2 or wav_file.get_position() + 2 > wav_file.get_length():
				return false
			var format_code: int = wav_file.get_16()
			return format_code == 1 or format_code == 3

		var skip_size: int = chunk_size
		if skip_size % 2 != 0:
			skip_size += 1
		var next_position: int = mini(wav_file.get_position() + skip_size, wav_file.get_length())
		wav_file.seek(next_position)

	return false


func _create_player(preferred_bus: StringName) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = _resolve_bus(preferred_bus)
	player.autoplay = false
	return player


func _resolve_bus(preferred_bus: StringName) -> StringName:
	if AudioServer.get_bus_index(String(preferred_bus)) >= 0:
		return preferred_bus
	return MASTER_BUS
