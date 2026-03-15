extends CharacterBody2D
class_name SummonUnit

const CombatText = preload("res://scripts/floating_combat_text.gd")

@export var summon_identity: StringName = &"mushroom_knight"
@export var move_speed: float = 110.0
@export var repath_interval: float = 0.15
@export var target_reach_distance: float = 14.0
@export var follow_player_distance: float = 80.0
@export var attack_range: float = 210.0
@export var attack_damage: float = 20.0
@export var attack_cooldown: float = 0.8
@export var attack_projectile_scene: PackedScene = preload("res://entities/summon/summon_attack.tscn")
@export var max_health: float = 80.0
@export var nav_path_desired_distance: float = 12.0
@export var nav_target_desired_distance: float = 16.0
@export var nav_probe_ring_points: int = 8
@export var nav_probe_ring_step: float = 16.0
@export var nav_goal_update_interval: float = 0.45
@export var follow_player_retarget_interval: float = 10.0
@export var retarget_min_interval: float = 2.0
@export var retarget_far_distance_start: float = 900.0
@export var retarget_far_distance_span: float = 1400.0
@export var retarget_far_interval_bonus: float = 2.5
@export var follow_nav_target_update_interval: float = 0.32
@export var follow_nav_target_min_shift: float = 34.0
@export var follow_enemy_scan_interval: float = 0.75
@export var enemy_target_search_radius: float = 700.0
@export var ai_update_bucket_count: int = 4
@export var far_lod_distance: float = 1300.0
@export var far_lod_repath_multiplier: float = 2.0
@export var far_lod_nav_refresh_multiplier: float = 2.2
@export var far_lod_follow_refresh_multiplier: float = 3.0
@export var stuck_detection_enabled: bool = true
@export var stuck_check_window_seconds: float = 0.45
@export var stuck_min_distance_per_window: float = 8.0
@export var stuck_required_windows: int = 3
@export var stuck_recovery_cooldown_seconds: float = 1.0
@export var stuck_recovery_probe_points: int = 12
@export var stuck_recovery_probe_rings: int = 3
@export var stuck_recovery_probe_step: float = 52.0
@export var command_follow_distance: float = 72.0
@export var follow_formation_radius: float = 26.0
@export var health_bar_show_duration: float = 2.0
@export var always_show_health_bar: bool = false
@export var selected_marker_radius: float = 40.0
@export var selected_marker_line_width: float = 3.0
@export var selected_marker_fill_color: Color = Color(1.0, 0.94, 0.45, 0.16)
@export var selected_marker_line_color: Color = Color(1.0, 0.94, 0.45, 0.98)
@export var selected_marker_y_offset: float = 14.0
@export var selected_marker_arc_points: int = 18
@export var sprite_texture_override: Texture2D
@export var summon_scene_for_split: PackedScene = preload("res://entities/summon/summon.tscn")
@export var split_child_count: int = 2
@export var split_child_scale: float = 0.72
@export var split_child_health_scale: float = 0.45
@export var split_child_damage_scale: float = 0.45
@export var split_enabled: bool = true
@export var is_mini_slime: bool = false
@export var idle_bounce_fast_speed: float = 8.0
@export var idle_bounce_fast_height: float = 2.3
@export var idle_bounce_slow_speed: float = 2.3
@export var idle_bounce_slow_height: float = 0.9
@export var attack_tilt_angle_degrees: float = 8.0
@export var attack_tilt_duration: float = 0.12

const PHYSICS_LAYER_WORLD: int = 1 << 0
const PHYSICS_LAYER_SUMMON: int = 1 << 3

const ID_BABY_DRAGON: StringName = &"baby_dragon"
const ID_SLIME: StringName = &"slime"
const ID_GHOST: StringName = &"ghost"
const ID_SPARK_GOBLIN: StringName = &"spark_goblin"
const ID_JACK_IN_THE_BOX: StringName = &"jack_in_the_box"
const ID_MUSHROOM_KNIGHT: StringName = &"mushroom_knight"
const ID_ACORN_SPITTER: StringName = &"acorn_spitter"
const ID_BUSH_BOY: StringName = &"bush_boy"
const ID_BEE_SWARM: StringName = &"bee_swarm"
const ID_ROOTER: StringName = &"rooter"
const VFX_FIRE_CONE_PATH: String = "res://assets/vfx/fire_cone.png"
const VFX_CHAIN_LIGHTNING_PATH: String = "res://assets/vfx/chain_lightning.png"
const VFX_ACORN_PROJECTILE_PATH: String = "res://assets/vfx/acorn_projectile.png"
const VFX_SPRING_PROJECTILE_PATH: String = "res://assets/vfx/spring_projectile.png"
const MAX_WORLD_VFX_SPAWNS_PER_FRAME: int = 28
const MAX_PROJECTILE_SPAWNS_PER_FRAME: int = 48

enum CommandMode {
	AUTO,
	MOVE,
	FOLLOW,
	HOLD,
}

var _enemy_target: Node2D
var _player_target: Node2D
var _time_to_repath: float = 0.0
var _time_to_next_attack: float = 0.0
var _current_health: float = 0.0
var _command_mode: CommandMode = CommandMode.AUTO
var _move_target_position: Vector2 = Vector2.ZERO
var _hold_toggle_enabled: bool = false
var _time_to_nav_goal_refresh: float = 0.0
var _last_nav_goal_target: Node2D
var _time_to_follow_nav_refresh: float = 0.0
var _last_follow_nav_target: Vector2 = Vector2.INF
var _follow_snapshot_target: Vector2 = Vector2.INF
var _time_to_follow_enemy_scan: float = 0.0
var _follow_formation_angle: float = 0.0
var _is_command_selected: bool = false
var _health_bar_visible_time_left: float = 0.0
var _behavior_tick_time_left: float = 0.0
var _attack_lock_time_left: float = 0.0
var _has_split_once: bool = false
var _external_push_velocity: Vector2 = Vector2.ZERO
var _vfx_fire_cone: Texture2D
var _vfx_chain_lightning: Texture2D
var _vfx_acorn_projectile: Texture2D
var _vfx_spring_projectile: Texture2D
var _attack_tilt_tween: Tween
var _spatial_index: SpatialIndex2D
var _vfx_pool: VfxPool2D
var _perf_debug: PerfDebugService
var _stuck_check_time_left: float = 0.0
var _stuck_window_distance_accum: float = 0.0
var _stuck_window_failures: int = 0
var _stuck_recovery_cooldown_time_left: float = 0.0

static var _world_vfx_spawn_frame: int = -1
static var _world_vfx_spawn_count: int = 0
static var _projectile_spawn_frame: int = -1
static var _projectile_spawn_count: int = 0

@onready var _health_bar: ProgressBar = get_node_or_null("HealthBar") as ProgressBar
@onready var _navigation_agent: NavigationAgent2D = get_node_or_null("NavigationAgent2D") as NavigationAgent2D
@onready var _sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D

func _ready() -> void:
	_perf_debug = get_node_or_null("/root/PerfDebug") as PerfDebugService
	_load_vfx_assets()
	set_summon_identity(summon_identity)
	if sprite_texture_override != null and _sprite != null:
		_sprite.texture = sprite_texture_override

	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = PHYSICS_LAYER_SUMMON
	collision_mask = 0 if summon_identity == ID_GHOST else PHYSICS_LAYER_WORLD
	add_to_group("summons")
	if _navigation_agent != null:
		_navigation_agent.path_desired_distance = maxf(nav_path_desired_distance, 4.0)
		_navigation_agent.target_desired_distance = maxf(nav_target_desired_distance, 6.0)
		_navigation_agent.max_speed = move_speed
		_navigation_agent.set_navigation_map(get_world_2d().navigation_map)
	_spatial_index = get_node_or_null("/root/SpatialIndex") as SpatialIndex2D
	_vfx_pool = get_node_or_null("/root/VfxPool") as VfxPool2D
	_follow_formation_angle = randf_range(0.0, TAU)
	_player_target = _find_player()
	_current_health = max_health
	_time_to_repath = randf_range(0.0, maxf(repath_interval, 0.05))
	_time_to_nav_goal_refresh = randf_range(0.0, maxf(nav_goal_update_interval, 0.05))
	_time_to_follow_nav_refresh = randf_range(0.0, maxf(follow_nav_target_update_interval, 0.05))
	_time_to_follow_enemy_scan = randf_range(0.0, maxf(follow_enemy_scan_interval, 0.1))
	_time_to_next_attack = randf_range(0.0, maxf(attack_cooldown, 0.05) * 0.3)
	_health_bar_visible_time_left = 0.0
	_stuck_check_time_left = randf_range(0.0, maxf(stuck_check_window_seconds, 0.05))
	_update_health_bar()

func set_summon_identity(identity: StringName) -> void:
	summon_identity = identity
	_apply_summon_identity_profile()

func _apply_summon_identity_profile() -> void:
	match summon_identity:
		ID_BABY_DRAGON:
			move_speed = 150.0
			attack_range = 210.0
			attack_damage = 11.0
			attack_cooldown = 1.0
			max_health = 62.0
		ID_SLIME:
			move_speed = 72.0
			attack_range = 58.0
			attack_damage = 40.0
			attack_cooldown = 1.65
			max_health = 150.0
		ID_GHOST:
			move_speed = 140.0
			attack_range = 92.0
			attack_damage = 0.0
			attack_cooldown = 0.35
			max_health = 50.0
			follow_player_distance = 60.0
		ID_SPARK_GOBLIN:
			move_speed = 112.0
			attack_range = 220.0
			attack_damage = 15.0
			attack_cooldown = 0.9
			max_health = 80.0
		ID_JACK_IN_THE_BOX:
			move_speed = 120.0
			attack_range = 190.0
			attack_damage = 20.0
			attack_cooldown = 1.05
			max_health = 96.0
		ID_MUSHROOM_KNIGHT:
			move_speed = 84.0
			attack_range = 62.0
			attack_damage = 19.0
			attack_cooldown = 1.2
			max_health = 125.0
		ID_ACORN_SPITTER:
			move_speed = 152.0
			attack_range = 256.0
			attack_damage = 8.0
			attack_cooldown = 0.5
			max_health = 82.0
		ID_BUSH_BOY:
			move_speed = 48.0
			attack_range = 0.0
			attack_damage = 0.0
			attack_cooldown = 1.0
			max_health = 300.0
		ID_BEE_SWARM:
			move_speed = 170.0
			attack_range = 132.0
			attack_damage = 4.0
			attack_cooldown = 0.24
			max_health = 58.0
		ID_ROOTER:
			move_speed = 82.0
			attack_range = 145.0
			attack_damage = 7.0
			attack_cooldown = 1.0
			max_health = 102.0
		_:
			# Preserve existing defaults for unknown IDs.
			pass

func _physics_process(delta: float) -> void:
	var physics_start_us: int = Time.get_ticks_usec()
	_perf_inc(&"summon.physics_ticks")
	if _command_mode == CommandMode.FOLLOW:
		_perf_inc(&"summon.follow_mode_ticks")

	_time_to_repath -= delta
	_time_to_nav_goal_refresh = maxf(_time_to_nav_goal_refresh - delta, 0.0)
	_time_to_follow_nav_refresh = maxf(_time_to_follow_nav_refresh - delta, 0.0)
	_time_to_follow_enemy_scan = maxf(_time_to_follow_enemy_scan - delta, 0.0)
	_time_to_next_attack = maxf(_time_to_next_attack - delta, 0.0)
	_stuck_recovery_cooldown_time_left = maxf(_stuck_recovery_cooldown_time_left - delta, 0.0)
	var previous_health_bar_visible_time_left: float = _health_bar_visible_time_left
	_health_bar_visible_time_left = maxf(_health_bar_visible_time_left - delta, 0.0)
	_behavior_tick_time_left = maxf(_behavior_tick_time_left - delta, 0.0)
	_attack_lock_time_left = maxf(_attack_lock_time_left - delta, 0.0)
	_external_push_velocity = _external_push_velocity.move_toward(Vector2.ZERO, 900.0 * delta)
	if previous_health_bar_visible_time_left > 0.0 and _health_bar_visible_time_left <= 0.0:
		_refresh_health_bar_visibility()

	_update_passive_archetype_behavior()
	var is_far_lod: bool = _is_far_from_player()
	var repath_wait: float = maxf(repath_interval, 0.05)
	if is_far_lod:
		repath_wait *= maxf(far_lod_repath_multiplier, 1.0)

	if _time_to_repath <= 0.0 and _is_ai_bucket_turn():
		var repath_block_start_us: int = Time.get_ticks_usec()
		var should_refresh_enemy_target: bool = _command_mode == CommandMode.AUTO
		if _command_mode == CommandMode.FOLLOW and _time_to_follow_enemy_scan <= 0.0:
			should_refresh_enemy_target = true

		if should_refresh_enemy_target:
			var enemy_refresh_start_us: int = Time.get_ticks_usec()
			if summon_identity == ID_SPARK_GOBLIN:
				_enemy_target = _find_random_enemy_nearby(attack_range * 1.4)
			else:
				_enemy_target = _find_closest_enemy()
			_perf_mark_scope(&"summon.refresh_enemy_target", enemy_refresh_start_us)

			if _command_mode == CommandMode.FOLLOW:
				_time_to_follow_enemy_scan = _get_follow_enemy_scan_wait()
		if not is_instance_valid(_player_target):
			_player_target = _find_player()

		if _command_mode == CommandMode.AUTO:
			var nav_target: Node2D = _enemy_target
			if _is_non_attacker_identity() or not is_instance_valid(nav_target):
				nav_target = _player_target

			if is_instance_valid(nav_target):
				if _time_to_nav_goal_refresh <= 0.0 and _should_refresh_auto_navigation_goal(nav_target):
					_set_navigation_target_for_target(nav_target)
					_last_nav_goal_target = nav_target
					_time_to_nav_goal_refresh = _get_target_retarget_wait(nav_target.global_position)
			else:
				_last_nav_goal_target = null
				_time_to_nav_goal_refresh = 0.0
				_clear_navigation_target()
		else:
			_last_nav_goal_target = null
			_time_to_nav_goal_refresh = 0.0
		_time_to_repath = repath_wait
		_perf_mark_scope(&"summon.repath_block", repath_block_start_us)

	if _command_mode == CommandMode.MOVE:
		_handle_move_command()
	elif _command_mode == CommandMode.FOLLOW:
		_handle_follow_command()
	elif _command_mode == CommandMode.HOLD:
		_handle_hold_command()
	elif _is_non_attacker_identity():
		_handle_non_attacker_auto()
	elif is_instance_valid(_enemy_target):
		var distance_to_enemy: float = global_position.distance_to(_enemy_target.global_position)
		if distance_to_enemy <= attack_range:
			velocity = Vector2.ZERO
			if _time_to_next_attack <= 0.0:
				_time_to_next_attack = attack_cooldown
				_perform_attack(_enemy_target)
		else:
			_move_towards(_enemy_target.global_position)
	elif is_instance_valid(_player_target):
		if global_position.distance_to(_player_target.global_position) > follow_player_distance:
			_move_towards(_player_target.global_position)
		else:
			velocity = Vector2.ZERO
	else:
		velocity = Vector2.ZERO

	var pre_move_position: Vector2 = global_position
	velocity += _external_push_velocity
	move_and_slide()
	_update_stuck_recovery(delta, pre_move_position)
	_perf_mark_physics_scope(&"summon.physics_total", physics_start_us, {
		"mode": get_command_mode_name(),
	})

func set_move_target(target_position: Vector2) -> void:
	_move_target_position = target_position
	_command_mode = CommandMode.MOVE

func set_hold_position(should_hold: bool) -> void:
	_hold_toggle_enabled = should_hold

	if _command_mode == CommandMode.MOVE:
		return

	if should_hold:
		_command_mode = CommandMode.HOLD
		velocity = Vector2.ZERO
		return

	_command_mode = CommandMode.AUTO

func clear_manual_command() -> void:
	if _hold_toggle_enabled:
		_command_mode = CommandMode.HOLD
	else:
		_command_mode = CommandMode.AUTO

func set_follow_player() -> void:
	if not is_instance_valid(_player_target):
		_player_target = _find_player()

	if not is_instance_valid(_player_target):
		_command_mode = CommandMode.AUTO
		return

	_hold_toggle_enabled = false
	_command_mode = CommandMode.FOLLOW
	_time_to_follow_nav_refresh = 0.0
	_time_to_follow_enemy_scan = 0.0
	_follow_snapshot_target = Vector2.INF
	_last_follow_nav_target = Vector2.INF

func set_auto_behavior() -> void:
	_hold_toggle_enabled = false
	_command_mode = CommandMode.AUTO
	_clear_navigation_target()

func set_selected_for_command(is_selected: bool) -> void:
	if _is_command_selected == is_selected:
		return

	_is_command_selected = is_selected
	_refresh_health_bar_visibility()
	queue_redraw()

func is_holding_position() -> bool:
	return _command_mode == CommandMode.HOLD

func is_hold_toggle_enabled() -> bool:
	return _hold_toggle_enabled

func get_command_mode_name() -> String:
	match _command_mode:
		CommandMode.MOVE:
			return "MOVE"
		CommandMode.FOLLOW:
			return "FOLLOW"
		CommandMode.HOLD:
			return "HOLD"
		_:
			return "AUTO"

func _handle_move_command() -> void:
	var distance_to_target: float = global_position.distance_to(_move_target_position)
	if distance_to_target > target_reach_distance:
		_move_towards(_move_target_position)
	else:
		velocity = Vector2.ZERO
		if _hold_toggle_enabled:
			_command_mode = CommandMode.HOLD
		else:
			_command_mode = CommandMode.AUTO

	_try_attack_in_range()

func _handle_hold_command() -> void:
	velocity = Vector2.ZERO
	_clear_navigation_target()
	_try_attack_in_range()

func _handle_follow_command() -> void:
	var follow_start_us: int = Time.get_ticks_usec()
	if not is_instance_valid(_player_target):
		_player_target = _find_player()

	if not is_instance_valid(_player_target):
		_command_mode = CommandMode.AUTO
		velocity = Vector2.ZERO
		_perf_mark_scope(&"summon.follow_handler", follow_start_us, {
			"status": "no_player",
		})
		return

	if _attack_lock_time_left > 0.0:
		velocity = Vector2.ZERO
		_try_attack_in_range()
		_perf_mark_scope(&"summon.follow_handler", follow_start_us, {
			"status": "attack_lock",
		})
		return

	_update_follow_navigation_target(_player_target.global_position)

	if _follow_snapshot_target == Vector2.INF:
		_follow_snapshot_target = _get_follow_formation_target(_player_target.global_position)
		_set_navigation_target(_follow_snapshot_target)
		_last_follow_nav_target = _follow_snapshot_target
		_time_to_follow_nav_refresh = _get_follow_nav_refresh_wait(_follow_snapshot_target)

	var distance_to_follow_snapshot: float = global_position.distance_to(_follow_snapshot_target)
	if distance_to_follow_snapshot > maxf(target_reach_distance, 16.0):
		velocity = _get_navigation_velocity(_follow_snapshot_target)
	else:
		velocity = Vector2.ZERO
		_clear_navigation_target()

	_try_attack_in_range()
	_perf_mark_scope(&"summon.follow_handler", follow_start_us)

func _handle_non_attacker_auto() -> void:
	if is_instance_valid(_player_target) and global_position.distance_to(_player_target.global_position) > follow_player_distance:
		_move_towards(_player_target.global_position)
	else:
		velocity = Vector2.ZERO
		_clear_navigation_target()

func _update_follow_navigation_target(player_position: Vector2) -> void:
	var update_start_us: int = Time.get_ticks_usec()
	if not _uses_navigation_agent():
		_perf_mark_scope(&"summon.update_follow_nav_target", update_start_us, {
			"status": "no_nav_agent",
		})
		return
	if _navigation_agent == null:
		_perf_mark_scope(&"summon.update_follow_nav_target", update_start_us, {
			"status": "missing_nav_agent",
		})
		return
	if _navigation_agent.get_navigation_map() == RID():
		_perf_mark_scope(&"summon.update_follow_nav_target", update_start_us, {
			"status": "missing_nav_map",
		})
		return

	var follow_target: Vector2 = _get_follow_formation_target(player_position)
	if _time_to_follow_nav_refresh > 0.0:
		_perf_mark_scope(&"summon.update_follow_nav_target", update_start_us, {
			"status": "refresh_wait",
		})
		return

	_set_navigation_target(follow_target)
	_follow_snapshot_target = follow_target
	_last_follow_nav_target = follow_target
	_time_to_follow_nav_refresh = _get_follow_nav_refresh_wait(follow_target)
	_perf_inc(&"summon.follow_nav_target_updates")
	_perf_mark_scope(&"summon.update_follow_nav_target", update_start_us)

func _get_follow_formation_target(player_position: Vector2) -> Vector2:
	var radius: float = maxf(follow_formation_radius, 0.0)
	if radius <= 0.0:
		return player_position

	return player_position + (Vector2.RIGHT.rotated(_follow_formation_angle) * radius)

func _try_attack_in_range() -> bool:
	if not is_instance_valid(_enemy_target):
		return false
	if attack_range <= 0.0 or attack_damage <= 0.0:
		return false

	if global_position.distance_to(_enemy_target.global_position) > attack_range:
		return false

	if _time_to_next_attack > 0.0:
		return false

	_time_to_next_attack = attack_cooldown
	_perform_attack(_enemy_target)
	return true

func _update_passive_archetype_behavior() -> void:
	if _sprite != null:
		var bounce_time: float = Time.get_ticks_msec() / 1000.0
		var bounce_speed: float = idle_bounce_slow_speed
		var bounce_height: float = idle_bounce_slow_height
		if summon_identity == ID_JACK_IN_THE_BOX or summon_identity == ID_SLIME:
			bounce_speed = idle_bounce_fast_speed
			bounce_height = idle_bounce_fast_height

		_sprite.position.y = sin(bounce_time * bounce_speed) * bounce_height

	if summon_identity != ID_GHOST:
		return
	if _behavior_tick_time_left > 0.0:
		return

	_behavior_tick_time_left = 0.22
	for enemy in _get_enemies_in_radius(attack_range):
		_deal_damage_to_target(enemy, 3.0)

func _perform_attack(target: Node2D) -> void:
	if target == null:
		return

	if summon_identity != ID_GHOST and summon_identity != ID_BUSH_BOY:
		_play_attack_tilt_animation()

	match summon_identity:
		ID_BABY_DRAGON:
			_attack_baby_dragon(target)
		ID_SLIME:
			_attack_slime(target)
		ID_GHOST:
			# Ghost deals proximity drain as a passive aura.
			pass
		ID_SPARK_GOBLIN:
			_attack_spark_goblin(target)
		ID_JACK_IN_THE_BOX:
			_attack_jack(target)
		ID_MUSHROOM_KNIGHT:
			_attack_mushroom_knight(target)
		ID_ACORN_SPITTER:
			_attack_acorn_spitter(target)
		ID_BUSH_BOY:
			# Bush unit is a defensive body blocker and does not attack.
			pass
		ID_BEE_SWARM:
			_attack_bee_swarm(target)
		ID_ROOTER:
			_attack_rooter(target)
		_:
			_launch_projectile_attack(target)

func _play_attack_tilt_animation() -> void:
	if _sprite == null:
		return

	if is_instance_valid(_attack_tilt_tween):
		_attack_tilt_tween.kill()

	var tilt_sign: float = -1.0 if (randi() % 2 == 0) else 1.0
	var tilt_angle: float = deg_to_rad(attack_tilt_angle_degrees) * tilt_sign
	var half_duration: float = maxf(attack_tilt_duration * 0.5, 0.03)

	_attack_tilt_tween = create_tween()
	_attack_tilt_tween.tween_property(_sprite, "rotation", tilt_angle, half_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_attack_tilt_tween.tween_property(_sprite, "rotation", 0.0, half_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _attack_baby_dragon(primary_target: Node2D) -> void:
	var to_primary: Vector2 = (primary_target.global_position - global_position).normalized()
	if to_primary == Vector2.ZERO:
		to_primary = Vector2.RIGHT

	_spawn_world_vfx(
		_vfx_fire_cone,
		global_position,
		to_primary.angle() + deg_to_rad(30.0),
		Vector2(1.45, 1.15) * 4.0,
		0.2,
		true,
		Vector2(0.0, 1.0)
	)

	var cone_half_angle_cos: float = cos(deg_to_rad(22.0))
	for enemy in _get_enemies_in_radius(attack_range):
		var to_enemy: Vector2 = (enemy.global_position - global_position).normalized()
		if to_enemy == Vector2.ZERO:
			continue
		if to_primary.dot(to_enemy) < cone_half_angle_cos:
			continue
		_deal_damage_to_target(enemy, attack_damage, {
			"burn_dps": 4.0,
			"burn_duration": 2.5,
		})

func _attack_slime(target: Node2D) -> void:
	_deal_damage_to_target(target, attack_damage, {
		"knockback_force": 120.0,
	})

func _attack_spark_goblin(target: Node2D) -> void:
	var visited: Dictionary = {}
	var current_target: Node2D = target
	var jump_damage: float = attack_damage
	var chain_from: Vector2 = global_position

	for jump_index in range(4):
		if not is_instance_valid(current_target):
			break

		_spawn_chain_lightning_vfx(chain_from, current_target.global_position)

		visited[current_target.get_instance_id()] = true
		_deal_damage_to_target(current_target, jump_damage)
		jump_damage *= 0.78
		chain_from = current_target.global_position

		if jump_index >= 3:
			break

		var next_target: Node2D = _find_next_chain_target(current_target.global_position, visited)
		if not is_instance_valid(next_target):
			break
		current_target = next_target

func _find_next_chain_target(from_position: Vector2, visited: Dictionary) -> Node2D:
	var enemy_candidates: Array[Node2D] = []
	for enemy in _get_enemies_in_radius_from_point(from_position, 135.0):
		if visited.has(enemy.get_instance_id()):
			continue
		enemy_candidates.append(enemy)

	var summon_candidates: Array[Node2D] = []
	for summon_candidate in _get_summons_in_radius_from_point(from_position, 135.0):
		if summon_candidate == self:
			continue
		if visited.has(summon_candidate.get_instance_id()):
			continue
		summon_candidates.append(summon_candidate)

	if not summon_candidates.is_empty() and randf() < 0.65:
		return _pick_closest_target(from_position, summon_candidates)

	if not enemy_candidates.is_empty():
		return _pick_closest_target(from_position, enemy_candidates)

	if not summon_candidates.is_empty():
		return _pick_closest_target(from_position, summon_candidates)

	return null

func _pick_closest_target(from_position: Vector2, candidates: Array[Node2D]) -> Node2D:
	var best_target: Node2D
	var best_distance_sq: float = INF
	for candidate in candidates:
		if not is_instance_valid(candidate):
			continue
		var distance_sq: float = from_position.distance_squared_to(candidate.global_position)
		if distance_sq < best_distance_sq:
			best_distance_sq = distance_sq
			best_target = candidate

	return best_target

func _attack_jack(target: Node2D) -> void:
	_launch_projectile_attack(target, {
		"knockback_force": 260.0,
		"projectile_texture": _vfx_spring_projectile,
		"projectile_rotation_offset": deg_to_rad(45.0),
	})

func _attack_mushroom_knight(target: Node2D) -> void:
	_deal_damage_to_target(target, attack_damage)

func _attack_acorn_spitter(target: Node2D) -> void:
	_attack_lock_time_left = maxf(_attack_lock_time_left, 0.22)
	velocity = Vector2.ZERO
	_launch_projectile_attack(target, {
		"projectile_texture": _vfx_acorn_projectile,
	})

func _attack_bee_swarm(target: Node2D) -> void:
	_deal_damage_to_target(target, attack_damage, {
		"sting_stacks_add": 1,
		"sting_dps_per_stack": 0.5,
		"sting_duration": 2.4,
		"sting_max_stack_burst_damage": 12.0,
	})

func _attack_rooter(target: Node2D) -> void:
	_deal_damage_to_target(target, attack_damage, {
		"root_duration": 1.1,
	})

func _get_enemies_in_radius(radius: float) -> Array[Node2D]:
	return _get_enemies_in_radius_from_point(global_position, radius)

func _get_enemies_in_radius_from_point(from_position: Vector2, radius: float) -> Array[Node2D]:
	var spatial_index := _resolve_spatial_index()
	if spatial_index != null:
		return spatial_index.get_nodes_in_radius(from_position, &"enemies", radius, self)

	var enemies: Array[Node2D] = []
	var radius_sq: float = radius * radius

	for candidate in get_tree().get_nodes_in_group("enemies"):
		if not (candidate is Node2D):
			continue
		var enemy: Node2D = candidate as Node2D
		if from_position.distance_squared_to(enemy.global_position) <= radius_sq:
			enemies.append(enemy)

	return enemies

func _get_summons_in_radius_from_point(from_position: Vector2, radius: float) -> Array[Node2D]:
	var spatial_index := _resolve_spatial_index()
	if spatial_index != null:
		return spatial_index.get_nodes_in_radius(from_position, &"summons", radius, self)

	var summons: Array[Node2D] = []
	var radius_sq: float = radius * radius

	for candidate in get_tree().get_nodes_in_group("summons"):
		if not (candidate is Node2D):
			continue
		var summon_node: Node2D = candidate as Node2D
		if from_position.distance_squared_to(summon_node.global_position) <= radius_sq:
			summons.append(summon_node)

	return summons

func _deal_damage_to_target(target: Node2D, damage: float, options: Dictionary = {}) -> void:
	if target == null or damage <= 0.0:
		return
	if target is EnemyUnit:
		(target as EnemyUnit).take_hit(damage, self, options)
		return
	if target is Player:
		(target as Player).take_hit(damage, self, options)
		return
	if target is SummonUnit:
		(target as SummonUnit).take_hit(damage, self, options)
		return

	if target.has_method("take_hit"):
		target.call("take_hit", damage, self, options)
		return

	if target.has_method("take_damage"):
		target.call("take_damage", damage)

func take_hit(amount: float, source: Node2D = null, options: Dictionary = {}) -> void:
	var final_damage: float = amount
	if summon_identity == ID_BUSH_BOY and _command_mode == CommandMode.HOLD:
		final_damage *= 0.6

	if options.has("damage_multiplier"):
		final_damage *= float(options.get("damage_multiplier", 1.0))

	take_damage(final_damage)

	var knockback_force: float = float(options.get("knockback_force", 0.0))
	if knockback_force > 0.0 and is_instance_valid(source):
		var push_direction: Vector2 = source.global_position.direction_to(global_position)
		if push_direction != Vector2.ZERO:
			_external_push_velocity += push_direction * knockback_force

func take_damage(amount: float) -> void:
	if amount <= 0.0:
		return

	var previous_health: float = _current_health
	_current_health = clampf(_current_health - amount, 0.0, max_health)
	var applied_damage: float = previous_health - _current_health
	if applied_damage > 0.0:
		CombatText.spawn_damage(self, applied_damage)
		_request_health_bar_visibility()
	_update_health_bar()

	if _current_health <= 0.0:
		_die()

func heal(amount: float) -> void:
	if amount <= 0.0:
		return
	if _current_health <= 0.0:
		return

	var previous_health: float = _current_health
	_current_health = clampf(_current_health + amount, 0.0, max_health)
	var healed_amount: float = _current_health - previous_health
	if healed_amount <= 0.0:
		return

	CombatText.spawn_heal(self, healed_amount)
	_request_health_bar_visibility(0.75)
	_update_health_bar()

func _die() -> void:
	if _should_split_on_death():
		_spawn_split_children()
	queue_free()

func _should_split_on_death() -> bool:
	if summon_identity != ID_SLIME:
		return false
	if not split_enabled:
		return false
	if is_mini_slime:
		return false
	if _has_split_once:
		return false
	return true

func _spawn_split_children() -> void:
	if summon_scene_for_split == null:
		return

	_has_split_once = true
	var parent_node: Node = get_tree().current_scene
	if parent_node == null:
		parent_node = get_parent()
	if parent_node == null:
		return

	var split_count: int = maxi(split_child_count, 1)
	for split_index in range(split_count):
		var split_summon := summon_scene_for_split.instantiate() as Node2D
		if split_summon == null:
			continue

		if split_summon.has_method("set_summon_identity"):
			split_summon.call("set_summon_identity", ID_SLIME)
		else:
			split_summon.set("summon_identity", ID_SLIME)

		split_summon.set("is_mini_slime", true)
		split_summon.set("split_enabled", false)
		split_summon.set("max_health", maxf(max_health * split_child_health_scale, 12.0))
		split_summon.set("attack_damage", maxf(attack_damage * split_child_damage_scale, 4.0))
		split_summon.set("move_speed", move_speed * 1.25)
		split_summon.set("sprite_texture_override", sprite_texture_override)

		parent_node.add_child(split_summon)
		split_summon.scale = scale * split_child_scale
		var angle: float = TAU * float(split_index) / float(split_count)
		split_summon.global_position = global_position + Vector2.RIGHT.rotated(angle) * 20.0
		if split_summon.has_method("set_hold_position"):
			split_summon.call("set_hold_position", true)

func _update_health_bar() -> void:
	if _health_bar == null:
		return

	_health_bar.max_value = max_health
	_health_bar.value = _current_health
	_refresh_health_bar_visibility()

func _request_health_bar_visibility(duration: float = -1.0) -> void:
	if _health_bar == null:
		return

	var resolved_duration: float = duration
	if resolved_duration < 0.0:
		resolved_duration = health_bar_show_duration
	_health_bar_visible_time_left = maxf(_health_bar_visible_time_left, maxf(resolved_duration, 0.0))
	_refresh_health_bar_visibility()

func _refresh_health_bar_visibility() -> void:
	if _health_bar == null:
		return

	var should_show: bool = always_show_health_bar or _is_command_selected or _health_bar_visible_time_left > 0.0
	if _current_health <= 0.0:
		should_show = false
	_health_bar.visible = should_show

func _is_ai_bucket_turn() -> bool:
	var bucket_count: int = maxi(ai_update_bucket_count, 1)
	if bucket_count <= 1:
		return true

	var frame_bucket: int = Engine.get_physics_frames() % bucket_count
	var summon_bucket: int = int(get_instance_id() % bucket_count)
	return frame_bucket == summon_bucket

func _launch_projectile_attack(target: Node2D, hit_options: Dictionary = {}) -> void:
	if attack_projectile_scene == null:
		_deal_damage_to_target(target, attack_damage, hit_options)
		return
	if not _can_spawn_projectile_this_frame():
		_deal_damage_to_target(target, attack_damage, hit_options)
		return

	var parent_node: Node = get_tree().current_scene
	if parent_node == null:
		parent_node = get_parent()
	if parent_node == null:
		_deal_damage_to_target(target, attack_damage, hit_options)
		return

	var projectile: SummonAttackProjectile = SummonAttackProjectile.spawn(
		attack_projectile_scene,
		parent_node,
		global_position,
		target,
		attack_damage,
		self,
		hit_options
	)
	if projectile == null:
		_deal_damage_to_target(target, attack_damage, hit_options)
		return

func _spawn_chain_lightning_vfx(from_position: Vector2, to_position: Vector2) -> void:
	var chain_delta: Vector2 = to_position - from_position
	if chain_delta.length_squared() <= 0.0001:
		return

	var midpoint: Vector2 = from_position + (chain_delta * 0.5)
	var scale_x: float = maxf(chain_delta.length() / 64.0, 0.6)
	_spawn_world_vfx(_vfx_chain_lightning, midpoint, chain_delta.angle(), Vector2(scale_x, 1.0), 0.12)

func _load_vfx_assets() -> void:
	_vfx_fire_cone = load(VFX_FIRE_CONE_PATH) as Texture2D
	_vfx_chain_lightning = load(VFX_CHAIN_LIGHTNING_PATH) as Texture2D
	_vfx_acorn_projectile = load(VFX_ACORN_PROJECTILE_PATH) as Texture2D
	_vfx_spring_projectile = load(VFX_SPRING_PROJECTILE_PATH) as Texture2D

func _spawn_world_vfx(texture: Texture2D, world_position: Vector2, rotation_radians: float = 0.0, sprite_scale: Vector2 = Vector2.ONE, lifetime: float = 0.2, use_corner_anchor: bool = false, corner_anchor_uv: Vector2 = Vector2.ZERO) -> void:
	if texture == null:
		return
	if not _can_spawn_world_vfx_this_frame():
		return

	var parent_node: Node = get_tree().current_scene
	if parent_node == null:
		parent_node = get_parent()
	if parent_node == null:
		return

	var resolved_world_position: Vector2 = world_position
	if use_corner_anchor:
		var clamped_anchor_uv: Vector2 = Vector2(clampf(corner_anchor_uv.x, 0.0, 1.0), clampf(corner_anchor_uv.y, 0.0, 1.0))
		var texture_size: Vector2 = texture.get_size() * sprite_scale
		var local_anchor_offset: Vector2 = Vector2(texture_size.x * clamped_anchor_uv.x, texture_size.y * clamped_anchor_uv.y)
		resolved_world_position = world_position - local_anchor_offset.rotated(rotation_radians)

	if is_instance_valid(_vfx_pool):
		_vfx_pool.spawn_world_fade(parent_node, texture, resolved_world_position, rotation_radians, sprite_scale, 30, lifetime, 0.96, not use_corner_anchor)
		return

	var vfx_sprite := Sprite2D.new()
	vfx_sprite.texture = texture
	vfx_sprite.centered = not use_corner_anchor
	vfx_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if use_corner_anchor:
		vfx_sprite.global_position = resolved_world_position
	else:
		vfx_sprite.global_position = resolved_world_position
	vfx_sprite.rotation = rotation_radians
	vfx_sprite.scale = sprite_scale
	vfx_sprite.z_index = 30
	vfx_sprite.modulate = Color(1.0, 1.0, 1.0, 0.96)
	parent_node.add_child(vfx_sprite)

	var fade_tween: Tween = vfx_sprite.create_tween()
	fade_tween.tween_property(vfx_sprite, "modulate:a", 0.0, maxf(lifetime, 0.05))
	fade_tween.tween_callback(Callable(vfx_sprite, "queue_free"))

func _can_spawn_world_vfx_this_frame() -> bool:
	var frame: int = Engine.get_process_frames()
	if frame != _world_vfx_spawn_frame:
		_world_vfx_spawn_frame = frame
		_world_vfx_spawn_count = 0

	if _world_vfx_spawn_count >= MAX_WORLD_VFX_SPAWNS_PER_FRAME:
		return false

	_world_vfx_spawn_count += 1
	return true

func _can_spawn_projectile_this_frame() -> bool:
	var frame: int = Engine.get_process_frames()
	if frame != _projectile_spawn_frame:
		_projectile_spawn_frame = frame
		_projectile_spawn_count = 0

	if _projectile_spawn_count >= MAX_PROJECTILE_SPAWNS_PER_FRAME:
		return false

	_projectile_spawn_count += 1
	return true

func _move_towards(target_position: Vector2) -> void:
	if _attack_lock_time_left > 0.0:
		velocity = Vector2.ZERO
		return

	if global_position.distance_to(target_position) > target_reach_distance:
		_set_navigation_target(target_position)
		velocity = _get_navigation_velocity(target_position)
	else:
		velocity = Vector2.ZERO
		_clear_navigation_target()

func _update_stuck_recovery(delta: float, pre_move_position: Vector2) -> void:
	if not stuck_detection_enabled:
		_stuck_window_failures = 0
		_stuck_window_distance_accum = 0.0
		_stuck_check_time_left = maxf(stuck_check_window_seconds, 0.05)
		return
	if not _uses_navigation_agent():
		return
	if _navigation_agent == null or _navigation_agent.get_navigation_map() == RID():
		return
	if _command_mode == CommandMode.HOLD:
		_stuck_window_failures = 0
		_stuck_window_distance_accum = 0.0
		_stuck_check_time_left = maxf(stuck_check_window_seconds, 0.05)
		return
	if _command_mode == CommandMode.FOLLOW:
		# Follow mode should keep snapping toward player updates rather than detouring to recovery waypoints.
		_stuck_window_failures = 0
		_stuck_window_distance_accum = 0.0
		_stuck_check_time_left = maxf(stuck_check_window_seconds, 0.05)
		return

	var current_goal: Vector2 = _get_current_navigation_goal()
	if current_goal == Vector2.INF:
		_stuck_window_failures = 0
		_stuck_window_distance_accum = 0.0
		_stuck_check_time_left = maxf(stuck_check_window_seconds, 0.05)
		return

	var min_goal_distance: float = maxf(target_reach_distance * 2.0, 24.0)
	if _command_mode == CommandMode.FOLLOW:
		min_goal_distance = maxf(command_follow_distance * 0.5, 24.0)

	var should_be_advancing: bool = global_position.distance_to(current_goal) > min_goal_distance
	if not should_be_advancing:
		_stuck_window_failures = 0
		_stuck_window_distance_accum = 0.0
		_stuck_check_time_left = maxf(stuck_check_window_seconds, 0.05)
		return

	_stuck_check_time_left = maxf(_stuck_check_time_left - delta, 0.0)
	_stuck_window_distance_accum += pre_move_position.distance_to(global_position)
	if _stuck_check_time_left > 0.0:
		return

	var moved_enough: bool = _stuck_window_distance_accum >= maxf(stuck_min_distance_per_window, 0.5)
	if moved_enough:
		_stuck_window_failures = 0
	else:
		_stuck_window_failures += 1

	_stuck_check_time_left = maxf(stuck_check_window_seconds, 0.05)
	_stuck_window_distance_accum = 0.0

	if _stuck_window_failures < maxi(stuck_required_windows, 1):
		return
	if _stuck_recovery_cooldown_time_left > 0.0:
		return

	_trigger_stuck_recovery(current_goal)
	_stuck_window_failures = 0
	_stuck_recovery_cooldown_time_left = maxf(stuck_recovery_cooldown_seconds, 0.25)

func _get_current_navigation_goal() -> Vector2:
	if _command_mode == CommandMode.MOVE:
		return _move_target_position

	if _command_mode == CommandMode.FOLLOW:
		if _follow_snapshot_target != Vector2.INF:
			return _follow_snapshot_target
		if is_instance_valid(_player_target):
			return _player_target.global_position
		return Vector2.INF

	if _command_mode == CommandMode.AUTO:
		if not _is_non_attacker_identity() and is_instance_valid(_enemy_target):
			return _enemy_target.global_position
		if is_instance_valid(_player_target):
			return _player_target.global_position
		return Vector2.INF

	return Vector2.INF

func _trigger_stuck_recovery(goal_position: Vector2) -> void:
	if goal_position == Vector2.INF:
		return

	var recovery_start_us: int = Time.get_ticks_usec()
	var recovery_waypoint: Vector2 = _choose_stuck_recovery_waypoint(goal_position)
	_clear_navigation_target()
	_set_navigation_target(recovery_waypoint)

	if _command_mode == CommandMode.FOLLOW:
		_follow_snapshot_target = recovery_waypoint
		_time_to_follow_nav_refresh = 0.0

	_time_to_nav_goal_refresh = 0.0
	_time_to_repath = 0.0
	_perf_inc(&"summon.stuck_recoveries")
	_perf_mark_scope(&"summon.stuck_recovery", recovery_start_us, {
		"mode": get_command_mode_name(),
	})

func _choose_stuck_recovery_waypoint(goal_position: Vector2) -> Vector2:
	if _navigation_agent == null:
		return goal_position

	var nav_map: RID = _navigation_agent.get_navigation_map()
	if nav_map == RID():
		return goal_position

	var best_candidate: Vector2 = NavigationServer2D.map_get_closest_point(nav_map, goal_position)
	var best_score: float = best_candidate.distance_to(goal_position) + (best_candidate.distance_to(global_position) * 0.1)
	var base_direction: Vector2 = global_position.direction_to(goal_position)
	if base_direction == Vector2.ZERO:
		base_direction = Vector2.RIGHT

	var probe_points: int = maxi(stuck_recovery_probe_points, 6)
	var ring_count: int = maxi(stuck_recovery_probe_rings, 1)
	var ring_step: float = maxf(stuck_recovery_probe_step, 12.0)

	for ring_index in range(1, ring_count + 1):
		var probe_radius: float = ring_step * float(ring_index)
		for point_index in range(probe_points):
			var angle: float = TAU * float(point_index) / float(probe_points)
			var probe_direction: Vector2 = base_direction.rotated(angle)
			var sample_position: Vector2 = global_position + (probe_direction * probe_radius)
			var projected_sample: Vector2 = NavigationServer2D.map_get_closest_point(nav_map, sample_position)
			if projected_sample.distance_to(global_position) < 12.0:
				continue

			var score: float = projected_sample.distance_to(sample_position) + (projected_sample.distance_to(goal_position) * 0.08)
			if score < best_score:
				best_score = score
				best_candidate = projected_sample

	return best_candidate

func _uses_navigation_agent() -> bool:
	return summon_identity != ID_GHOST

func _get_navigation_velocity(target_position: Vector2) -> Vector2:
	if not _uses_navigation_agent():
		return global_position.direction_to(target_position) * move_speed

	if _navigation_agent == null or _navigation_agent.get_navigation_map() == RID():
		return Vector2.ZERO

	if _navigation_agent.is_navigation_finished():
		return Vector2.ZERO

	var next_path_position: Vector2 = _navigation_agent.get_next_path_position()
	return global_position.direction_to(next_path_position) * move_speed

func _set_navigation_target(target_position: Vector2) -> void:
	if not _uses_navigation_agent():
		return
	if _navigation_agent == null:
		return

	if _navigation_agent.target_position.distance_to(target_position) <= 6.0:
		return

	_navigation_agent.target_position = target_position

func _set_navigation_target_for_target(target: Node2D) -> void:
	var nav_target_start_us: int = Time.get_ticks_usec()
	if target == null:
		_perf_mark_scope(&"summon.set_nav_target_for_target", nav_target_start_us, {
			"status": "missing_target",
		})
		return

	if not _uses_navigation_agent():
		_perf_mark_scope(&"summon.set_nav_target_for_target", nav_target_start_us, {
			"status": "no_nav_agent",
		})
		return

	if _navigation_agent == null or _navigation_agent.get_navigation_map() == RID():
		_set_navigation_target(target.global_position)
		_perf_mark_scope(&"summon.set_nav_target_for_target", nav_target_start_us, {
			"status": "fallback_direct_target",
		})
		return

	var desired_distance: float = attack_range if target == _enemy_target else target_reach_distance
	var should_probe_ring: bool = target == _enemy_target and not _is_far_from_player()
	var best_target: Vector2 = _choose_best_navigation_target(target.global_position, desired_distance, should_probe_ring)
	_set_navigation_target(best_target)
	_perf_mark_scope(&"summon.set_nav_target_for_target", nav_target_start_us, {
		"probe_ring": should_probe_ring,
	})

func _choose_best_navigation_target(target_position: Vector2, desired_distance: float, probe_ring: bool) -> Vector2:
	if _navigation_agent == null:
		return target_position

	var nav_map: RID = _navigation_agent.get_navigation_map()
	if nav_map == RID():
		return target_position

	var projected_center: Vector2 = NavigationServer2D.map_get_closest_point(nav_map, target_position)
	if not probe_ring:
		return projected_center

	var direction_from_target: Vector2 = (global_position - target_position).normalized()
	if direction_from_target == Vector2.ZERO:
		direction_from_target = Vector2.RIGHT

	var desired_ring_distance: float = maxf(desired_distance, 8.0)
	var best_candidate: Vector2 = projected_center
	var best_score: float = projected_center.distance_to(target_position)
	var ring_points: int = maxi(nav_probe_ring_points, 4)
	var ring_distances: Array[float] = [desired_ring_distance, desired_ring_distance + maxf(nav_probe_ring_step, 4.0)]

	for ring_distance in ring_distances:
		for i in range(ring_points):
			var angle_offset: float = TAU * float(i) / float(ring_points)
			var ring_target: Vector2 = target_position + (direction_from_target.rotated(angle_offset) * ring_distance)
			var projected_ring: Vector2 = NavigationServer2D.map_get_closest_point(nav_map, ring_target)
			var candidate_score: float = projected_ring.distance_to(ring_target)
			if candidate_score < best_score:
				best_score = candidate_score
				best_candidate = projected_ring

	return best_candidate

func _clear_navigation_target() -> void:
	if not _uses_navigation_agent():
		return
	if _navigation_agent == null:
		return

	_navigation_agent.target_position = global_position

func _find_player() -> Node2D:
	var spatial_index := _resolve_spatial_index()
	if spatial_index != null:
		var nearest_player: Node2D = spatial_index.find_closest_in_group(global_position, &"players", -1.0, self)
		if nearest_player != null:
			return nearest_player

	var players: Array = get_tree().get_nodes_in_group("players")
	if not players.is_empty() and players[0] is Node2D:
		return players[0] as Node2D

	if get_tree().current_scene != null:
		var by_name: Node = get_tree().current_scene.find_child("player", true, false)
		if by_name is Node2D:
			return by_name as Node2D

	return null

func _find_random_enemy_nearby(radius: float) -> Node2D:
	var candidates: Array[Node2D] = _get_enemies_in_radius(radius)
	if candidates.is_empty():
		return _find_closest_enemy()

	return candidates[randi() % candidates.size()]

func _find_closest_enemy() -> Node2D:
	var find_start_us: int = Time.get_ticks_usec()
	var search_radius: float = maxf(enemy_target_search_radius, 0.0)
	if search_radius > 0.0:
		var nearby_enemies: Array[Node2D] = _get_enemies_in_radius(search_radius)
		if not nearby_enemies.is_empty():
			var closest_nearby: Node2D = _pick_closest_target(global_position, nearby_enemies)
			_perf_mark_scope(&"summon.find_closest_enemy", find_start_us, {
				"path": "radius_query",
				"candidates": nearby_enemies.size(),
			})
			return closest_nearby

	var spatial_index := _resolve_spatial_index()
	if spatial_index != null:
		var nearest: Node2D = spatial_index.find_closest_in_group(global_position, &"enemies", -1.0, self)
		_perf_mark_scope(&"summon.find_closest_enemy", find_start_us, {
			"path": "spatial_index",
		})
		return nearest

	var closest_enemy: Node2D
	var closest_distance_sq: float = INF

	for candidate in get_tree().get_nodes_in_group("enemies"):
		if not (candidate is Node2D):
			continue

		var enemy_2d: Node2D = candidate as Node2D
		var distance_sq: float = global_position.distance_squared_to(enemy_2d.global_position)
		if distance_sq < closest_distance_sq:
			closest_distance_sq = distance_sq
			closest_enemy = enemy_2d

	_perf_mark_scope(&"summon.find_closest_enemy", find_start_us, {
		"path": "group_scan",
	})
	return closest_enemy

func _perf_mark_scope(scope_name: StringName, start_us: int, metadata: Dictionary = {}) -> void:
	if not is_instance_valid(_perf_debug):
		return

	_perf_debug.add_scope_time_us(scope_name, Time.get_ticks_usec() - start_us, metadata)

func _perf_mark_physics_scope(scope_name: StringName, start_us: int, metadata: Dictionary = {}) -> void:
	if not is_instance_valid(_perf_debug):
		return

	_perf_debug.add_physics_scope_time_us(scope_name, Time.get_ticks_usec() - start_us, metadata)

func _perf_inc(counter_name: StringName, amount: int = 1) -> void:
	if not is_instance_valid(_perf_debug):
		return

	_perf_debug.increment_counter(counter_name, amount)

func _get_follow_enemy_scan_wait() -> float:
	var wait_time: float = maxf(follow_enemy_scan_interval, 0.1)
	if _is_far_from_player():
		wait_time *= maxf(far_lod_follow_refresh_multiplier, 1.0)
	return wait_time

func _should_refresh_auto_navigation_goal(nav_target: Node2D) -> bool:
	if nav_target == null:
		return false
	if _last_nav_goal_target != nav_target:
		return true
	if _navigation_agent == null:
		return true

	var desired_position: Vector2 = nav_target.global_position
	var current_target_position: Vector2 = _navigation_agent.target_position
	return current_target_position.distance_to(desired_position) >= maxf(follow_nav_target_min_shift, 4.0)

func _get_target_retarget_wait(target_position: Vector2) -> float:
	var base_wait: float = maxf(retarget_min_interval, 2.0)
	base_wait = maxf(base_wait, maxf(nav_goal_update_interval, 0.05))
	base_wait = maxf(base_wait, maxf(follow_nav_target_update_interval, 0.05))

	var extra_wait: float = 0.0
	var start_distance: float = maxf(retarget_far_distance_start, 0.0)
	var span_distance: float = maxf(retarget_far_distance_span, 1.0)
	var distance_to_target: float = global_position.distance_to(target_position)
	if distance_to_target > start_distance:
		var t: float = clampf((distance_to_target - start_distance) / span_distance, 0.0, 1.0)
		extra_wait = t * maxf(retarget_far_interval_bonus, 0.0)

	return base_wait + extra_wait

func _resolve_spatial_index() -> SpatialIndex2D:
	if is_instance_valid(_spatial_index):
		return _spatial_index

	_spatial_index = get_node_or_null("/root/SpatialIndex") as SpatialIndex2D
	return _spatial_index

func _is_far_from_player() -> bool:
	var threshold: float = maxf(far_lod_distance, 200.0)
	if is_instance_valid(_player_target):
		return global_position.distance_squared_to(_player_target.global_position) > threshold * threshold

	var player_target: Node2D = _find_player()
	if player_target == null:
		return false

	return global_position.distance_squared_to(player_target.global_position) > threshold * threshold

func _get_follow_nav_refresh_wait(follow_target: Vector2) -> float:
	var wait_time: float = maxf(follow_nav_target_update_interval, 0.08)
	if _is_far_from_player():
		wait_time *= maxf(far_lod_follow_refresh_multiplier, 1.0)

	var distance_to_follow_target: float = global_position.distance_to(follow_target)
	if distance_to_follow_target > maxf(command_follow_distance * 1.5, 110.0):
		wait_time *= 0.5

	return clampf(wait_time, 0.05, maxf(follow_player_retarget_interval, 0.2))

func _is_non_attacker_identity() -> bool:
	return summon_identity == ID_BUSH_BOY

func _draw() -> void:
	if not _is_command_selected:
		return

	var marker_center: Vector2 = Vector2(0.0, selected_marker_y_offset)
	draw_circle(marker_center, selected_marker_radius, selected_marker_fill_color)
	draw_arc(marker_center, selected_marker_radius, 0.0, TAU, maxi(selected_marker_arc_points, 8), selected_marker_line_color, selected_marker_line_width, true)
