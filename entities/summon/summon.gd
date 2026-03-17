extends CharacterBody2D
class_name SummonUnit

const CombatText = preload("res://scripts/floating_combat_text.gd")
const SummonCommandModule = preload("res://entities/summon/modules/summon_command_module.gd")
const SummonAiNavigationModule = preload("res://entities/summon/modules/summon_ai_navigation_module.gd")
const SummonCombatModule = preload("res://entities/summon/modules/summon_combat_module.gd")
const SummonVfxModule = preload("res://entities/summon/modules/summon_vfx_module.gd")
const SummonHealthModule = preload("res://entities/summon/modules/summon_health_module.gd")
const SummonProfileCatalogScript = preload("res://entities/summon/summon_profile_catalog.gd")

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
@export var nav_probe_ring_max_per_frame: int = 3
@export var nav_goal_update_interval: float = 0.45
@export var follow_player_retarget_interval: float = 10.0
@export var retarget_min_interval: float = 2.0
@export var retarget_far_distance_start: float = 900.0
@export var retarget_far_distance_span: float = 1400.0
@export var retarget_far_interval_bonus: float = 2.5
@export var follow_nav_target_update_interval: float = 0.32
@export var follow_nav_target_min_shift: float = 34.0
@export var nav_velocity_refresh_interval: float = 0.08
@export var follow_enemy_scan_interval: float = 0.75
@export var enemy_target_search_radius: float = 700.0
@export var ai_update_bucket_count: int = 4
@export var far_lod_distance: float = 1300.0
@export var far_lod_repath_multiplier: float = 2.0
@export var far_lod_nav_refresh_multiplier: float = 2.2
@export var far_lod_follow_refresh_multiplier: float = 3.0
@export var far_lod_velocity_refresh_multiplier: float = 2.0
@export var stuck_detection_enabled: bool = true
@export var stuck_check_window_seconds: float = 0.45
@export var stuck_min_distance_per_window: float = 8.0
@export var stuck_required_windows: int = 3
@export var stuck_recovery_cooldown_seconds: float = 1.0
@export var stuck_recovery_probe_points: int = 12
@export var stuck_recovery_probe_rings: int = 3
@export var stuck_recovery_probe_step: float = 52.0
@export var stuck_recovery_max_per_frame: int = 1
@export var stuck_recovery_max_samples: int = 12
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
var _time_to_nav_velocity_refresh: float = 0.0
var _cached_nav_velocity: Vector2 = Vector2.ZERO
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
var _command_module
var _ai_navigation_module
var _combat_module
var _vfx_module_impl
var _health_module

static var _world_vfx_spawn_frame: int = -1
static var _world_vfx_spawn_count: int = 0
static var _projectile_spawn_frame: int = -1
static var _projectile_spawn_count: int = 0
static var _stuck_recovery_frame: int = -1
static var _stuck_recovery_count: int = 0

@onready var _health_bar: ProgressBar = get_node_or_null("HealthBar") as ProgressBar
@onready var _navigation_agent: NavigationAgent2D = get_node_or_null("NavigationAgent2D") as NavigationAgent2D
@onready var _sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D

func _ensure_modules() -> void:
	if _command_module == null:
		_command_module = SummonCommandModule.new(self)
	if _ai_navigation_module == null:
		_ai_navigation_module = SummonAiNavigationModule.new(self)
	if _combat_module == null:
		_combat_module = SummonCombatModule.new(self)
	if _vfx_module_impl == null:
		_vfx_module_impl = SummonVfxModule.new(self)
	if _health_module == null:
		_health_module = SummonHealthModule.new(self)

func _touch_delegated_private_state() -> void:
	# These fields are consumed by extracted modules; touching them here avoids false "unused private" warnings.
	_current_health = _current_health
	_move_target_position = _move_target_position
	_hold_toggle_enabled = _hold_toggle_enabled
	_last_follow_nav_target = _last_follow_nav_target
	_follow_snapshot_target = _follow_snapshot_target
	_cached_nav_velocity = _cached_nav_velocity
	_has_split_once = _has_split_once
	_vfx_fire_cone = _vfx_fire_cone
	_vfx_chain_lightning = _vfx_chain_lightning
	_vfx_acorn_projectile = _vfx_acorn_projectile
	_vfx_spring_projectile = _vfx_spring_projectile
	_attack_tilt_tween = _attack_tilt_tween
	_stuck_window_distance_accum = _stuck_window_distance_accum
	_stuck_window_failures = _stuck_window_failures
	_world_vfx_spawn_frame = _world_vfx_spawn_frame
	_world_vfx_spawn_count = _world_vfx_spawn_count
	_projectile_spawn_frame = _projectile_spawn_frame
	_projectile_spawn_count = _projectile_spawn_count
	_stuck_recovery_frame = _stuck_recovery_frame
	_stuck_recovery_count = _stuck_recovery_count
	_health_bar = _health_bar

func _ready() -> void:
	_ensure_modules()
	_touch_delegated_private_state()
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
	_health_module.initialize_health(true)
	_time_to_repath = randf_range(0.0, maxf(repath_interval, 0.05))
	_time_to_nav_goal_refresh = randf_range(0.0, maxf(nav_goal_update_interval, 0.05))
	_time_to_follow_nav_refresh = randf_range(0.0, maxf(follow_nav_target_update_interval, 0.05))
	_time_to_nav_velocity_refresh = randf_range(0.0, maxf(nav_velocity_refresh_interval, 0.01))
	_time_to_follow_enemy_scan = randf_range(0.0, maxf(follow_enemy_scan_interval, 0.1))
	_time_to_next_attack = randf_range(0.0, maxf(attack_cooldown, 0.05) * 0.3)
	_health_bar_visible_time_left = 0.0
	_stuck_check_time_left = randf_range(0.0, maxf(stuck_check_window_seconds, 0.05))
	_update_health_bar()

func set_summon_identity(identity: StringName) -> void:
	summon_identity = identity
	_apply_summon_identity_profile()

func _apply_summon_identity_profile() -> void:
	var profile: SummonIdentityProfile = SummonProfileCatalogScript.get_profile(summon_identity)
	if profile == null:
		# Preserve existing defaults for unknown IDs.
		return

	move_speed = profile.move_speed
	attack_range = profile.attack_range
	attack_damage = profile.attack_damage
	attack_cooldown = profile.attack_cooldown
	max_health = profile.max_health
	if profile.follow_player_distance_override >= 0.0:
		follow_player_distance = profile.follow_player_distance_override

func _physics_process(delta: float) -> void:
	var physics_start_us: int = Time.get_ticks_usec()
	_perf_inc(&"summon.physics_ticks")
	if _command_mode == CommandMode.FOLLOW:
		_perf_inc(&"summon.follow_mode_ticks")

	_time_to_repath -= delta
	_time_to_nav_goal_refresh = maxf(_time_to_nav_goal_refresh - delta, 0.0)
	_time_to_follow_nav_refresh = maxf(_time_to_follow_nav_refresh - delta, 0.0)
	_time_to_nav_velocity_refresh = maxf(_time_to_nav_velocity_refresh - delta, 0.0)
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
	_perf_mark_physics_scope(&"summon.physics_total", physics_start_us)

func set_move_target(target_position: Vector2) -> void:
	_ensure_modules()
	_command_module.set_move_target(target_position)

func set_hold_position(should_hold: bool) -> void:
	_ensure_modules()
	_command_module.set_hold_position(should_hold)

func clear_manual_command() -> void:
	_ensure_modules()
	_command_module.clear_manual_command()

func set_follow_player() -> void:
	_ensure_modules()
	_command_module.set_follow_player()

func set_auto_behavior() -> void:
	_ensure_modules()
	_command_module.set_auto_behavior()

func set_selected_for_command(is_selected: bool) -> void:
	if _is_command_selected == is_selected:
		return

	_is_command_selected = is_selected
	_refresh_health_bar_visibility()
	queue_redraw()

func is_holding_position() -> bool:
	_ensure_modules()
	return _command_module.is_holding_position()

func is_hold_toggle_enabled() -> bool:
	_ensure_modules()
	return _command_module.is_hold_toggle_enabled()

func get_command_mode_name() -> String:
	_ensure_modules()
	return _command_module.get_command_mode_name()

func _handle_move_command() -> void:
	_ensure_modules()
	_ai_navigation_module.handle_move_command()

func _handle_hold_command() -> void:
	_ensure_modules()
	_ai_navigation_module.handle_hold_command()

func _handle_follow_command() -> void:
	_ensure_modules()
	_ai_navigation_module.handle_follow_command()

func _handle_non_attacker_auto() -> void:
	_ensure_modules()
	_ai_navigation_module.handle_non_attacker_auto()

func _update_follow_navigation_target(player_position: Vector2) -> void:
	_ensure_modules()
	_ai_navigation_module.update_follow_navigation_target(player_position)

func _get_follow_formation_target(player_position: Vector2) -> Vector2:
	_ensure_modules()
	return _ai_navigation_module.get_follow_formation_target(player_position)

func _try_attack_in_range() -> bool:
	_ensure_modules()
	return _combat_module.try_attack_in_range()

func _update_passive_archetype_behavior() -> void:
	_ensure_modules()
	_combat_module.update_passive_archetype_behavior()

func _perform_attack(target: Node2D) -> void:
	_ensure_modules()
	_combat_module.perform_attack(target)

func _play_attack_tilt_animation() -> void:
	_ensure_modules()
	_combat_module.play_attack_tilt_animation()

func _attack_baby_dragon(primary_target: Node2D) -> void:
	_ensure_modules()
	_combat_module.attack_baby_dragon(primary_target)

func _attack_slime(target: Node2D) -> void:
	_ensure_modules()
	_combat_module.attack_slime(target)

func _attack_spark_goblin(target: Node2D) -> void:
	_ensure_modules()
	_combat_module.attack_spark_goblin(target)

func _find_next_chain_target(from_position: Vector2, visited: Dictionary) -> Node2D:
	_ensure_modules()
	return _combat_module.find_next_chain_target(from_position, visited)

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
	_ensure_modules()
	_combat_module.attack_jack(target)

func _attack_mushroom_knight(target: Node2D) -> void:
	_ensure_modules()
	_combat_module.attack_mushroom_knight(target)

func _attack_acorn_spitter(target: Node2D) -> void:
	_ensure_modules()
	_combat_module.attack_acorn_spitter(target)

func _attack_bee_swarm(target: Node2D) -> void:
	_ensure_modules()
	_combat_module.attack_bee_swarm(target)

func _attack_rooter(target: Node2D) -> void:
	_ensure_modules()
	_combat_module.attack_rooter(target)

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

	if target is House:
		(target as House).take_damage(damage)

func take_hit(amount: float, source: Node2D = null, options: Dictionary = {}) -> void:
	_ensure_modules()
	_health_module.take_hit(amount, source, options)

func take_damage(amount: float) -> void:
	_ensure_modules()
	_health_module.take_damage(amount)

func heal(amount: float) -> void:
	_ensure_modules()
	_health_module.heal(amount)

func _die() -> void:
	_ensure_modules()
	_health_module.die()

func _should_split_on_death() -> bool:
	_ensure_modules()
	return _health_module.should_split_on_death()

func _spawn_split_children() -> void:
	_ensure_modules()
	_health_module.spawn_split_children()

func _update_health_bar() -> void:
	_ensure_modules()
	_health_module.update_health_bar()

func _request_health_bar_visibility(duration: float = -1.0) -> void:
	_ensure_modules()
	_health_module.request_health_bar_visibility(duration)

func _refresh_health_bar_visibility() -> void:
	_ensure_modules()
	_health_module.refresh_health_bar_visibility()

func _is_ai_bucket_turn() -> bool:
	var bucket_count: int = maxi(ai_update_bucket_count, 1)
	if bucket_count <= 1:
		return true

	var frame_bucket: int = Engine.get_physics_frames() % bucket_count
	var summon_bucket: int = int(get_instance_id() % bucket_count)
	return frame_bucket == summon_bucket

func _launch_projectile_attack(target: Node2D, hit_options: Dictionary = {}) -> void:
	_ensure_modules()
	_vfx_module_impl.launch_projectile_attack(target, hit_options)

func _spawn_chain_lightning_vfx(from_position: Vector2, to_position: Vector2) -> void:
	_ensure_modules()
	_vfx_module_impl.spawn_chain_lightning_vfx(from_position, to_position)

func _load_vfx_assets() -> void:
	_ensure_modules()
	_vfx_module_impl.load_vfx_assets()

func _spawn_world_vfx(texture: Texture2D, world_position: Vector2, rotation_radians: float = 0.0, sprite_scale: Vector2 = Vector2.ONE, lifetime: float = 0.2, use_corner_anchor: bool = false, corner_anchor_uv: Vector2 = Vector2.ZERO) -> void:
	_ensure_modules()
	_vfx_module_impl.spawn_world_vfx(texture, world_position, rotation_radians, sprite_scale, lifetime, use_corner_anchor, corner_anchor_uv)

func _can_spawn_world_vfx_this_frame() -> bool:
	_ensure_modules()
	return _vfx_module_impl.can_spawn_world_vfx_this_frame()

func _can_spawn_projectile_this_frame() -> bool:
	_ensure_modules()
	return _vfx_module_impl.can_spawn_projectile_this_frame()

func _move_towards(target_position: Vector2) -> void:
	_ensure_modules()
	_ai_navigation_module.move_towards(target_position)

func _update_stuck_recovery(delta: float, pre_move_position: Vector2) -> void:
	_ensure_modules()
	_ai_navigation_module.update_stuck_recovery(delta, pre_move_position)

func _get_current_navigation_goal() -> Vector2:
	_ensure_modules()
	return _ai_navigation_module.get_current_navigation_goal()

func _trigger_stuck_recovery(goal_position: Vector2) -> void:
	_ensure_modules()
	_ai_navigation_module.trigger_stuck_recovery(goal_position)

func _choose_stuck_recovery_waypoint(goal_position: Vector2) -> Vector2:
	_ensure_modules()
	return _ai_navigation_module.choose_stuck_recovery_waypoint(goal_position)

func _uses_navigation_agent() -> bool:
	_ensure_modules()
	return _ai_navigation_module.uses_navigation_agent()

func _get_navigation_velocity(target_position: Vector2) -> Vector2:
	_ensure_modules()
	return _ai_navigation_module.get_navigation_velocity(target_position)

func _get_nav_velocity_refresh_wait() -> float:
	_ensure_modules()
	return _ai_navigation_module.get_nav_velocity_refresh_wait()

func _set_navigation_target(target_position: Vector2) -> void:
	_ensure_modules()
	_ai_navigation_module.set_navigation_target(target_position)

func _set_navigation_target_for_target(target: Node2D) -> void:
	_ensure_modules()
	_ai_navigation_module.set_navigation_target_for_target(target)

func _choose_best_navigation_target(target_position: Vector2, desired_distance: float, probe_ring: bool) -> Vector2:
	_ensure_modules()
	return _ai_navigation_module.choose_best_navigation_target(target_position, desired_distance, probe_ring)

func _try_consume_nav_probe_budget() -> bool:
	_ensure_modules()
	return _ai_navigation_module.try_consume_nav_probe_budget()

func _try_consume_stuck_recovery_budget() -> bool:
	_ensure_modules()
	return _ai_navigation_module.try_consume_stuck_recovery_budget()

func _clear_navigation_target() -> void:
	_ensure_modules()
	_ai_navigation_module.clear_navigation_target()

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
	_ensure_modules()
	return _ai_navigation_module.get_follow_enemy_scan_wait()

func _should_refresh_auto_navigation_goal(nav_target: Node2D) -> bool:
	_ensure_modules()
	return _ai_navigation_module.should_refresh_auto_navigation_goal(nav_target)

func _get_target_retarget_wait(target_position: Vector2) -> float:
	_ensure_modules()
	return _ai_navigation_module.get_target_retarget_wait(target_position)

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
	_ensure_modules()
	return _ai_navigation_module.get_follow_nav_refresh_wait(follow_target)

func _is_non_attacker_identity() -> bool:
	return summon_identity == ID_BUSH_BOY

func _draw() -> void:
	if not _is_command_selected:
		return

	var marker_center: Vector2 = Vector2(0.0, selected_marker_y_offset)
	draw_circle(marker_center, selected_marker_radius, selected_marker_fill_color)
	draw_arc(marker_center, selected_marker_radius, 0.0, TAU, maxi(selected_marker_arc_points, 8), selected_marker_line_color, selected_marker_line_width, true)
