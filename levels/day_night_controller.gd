class_name DayNightController
extends Node

signal day_started(day_number: int)
signal night_started(night_number: int)

# Config — set by main.gd before add_child() so _ready sees them,
# or call initialize() after changing them.
var enable_day_night_cycle: bool = true
var day_duration_seconds: float = 60.0
var night_duration_seconds: float = 36.0
var first_night_starts_immediately: bool = false
var night_waves_per_cycle: int = 3
var night_wave_base_size: int = 6
var night_wave_size_growth_per_night: int = 2
var night_wave_spawn_scale: float = 0.9
var night_wave_spacing_seconds: float = 10.0
var day_night_transition_seconds: float = 1.8
var day_overlay_color: Color = Color(0.06, 0.09, 0.15, 0.0)
var night_overlay_color: Color = Color(0.06, 0.09, 0.15, 0.48)
var day_label_color: Color = Color(0.94, 0.96, 1.0, 1.0)
var night_label_color: Color = Color(0.65, 0.78, 1.0, 1.0)

var _enemy_spawner: EnemySpawner = null
var _label: Label = null
var _overlay: ColorRect = null

var _phase_timer: Timer = null
var _wave_timer: Timer = null
var _overlay_tween: Tween = null

var _is_night_phase: bool = false
var _night_index: int = 0
var _waves_spawned_this_night: int = 0
var _stopped: bool = false

var soul_tower_packed_scene : PackedScene = preload("res://entities/crystal/soul_tower.tscn")
var soul_tower : SoulTower
var soul_tower_spawn_center : Vector2 = Vector2(32,-32) #hardcoded to house rn
var soul_tower_spawn_min_dist_from_center : float = 2500
var soul_tower_spawn_max_dist_from_center : float = 4000


func setup(enemy_spawner: EnemySpawner, label: Label, overlay: ColorRect) -> void:
	_enemy_spawner = enemy_spawner
	_label = label
	_overlay = overlay


func initialize() -> void:
	_stopped = false

	if not enable_day_night_cycle:
		if _label != null:
			_label.visible = false
		_apply_visual_state(false, true)
		_set_tree_growth_paused(false)
		if is_instance_valid(_enemy_spawner):
			_enemy_spawner.start_spawning()
		return

	_ensure_timers()

	if first_night_starts_immediately:
		_start_night_phase()
	else:
		_start_day_phase()


func is_night_time() -> bool:
	return enable_day_night_cycle and _is_night_phase


func stop() -> void:
	_stopped = true
	if is_instance_valid(_phase_timer):
		_phase_timer.stop()
	if is_instance_valid(_wave_timer):
		_wave_timer.stop()
	if is_instance_valid(_overlay_tween):
		_overlay_tween.kill()


# ── Timers ──────────────────────────────────────────────────────────────────

func _ensure_timers() -> void:
	if _phase_timer == null:
		_phase_timer = Timer.new()
		_phase_timer.name = "DayNightPhaseTimer"
		_phase_timer.one_shot = true
		_phase_timer.timeout.connect(_on_phase_timer_timeout)
		add_child(_phase_timer)

	if _wave_timer == null:
		_wave_timer = Timer.new()
		_wave_timer.name = "NightWaveTimer"
		_wave_timer.one_shot = true
		_wave_timer.timeout.connect(_on_wave_timer_timeout)
		add_child(_wave_timer)

	if _label != null:
		_label.visible = true


func _start_phase_timer(duration_seconds: float) -> void:
	if _phase_timer == null or not is_instance_valid(_phase_timer):
		return
	if not _phase_timer.is_inside_tree():
		return

	_phase_timer.start(maxf(duration_seconds, 0.1))


# ── Phase transitions ────────────────────────────────────────────────────────

func _start_day_phase() -> void:
	_is_night_phase = false
	_waves_spawned_this_night = 0

	if is_instance_valid(_wave_timer):
		_wave_timer.stop()

	if is_instance_valid(_enemy_spawner):
		_enemy_spawner.stop_spawning()

	_place_soul_tower()

	_set_tree_growth_paused(false)
	_apply_visual_state(false, false)
	_update_label("Day")
	Audio.play_sfx(&"world_day_start", -3.0)
	Audio.play_music(&"music_day", -8.0)
	Audio.play_ambience(&"ambience_day", -13.0)
	day_started.emit(maxi(_night_index + 1, 1))
	_start_phase_timer(day_duration_seconds)


func _start_night_phase() -> void:
	_is_night_phase = true
	_night_index += 1
	_waves_spawned_this_night = 0

	if is_instance_valid(_enemy_spawner):
		_enemy_spawner.stop_spawning()

	_set_tree_growth_paused(true)
	_apply_visual_state(true, false)
	_update_label("Night %d" % _night_index)
	Audio.play_sfx(&"world_night_start", -3.0)
	Audio.play_music(&"music_night_light", -8.0)
	Audio.play_ambience(&"ambience_night", -13.0)
	night_started.emit(_night_index)
	_spawn_next_wave()
	_start_phase_timer(night_duration_seconds)


# ── World effects ────────────────────────────────────────────────────────────

func _set_tree_growth_paused(is_paused: bool) -> void:
	for tree in get_tree().get_nodes_in_group("trees"):
		if not is_instance_valid(tree):
			continue
		if tree is FarmTree:
			(tree as FarmTree).set_growth_paused(is_paused)


func _apply_visual_state(is_night: bool, immediate: bool) -> void:
	if _overlay == null:
		return

	var target_overlay: Color = night_overlay_color if is_night else day_overlay_color
	var target_label: Color = night_label_color if is_night else day_label_color

	if is_instance_valid(_overlay_tween):
		_overlay_tween.kill()

	if immediate or day_night_transition_seconds <= 0.0:
		_overlay.color = target_overlay
		if _label != null:
			_label.modulate = target_label
		return

	_overlay_tween = create_tween().set_parallel(true)
	_overlay_tween.tween_property(_overlay, "color", target_overlay, day_night_transition_seconds)
	if _label != null:
		_overlay_tween.tween_property(_label, "modulate", target_label, day_night_transition_seconds)


# ── Timer callbacks ──────────────────────────────────────────────────────────

func _on_phase_timer_timeout() -> void:
	if _stopped or not is_inside_tree() or not enable_day_night_cycle:
		return

	if _is_night_phase:
		_start_day_phase()
	else:
		_start_night_phase()


func _on_wave_timer_timeout() -> void:
	if _stopped or not _is_night_phase:
		return

	_spawn_next_wave()


# ── Wave logic ───────────────────────────────────────────────────────────────

func _spawn_next_wave() -> void:
	if not _is_night_phase:
		return

	var total_waves: int = maxi(night_waves_per_cycle, 1)
	if _waves_spawned_this_night >= total_waves:
		Audio.play_sfx(&"world_wave_clear")
		return

	var wave_size: int = _compute_wave_size()
	if is_instance_valid(_enemy_spawner):
		_enemy_spawner.spawn_wave(wave_size, true)

	_waves_spawned_this_night += 1
	if _waves_spawned_this_night == 1:
		Audio.play_sfx(&"world_wave_coming", -2.0)
	elif _waves_spawned_this_night == maxi(int(ceil(float(total_waves) * 0.5)), 2):
		Audio.play_sfx(&"world_wave_mid", -2.0)

	if _waves_spawned_this_night >= total_waves:
		Audio.play_music(&"music_wave_peak", -8.0)
	_update_label("Night %d  Wave %d/%d" % [_night_index, _waves_spawned_this_night, total_waves])

	if _waves_spawned_this_night >= total_waves:
		return

	if _wave_timer == null or not is_instance_valid(_wave_timer):
		return
	if not _wave_timer.is_inside_tree():
		return

	_wave_timer.start(_get_wave_spacing_seconds(total_waves))


func _compute_wave_size() -> int:
	var growth_steps: int = maxi(_night_index - 1, 0)
	var base_wave_size: int = maxi(night_wave_base_size + (growth_steps * night_wave_size_growth_per_night), 1)
	var scaled_wave_size: int = int(round(float(base_wave_size) * maxf(night_wave_spawn_scale, 0.1)))
	return maxi(scaled_wave_size, 1)


func _get_wave_spacing_seconds(total_waves: int) -> float:
	if total_waves <= 1:
		return maxf(night_duration_seconds, 0.1)

	var max_spacing: float = maxf(night_duration_seconds / float(total_waves - 1), 0.1)
	if night_wave_spacing_seconds <= 0.0:
		return max_spacing

	return clampf(night_wave_spacing_seconds, 0.1, max_spacing)


func _update_label(phase_text: String) -> void:
	if _label == null:
		return

	_label.visible = true
	_label.text = phase_text

# ── soul tower logic ───────────────────────────────────────────────────────────────

func _place_soul_tower() -> void:
	if soul_tower == null:
		soul_tower = soul_tower_packed_scene.instantiate()
		get_parent().add_child(soul_tower)
	
	soul_tower.global_position = random_point_in_ring(soul_tower_spawn_center,soul_tower_spawn_min_dist_from_center,soul_tower_spawn_max_dist_from_center)
	soul_tower.has_interacted = false

func random_point_in_ring(center: Vector2, min_dist: float, max_dist: float) -> Vector2:
	var angle = randf() * TAU
	
	# Important: sqrt for uniform distribution
	var r = sqrt(randf() * (max_dist * max_dist - min_dist * min_dist) + min_dist * min_dist)
	
	var offset = Vector2(cos(angle), sin(angle)) * r
	return center + offset
