extends CharacterBody2D
class_name EnemyUnit

const CombatText = preload("res://scripts/floating_combat_text.gd")
const HEALTH_COMPONENT_SCRIPT = preload("res://entities/shared/health_component.gd")
const NAVIGATION_GOAL_PROBE_SCRIPT = preload("res://entities/shared/navigation_goal_probe.gd")

const ENEMY_ARCHETYPE_BASIC_RAIDER: StringName = &"basic_raider"
const ENEMY_ARCHETYPE_FAST_RAIDER: StringName = &"fast_raider"
const ENEMY_ARCHETYPE_TANK_RAIDER: StringName = &"tank_raider"
const ENEMY_ARCHETYPE_RANGED_RAIDER: StringName = &"ranged_raider"
const ENEMY_ARCHETYPE_HEALING_RAIDER: StringName = &"healing_raider"
const ENEMY_ARCHETYPE_TRENCHCOAT_GOBLIN: StringName = &"trenchcoat_goblin"
const ENEMY_ARCHETYPE_GOBLIN: StringName = &"goblin"

const DEFAULT_ENEMY_TEXTURE_PATH: String = "res://assets/characters/enemy.png"
const ENEMY_PROJECTILE_TEXTURE_PATH: String = "res://assets/characters/raider_projectile.png"
const ENEMY_SCENE_PATH: String = "res://entities/enemy/enemy.tscn"
const RANGED_PROJECTILE_SCENE: PackedScene = preload("res://entities/summon/summon_attack.tscn")

@export var move_speed: float = 90.0
@export var repath_interval: float = 0.3
@export var target_reach_distance: float = 32.0
@export var target_stop_padding: float = 2.0
@export var nearby_target_groups: PackedStringArray = ["summons", "players"]
@export var fallback_target_group: StringName = &"house"
@export var nearby_target_radius: float = 270.0
@export var melee_damage: float = 15.0
@export var melee_attack_cooldown: float = 1.0
@export var melee_attack_extra_range: float = 6.0
@export var max_health: float = 100.0
@export var nav_path_desired_distance: float = 12.0
@export var nav_target_desired_distance: float = 16.0
@export var nav_probe_ring_points: int = 8
@export var nav_probe_ring_step: float = 16.0
@export var nav_probe_ring_max_per_frame: int = 3
@export var nav_goal_update_interval: float = 0.45
@export var visibility_check_interval: float = 0.2
@export var ai_update_bucket_count: int = 4
@export var far_lod_distance: float = 1300.0
@export var far_lod_repath_multiplier: float = 2.0
@export var far_lod_visibility_multiplier: float = 2.0
@export var status_tick_interval: float = 0.2
@export var max_sting_stacks: int = 8
@export var knockback_decay: float = 900.0
@export var health_bar_show_duration: float = 2.0
@export var always_show_health_bar: bool = false
@export var enemy_archetype: StringName = ENEMY_ARCHETYPE_BASIC_RAIDER
@export var apply_archetype_on_ready: bool = true
@export var ranged_attack_range: float = 340.0
@export var ranged_damage: float = 13.0
@export var ranged_attack_cooldown: float = 1.3
@export var ranged_reposition_padding: float = 20.0
@export var ranged_projectile_speed: float = 350.0
@export var healer_keep_away_distance: float = 170.0
@export var healer_reposition_padding: float = 28.0
@export var healer_aura_radius: float = 220.0
@export var healer_heal_per_second: float = 12.0
@export var healer_tick_interval: float = 0.4
@export var healer_max_allies_per_tick: int = 6
@export var split_spawn_count: int = 4
@export var split_spawn_spread_radius: float = 26.0
@export var idle_bounce_speed: float = 3.5
@export var idle_bounce_height: float = 1.6
@export var attack_tilt_angle_degrees: float = 8.0
@export var attack_tilt_duration: float = 0.12

const PHYSICS_LAYER_WORLD: int = 1 << 0
const PHYSICS_LAYER_ENEMY: int = 1 << 2
const VFX_BURN_EFFECT_PATH: String = "res://assets/vfx/burn_effect.png"
const VFX_ROOTED_PATH: String = "res://assets/vfx/rooted.png"
const VFX_HIT_MARKER_PATH: String = "res://assets/vfx/hit_marker.png"
const VFX_KNOCKBACK_PATH: String = "res://assets/vfx/knockback.png"

var _current_target: Node2D
var _time_to_repath: float = 0.0
var _time_to_next_melee_hit: float = 0.0
var _current_health: float = 0.0
var _health_component: HealthComponent = HEALTH_COMPONENT_SCRIPT.new()
var _time_to_nav_goal_refresh: float = 0.0
var _time_to_visibility_refresh: float = 0.0
var _last_nav_goal_target: Node2D
var _cached_has_clear_path: bool = false
var _burn_dps: float = 0.0
var _burn_time_left: float = 0.0
var _sting_stacks: int = 0
var _sting_dps_per_stack: float = 0.0
var _sting_time_left: float = 0.0
var _sting_max_stack_burst_damage: float = 0.0
var _sting_hits_toward_burst: int = 0
var _root_time_left: float = 0.0
var _status_tick_time_left: float = 0.0
var _external_push_velocity: Vector2 = Vector2.ZERO
var _health_bar_visible_time_left: float = 0.0
var _time_to_next_ranged_shot: float = 0.0
var _time_to_next_heal_tick: float = 0.0
var _burn_vfx_sprite: Sprite2D
var _root_vfx_sprite: Sprite2D
var _vfx_burn_effect: Texture2D
var _vfx_rooted: Texture2D
var _vfx_hit_marker: Texture2D
var _vfx_knockback: Texture2D
var _ranged_projectile_texture: Texture2D
var _attack_tilt_tween: Tween
var _spatial_index: SpatialIndex2D
var _vfx_pool: VfxPool2D
var _perf_debug: PerfDebugService

static var _vfx_spawn_frame: int = -1
static var _vfx_spawn_count: int = 0
static var _texture_cache: Dictionary = {}
static var _enemy_scene_cache: PackedScene
const MAX_VFX_SPAWNS_PER_FRAME: int = 24

@onready var _health_bar: ProgressBar = get_node_or_null("HealthBar") as ProgressBar
@onready var _navigation_agent: NavigationAgent2D = get_node_or_null("NavigationAgent2D") as NavigationAgent2D
@onready var _sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D

func _ready() -> void:
	_perf_debug = get_node_or_null("/root/PerfDebug") as PerfDebugService
	_load_vfx_assets()
	if apply_archetype_on_ready:
		_apply_enemy_archetype(enemy_archetype)
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = PHYSICS_LAYER_ENEMY
	collision_mask = PHYSICS_LAYER_WORLD
	add_to_group("enemies")
	if _navigation_agent != null:
		_navigation_agent.path_desired_distance = maxf(nav_path_desired_distance, 4.0)
		_navigation_agent.target_desired_distance = maxf(nav_target_desired_distance, 6.0)
		_navigation_agent.max_speed = maxf(move_speed, 1.0)
		_navigation_agent.set_navigation_map(get_world_2d().navigation_map)
	_spatial_index = get_node_or_null("/root/SpatialIndex") as SpatialIndex2D
	_vfx_pool = get_node_or_null("/root/VfxPool") as VfxPool2D
	_health_component.initialize(max_health, true)
	_current_health = _health_component.current_health
	_time_to_repath = randf_range(0.0, maxf(repath_interval, 0.05))
	_time_to_nav_goal_refresh = randf_range(0.0, maxf(nav_goal_update_interval, 0.05))
	_time_to_visibility_refresh = randf_range(0.0, maxf(visibility_check_interval, 0.05))
	_time_to_next_melee_hit = randf_range(0.0, maxf(melee_attack_cooldown, 0.05) * 0.3)
	_time_to_next_ranged_shot = randf_range(0.0, maxf(ranged_attack_cooldown, 0.05) * 0.4)
	_time_to_next_heal_tick = randf_range(0.0, maxf(healer_tick_interval, 0.1))
	_health_bar_visible_time_left = 0.0
	_update_health_bar()
	_setup_status_vfx()

func set_enemy_archetype(archetype: StringName) -> void:
	enemy_archetype = archetype
	if not is_inside_tree():
		return

	_apply_enemy_archetype(enemy_archetype)
	_sync_health_max_from_export()
	_current_health = _health_component.current_health
	_update_health_bar()

func _physics_process(delta: float) -> void:
	var physics_start_us: int = Time.get_ticks_usec()
	_perf_inc(&"enemy.physics_ticks")

	_time_to_repath -= delta
	_time_to_nav_goal_refresh = maxf(_time_to_nav_goal_refresh - delta, 0.0)
	_time_to_visibility_refresh = maxf(_time_to_visibility_refresh - delta, 0.0)
	_time_to_next_melee_hit = maxf(_time_to_next_melee_hit - delta, 0.0)
	_time_to_next_ranged_shot = maxf(_time_to_next_ranged_shot - delta, 0.0)
	_time_to_next_heal_tick = maxf(_time_to_next_heal_tick - delta, 0.0)
	var previous_health_bar_visible_time_left: float = _health_bar_visible_time_left
	_health_bar_visible_time_left = maxf(_health_bar_visible_time_left - delta, 0.0)
	_update_status_effects(delta)
	_update_healer_aura(delta)
	_update_idle_bounce()
	_external_push_velocity = _external_push_velocity.move_toward(Vector2.ZERO, maxf(knockback_decay, 0.0) * delta)
	if previous_health_bar_visible_time_left > 0.0 and _health_bar_visible_time_left <= 0.0:
		_refresh_health_bar_visibility()
	var is_rooted: bool = _root_time_left > 0.0
	var is_far_lod: bool = _is_far_from_player()
	var repath_wait: float = maxf(repath_interval, 0.05)
	var visibility_wait: float = maxf(visibility_check_interval, 0.05)
	if is_far_lod:
		repath_wait *= maxf(far_lod_repath_multiplier, 1.0)
		visibility_wait *= maxf(far_lod_visibility_multiplier, 1.0)
	if _time_to_repath <= 0.0 and _is_ai_bucket_turn():
		var repath_start_us: int = Time.get_ticks_usec()
		var nearby_target := _find_closest_target_in_groups(nearby_target_groups, nearby_target_radius)
		if is_instance_valid(nearby_target):
			_current_target = nearby_target
		else:
			_current_target = _find_closest_target_in_group(fallback_target_group)

		if is_instance_valid(_current_target):
			if _last_nav_goal_target != _current_target or _time_to_nav_goal_refresh <= 0.0:
				_set_navigation_target_for_target(_current_target)
				_last_nav_goal_target = _current_target
				_time_to_nav_goal_refresh = maxf(nav_goal_update_interval, 0.05)
			_cached_has_clear_path = _has_clear_path_to_target(_current_target)
			_time_to_visibility_refresh = visibility_wait
		else:
			_last_nav_goal_target = null
			_time_to_nav_goal_refresh = 0.0
			_time_to_visibility_refresh = 0.0
			_cached_has_clear_path = false
			_clear_navigation_target()
		_time_to_repath = repath_wait
		_perf_mark_scope(&"enemy.repath_block", repath_start_us)

	if is_instance_valid(_current_target):
		if _time_to_visibility_refresh <= 0.0:
			_cached_has_clear_path = _has_clear_path_to_target(_current_target)
			_time_to_visibility_refresh = visibility_wait

		var target_center_distance: float = global_position.distance_to(_current_target.global_position)
		var target_distance: float = _get_target_surface_distance(_current_target, target_center_distance)
		# Stop/attack thresholds are measured from target collider surface distance.
		var stop_distance: float = _get_surface_stop_distance(_current_target)
		var allow_attack_without_clear_path: bool = _current_target.is_in_group("house")
		var can_engage: bool = _cached_has_clear_path or allow_attack_without_clear_path
		var is_threat_target: bool = _current_target.is_in_group("summons") or _current_target.is_in_group("players")
		var is_ranged_archetype: bool = _is_ranged_archetype()
		var is_healer_archetype: bool = _is_healer_archetype()
		if is_rooted:
			velocity = Vector2.ZERO
		elif is_healer_archetype and is_threat_target:
			velocity = _get_healer_spacing_velocity(_current_target, target_distance)
		elif is_ranged_archetype:
			var ranged_stop_distance: float = maxf(ranged_attack_range - ranged_reposition_padding, stop_distance)
			if target_distance > ranged_stop_distance or not can_engage:
				velocity = _get_navigation_velocity(_current_target.global_position)
			else:
				velocity = Vector2.ZERO
		elif target_distance > stop_distance or not can_engage:
			velocity = _get_navigation_velocity(_current_target.global_position)
		else:
			velocity = Vector2.ZERO

		if not is_rooted:
			if is_ranged_archetype:
				_try_ranged_attack(_current_target, target_distance, _cached_has_clear_path, allow_attack_without_clear_path)
			elif not is_healer_archetype:
				_try_melee_attack(_current_target, target_distance, stop_distance, _cached_has_clear_path, allow_attack_without_clear_path)
	else:
		velocity = Vector2.ZERO
		_clear_navigation_target()

	velocity += _external_push_velocity
	move_and_slide()
	_perf_mark_physics_scope(&"enemy.physics_total", physics_start_us)

func _is_ai_bucket_turn() -> bool:
	var bucket_count: int = maxi(ai_update_bucket_count, 1)
	if bucket_count <= 1:
		return true

	var frame_bucket: int = Engine.get_physics_frames() % bucket_count
	var enemy_bucket: int = int(get_instance_id() % bucket_count)
	return frame_bucket == enemy_bucket

func _get_navigation_velocity(_target_position: Vector2) -> Vector2:
	if _navigation_agent == null or _navigation_agent.get_navigation_map() == RID():
		return Vector2.ZERO

	if _navigation_agent.is_navigation_finished():
		return Vector2.ZERO

	var next_path_position: Vector2 = _navigation_agent.get_next_path_position()
	return global_position.direction_to(next_path_position) * move_speed

func _set_navigation_target(target_position: Vector2) -> void:
	if _navigation_agent == null:
		return

	if _navigation_agent.target_position.distance_to(target_position) <= 6.0:
		return

	_navigation_agent.target_position = target_position

func _set_navigation_target_for_target(target: Node2D) -> void:
	var nav_target_start_us: int = Time.get_ticks_usec()
	if target == null:
		_perf_mark_scope(&"enemy.set_nav_target_for_target", nav_target_start_us, {
			"status": "missing_target",
		})
		return

	if _navigation_agent == null or _navigation_agent.get_navigation_map() == RID():
		_set_navigation_target(target.global_position)
		_perf_mark_scope(&"enemy.set_nav_target_for_target", nav_target_start_us, {
			"status": "fallback_direct_target",
		})
		return

	var desired_stop_distance: float = _get_stop_distance(target)
	var use_ring_probe: bool = target.is_in_group("house") and not _is_far_from_player() and _try_consume_nav_probe_budget()
	var best_target: Vector2 = _choose_best_navigation_target(target.global_position, desired_stop_distance, use_ring_probe)
	_set_navigation_target(best_target)
	_perf_mark_scope(&"enemy.set_nav_target_for_target", nav_target_start_us, {
		"probe_ring": use_ring_probe,
	})

func _choose_best_navigation_target(target_position: Vector2, desired_distance: float, probe_ring: bool) -> Vector2:
	return NAVIGATION_GOAL_PROBE_SCRIPT.choose_best_navigation_target(
		_navigation_agent,
		global_position,
		target_position,
		desired_distance,
		probe_ring,
		nav_probe_ring_points
	)

func _try_consume_nav_probe_budget() -> bool:
	return NAVIGATION_GOAL_PROBE_SCRIPT.try_consume_probe_budget(&"enemy_nav_probe", nav_probe_ring_max_per_frame)

func _clear_navigation_target() -> void:
	if _navigation_agent == null:
		return

	_navigation_agent.target_position = global_position

func _update_healer_aura(_delta: float) -> void:
	if not _is_healer_archetype():
		return
	if healer_heal_per_second <= 0.0 or healer_aura_radius <= 0.0:
		return
	if _time_to_next_heal_tick > 0.0:
		return

	var tick_interval: float = maxf(healer_tick_interval, 0.1)
	_time_to_next_heal_tick = tick_interval
	var heal_amount: float = healer_heal_per_second * tick_interval
	if heal_amount <= 0.0:
		return

	for ally in _find_nearby_allied_enemies(healer_aura_radius, healer_max_allies_per_tick):
		ally.heal(heal_amount)

func _find_nearby_allied_enemies(radius: float, max_targets: int) -> Array[EnemyUnit]:
	var allies: Array[EnemyUnit] = []
	var radius_sq: float = radius * radius
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if not (candidate is EnemyUnit):
			continue

		var ally: EnemyUnit = candidate as EnemyUnit
		if ally == self:
			continue
		if ally._health_component.is_dead:
			continue

		var distance_sq: float = global_position.distance_squared_to(ally.global_position)
		if distance_sq > radius_sq:
			continue

		allies.append(ally)
		if max_targets > 0 and allies.size() >= max_targets:
			break

	return allies

func _get_healer_spacing_velocity(target: Node2D, target_distance: float) -> Vector2:
	if target == null:
		return Vector2.ZERO

	var keep_away_distance: float = maxf(healer_keep_away_distance, 48.0)
	var inner_distance: float = keep_away_distance - maxf(healer_reposition_padding, 0.0)
	var outer_distance: float = keep_away_distance + maxf(healer_reposition_padding, 0.0)

	if target_distance < inner_distance:
		return target.global_position.direction_to(global_position) * move_speed
	if target_distance > outer_distance:
		return _get_navigation_velocity(target.global_position)
	return Vector2.ZERO

func _try_melee_attack(target: Node2D, target_distance: float, stop_distance: float, has_clear_path: bool, allow_without_clear_path: bool) -> void:
	if melee_damage <= 0.0 or melee_attack_cooldown <= 0.0:
		return
	if _time_to_next_melee_hit > 0.0:
		return
	if not has_clear_path and not allow_without_clear_path:
		return

	# Keep melee tight around collision contact while allowing a small tolerance.
	var melee_distance := stop_distance + melee_attack_extra_range
	if target_distance > melee_distance:
		return

	_time_to_next_melee_hit = melee_attack_cooldown
	_play_attack_tilt()
	if target is Player:
		(target as Player).take_damage(melee_damage)
		return
	if target is SummonUnit:
		(target as SummonUnit).take_damage(melee_damage)
		return
	if target is House:
		(target as House).take_damage(melee_damage)

func _try_ranged_attack(target: Node2D, target_distance: float, has_clear_path: bool, allow_without_clear_path: bool) -> void:
	if target == null:
		return
	if ranged_damage <= 0.0 or ranged_attack_cooldown <= 0.0:
		return
	if ranged_attack_range <= 0.0:
		return
	if _time_to_next_ranged_shot > 0.0:
		return
	if target_distance > ranged_attack_range:
		return
	if not has_clear_path and not allow_without_clear_path:
		return

	var projectile_parent: Node = get_tree().current_scene
	if projectile_parent == null:
		projectile_parent = get_parent()
	if projectile_parent == null:
		return

	var hit_options: Dictionary = {
		"projectile_speed": ranged_projectile_speed,
	}
	if _ranged_projectile_texture != null:
		hit_options["projectile_texture"] = _ranged_projectile_texture

	var projectile: SummonAttackProjectile = SummonAttackProjectile.spawn(
		RANGED_PROJECTILE_SCENE,
		projectile_parent,
		global_position,
		target,
		ranged_damage,
		self,
		hit_options
	)
	if projectile != null:
		_time_to_next_ranged_shot = ranged_attack_cooldown
		_play_attack_tilt()

func _has_clear_path_to_target(target: Node2D) -> bool:
	var los_start_us: int = Time.get_ticks_usec()
	if target == null:
		_perf_mark_scope(&"enemy.has_clear_path", los_start_us, {
			"status": "missing_target",
		})
		return false

	var world_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	if world_state == null:
		_perf_mark_scope(&"enemy.has_clear_path", los_start_us, {
			"status": "no_world_state",
		})
		return true

	var query := PhysicsRayQueryParameters2D.create(global_position, target.global_position)
	query.collision_mask = PHYSICS_LAYER_WORLD
	query.exclude = [get_rid()]

	var hit: Dictionary = world_state.intersect_ray(query)
	if hit.is_empty():
		_perf_mark_scope(&"enemy.has_clear_path", los_start_us, {
			"result": "clear",
		})
		return true

	var collider: Variant = hit.get("collider")
	var has_clear_path: bool = collider == target
	_perf_mark_scope(&"enemy.has_clear_path", los_start_us, {
		"result": "hit",
		"clear": has_clear_path,
	})
	return has_clear_path

func take_hit(amount: float, source: Node2D = null, options: Dictionary = {}) -> void:
	_apply_damage(amount)
	if amount > 0.0:
		_spawn_local_vfx(_vfx_hit_marker, Vector2(0.0, -20.0), 0.14, Vector2.ONE)

	if options.has("burn_dps") and options.has("burn_duration"):
		var burn_dps: float = float(options.get("burn_dps", 0.0))
		var burn_duration: float = float(options.get("burn_duration", 0.0))
		if burn_dps > 0.0 and burn_duration > 0.0:
			_burn_dps = maxf(_burn_dps, burn_dps)
			_burn_time_left = maxf(_burn_time_left, burn_duration)

	if options.has("sting_stacks_add"):
		var stacks_to_add: int = int(options.get("sting_stacks_add", 0))
		if stacks_to_add > 0:
			var previous_sting_stacks: int = _sting_stacks
			_sting_stacks = mini(_sting_stacks + stacks_to_add, maxi(max_sting_stacks, 1))
			_sting_time_left = maxf(_sting_time_left, float(options.get("sting_duration", 2.0)))
			_sting_dps_per_stack = maxf(_sting_dps_per_stack, float(options.get("sting_dps_per_stack", 1.0)))
			_sting_max_stack_burst_damage = maxf(_sting_max_stack_burst_damage, float(options.get("sting_max_stack_burst_damage", 0.0)))

			if _sting_stacks >= max_sting_stacks and _sting_max_stack_burst_damage > 0.0:
				var burst_interval: int = maxi(max_sting_stacks, 1)
				var hits_to_cap: int = maxi(max_sting_stacks - previous_sting_stacks, 0)
				var overflow_hits: int = maxi(stacks_to_add - hits_to_cap, 0)
				var counted_hits: int = stacks_to_add
				if previous_sting_stacks < max_sting_stacks:
					counted_hits = hits_to_cap + overflow_hits

				_sting_hits_toward_burst += counted_hits
				while _sting_hits_toward_burst >= burst_interval:
					_sting_hits_toward_burst -= burst_interval
					_apply_damage(_sting_max_stack_burst_damage)
					_spawn_local_vfx(_vfx_hit_marker, Vector2(0.0, -28.0), 0.18, Vector2(1.2, 1.2))

	if options.has("root_duration"):
		var root_duration: float = float(options.get("root_duration", 0.0))
		if root_duration > 0.0:
			_root_time_left = maxf(_root_time_left, root_duration)
			_spawn_local_vfx(_vfx_rooted, Vector2(0.0, 8.0), 0.18, Vector2(1.0, 1.0))

	if options.has("knockback_force") and is_instance_valid(source):
		var knockback_force: float = float(options.get("knockback_force", 0.0))
		if knockback_force > 0.0:
			var push_direction: Vector2 = source.global_position.direction_to(global_position)
			if push_direction != Vector2.ZERO:
				_external_push_velocity += push_direction * knockback_force
				_spawn_local_vfx(_vfx_knockback, Vector2(0.0, -4.0), 0.16, Vector2.ONE, push_direction.angle())

func take_damage(amount: float) -> void:
	take_hit(amount)

func _apply_damage(amount: float) -> void:
	if amount <= 0.0:
		return

	_sync_health_max_from_export()
	var applied_damage: float = _health_component.take_damage(amount)
	_current_health = _health_component.current_health
	if applied_damage > 0.0:
		CombatText.spawn_damage(self, applied_damage)
		_request_health_bar_visibility()
	_update_health_bar()

	if _health_component.is_dead:
		_die()

func heal(amount: float) -> void:
	if amount <= 0.0:
		return
	if _health_component.is_dead:
		return

	_sync_health_max_from_export()
	var healed_amount: float = _health_component.heal(amount)
	_current_health = _health_component.current_health
	if healed_amount <= 0.0:
		return

	CombatText.spawn_heal(self, healed_amount)
	_request_health_bar_visibility(0.75)
	_update_health_bar()

func _update_status_effects(delta: float) -> void:
	_burn_time_left = maxf(_burn_time_left - delta, 0.0)
	_sting_time_left = maxf(_sting_time_left - delta, 0.0)
	_root_time_left = maxf(_root_time_left - delta, 0.0)
	_status_tick_time_left = maxf(_status_tick_time_left - delta, 0.0)

	if _burn_time_left <= 0.0:
		_burn_dps = 0.0

	if _sting_time_left <= 0.0:
		_sting_stacks = 0
		_sting_dps_per_stack = 0.0
		_sting_max_stack_burst_damage = 0.0
		_sting_hits_toward_burst = 0

	if _status_tick_time_left > 0.0:
		_update_status_vfx()
		return

	var tick_interval: float = maxf(status_tick_interval, 0.05)
	_status_tick_time_left = tick_interval

	var burn_damage: float = _burn_dps * tick_interval
	if burn_damage > 0.0:
		_apply_damage(burn_damage)

	var sting_damage: float = _sting_dps_per_stack * float(_sting_stacks) * tick_interval
	if sting_damage > 0.0:
		_apply_damage(sting_damage)

	_update_status_vfx()

func _setup_status_vfx() -> void:
	_burn_vfx_sprite = _create_persistent_status_sprite(_vfx_burn_effect, Vector2(0.0, -4.0), Vector2(1.0, 1.0))
	_root_vfx_sprite = _create_persistent_status_sprite(_vfx_rooted, Vector2(0.0, 10.0), Vector2(1.0, 1.0))
	_update_status_vfx()

func _load_vfx_assets() -> void:
	_vfx_burn_effect = load(VFX_BURN_EFFECT_PATH) as Texture2D
	_vfx_rooted = load(VFX_ROOTED_PATH) as Texture2D
	_vfx_hit_marker = load(VFX_HIT_MARKER_PATH) as Texture2D
	_vfx_knockback = load(VFX_KNOCKBACK_PATH) as Texture2D

func _create_persistent_status_sprite(texture: Texture2D, local_position: Vector2, sprite_scale: Vector2) -> Sprite2D:
	if texture == null:
		return null

	var status_sprite := Sprite2D.new()
	status_sprite.texture = texture
	status_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	status_sprite.position = local_position
	status_sprite.scale = sprite_scale
	status_sprite.z_index = 5
	status_sprite.visible = false
	add_child(status_sprite)
	return status_sprite

func _update_status_vfx() -> void:
	if _burn_vfx_sprite != null:
		_burn_vfx_sprite.visible = _burn_time_left > 0.0
		if _burn_vfx_sprite.visible:
			var burn_pulse: float = 0.75 + (0.25 * sin(Time.get_ticks_msec() / 85.0))
			_burn_vfx_sprite.modulate = Color(1.0, 1.0, 1.0, burn_pulse)

	if _root_vfx_sprite != null:
		_root_vfx_sprite.visible = _root_time_left > 0.0
		if _root_vfx_sprite.visible:
			var root_pulse: float = 0.8 + (0.2 * sin(Time.get_ticks_msec() / 110.0))
			_root_vfx_sprite.modulate = Color(1.0, 1.0, 1.0, root_pulse)

func _spawn_local_vfx(texture: Texture2D, local_offset: Vector2, lifetime: float, sprite_scale: Vector2 = Vector2.ONE, rotation_radians: float = 0.0) -> void:
	if texture == null:
		return
	if not _can_spawn_vfx_this_frame():
		return
	if is_instance_valid(_vfx_pool):
		_vfx_pool.spawn_local_fade(self, texture, local_offset, rotation_radians, sprite_scale, 7, lifetime, 0.95)
		return

	var vfx_sprite := Sprite2D.new()
	vfx_sprite.texture = texture
	vfx_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	vfx_sprite.position = local_offset
	vfx_sprite.scale = sprite_scale
	vfx_sprite.rotation = rotation_radians
	vfx_sprite.z_index = 7
	vfx_sprite.modulate = Color(1.0, 1.0, 1.0, 0.95)
	add_child(vfx_sprite)

	var fade_tween: Tween = vfx_sprite.create_tween()
	fade_tween.tween_property(vfx_sprite, "modulate:a", 0.0, maxf(lifetime, 0.05))
	fade_tween.tween_callback(Callable(vfx_sprite, "queue_free"))

func _can_spawn_vfx_this_frame() -> bool:
	var frame: int = Engine.get_process_frames()
	if frame != _vfx_spawn_frame:
		_vfx_spawn_frame = frame
		_vfx_spawn_count = 0

	if _vfx_spawn_count >= MAX_VFX_SPAWNS_PER_FRAME:
		return false

	_vfx_spawn_count += 1
	return true

func _die() -> void:
	if enemy_archetype == ENEMY_ARCHETYPE_TRENCHCOAT_GOBLIN:
		_spawn_split_goblins()
	queue_free()

func _spawn_split_goblins() -> void:
	var spawn_count: int = maxi(split_spawn_count, 0)
	if spawn_count <= 0:
		return
	if get_parent() == null:
		return

	var enemy_scene: PackedScene = _get_enemy_scene()
	if enemy_scene == null:
		return

	for i in spawn_count:
		var enemy_node: Node = enemy_scene.instantiate()
		if not (enemy_node is EnemyUnit):
			if is_instance_valid(enemy_node):
				enemy_node.queue_free()
			continue

		var goblin: EnemyUnit = enemy_node as EnemyUnit
		goblin.set_enemy_archetype(ENEMY_ARCHETYPE_GOBLIN)
		get_parent().add_child(goblin)
		var angle: float = (TAU * float(i)) / float(spawn_count)
		var offset: Vector2 = Vector2.RIGHT.rotated(angle) * maxf(split_spawn_spread_radius, 8.0)
		goblin.global_position = global_position + offset

func _get_enemy_scene() -> PackedScene:
	if _enemy_scene_cache != null:
		return _enemy_scene_cache

	_enemy_scene_cache = load(ENEMY_SCENE_PATH) as PackedScene
	return _enemy_scene_cache

func _apply_enemy_archetype(archetype: StringName) -> void:
	var resolved_archetype: StringName = _normalize_enemy_archetype(archetype)
	enemy_archetype = resolved_archetype

	match resolved_archetype:
		ENEMY_ARCHETYPE_FAST_RAIDER:
			move_speed = 145.0
			max_health = 65.0
			melee_damage = 14.0
			melee_attack_cooldown = 0.85
		ENEMY_ARCHETYPE_TANK_RAIDER:
			move_speed = 58.0
			max_health = 240.0
			melee_damage = 9.0
			melee_attack_cooldown = 1.1
		ENEMY_ARCHETYPE_RANGED_RAIDER:
			move_speed = 84.0
			max_health = 70.0
			melee_damage = 0.0
			ranged_damage = 13.0
			ranged_attack_range = 360.0
			ranged_attack_cooldown = 1.35
		ENEMY_ARCHETYPE_HEALING_RAIDER:
			move_speed = 76.0
			max_health = 85.0
			melee_damage = 0.0
			healer_heal_per_second = 14.0
			healer_aura_radius = 230.0
			healer_keep_away_distance = 180.0
		ENEMY_ARCHETYPE_TRENCHCOAT_GOBLIN:
			move_speed = 95.0
			max_health = 260.0
			melee_damage = 20.0
			melee_attack_cooldown = 0.9
		ENEMY_ARCHETYPE_GOBLIN:
			move_speed = 102.0
			max_health = 95.0
			melee_damage = 13.0
			melee_attack_cooldown = 0.9
		_:
			move_speed = 90.0
			max_health = 100.0
			melee_damage = 15.0
			melee_attack_cooldown = 1.0

	if _navigation_agent != null:
		_navigation_agent.max_speed = maxf(move_speed, 1.0)

	var texture_path: String = _get_archetype_texture_path(resolved_archetype)
	var enemy_texture: Texture2D = _load_texture_cached(texture_path)
	if enemy_texture == null:
		enemy_texture = _load_texture_cached("res://assets/characters/raider.png")
	if enemy_texture == null:
		enemy_texture = _load_texture_cached(DEFAULT_ENEMY_TEXTURE_PATH)
	if _sprite != null and enemy_texture != null:
		_sprite.texture = enemy_texture

	_ranged_projectile_texture = _load_texture_cached(ENEMY_PROJECTILE_TEXTURE_PATH)

func _normalize_enemy_archetype(archetype: StringName) -> StringName:
	if archetype == StringName():
		return ENEMY_ARCHETYPE_BASIC_RAIDER

	match archetype:
		ENEMY_ARCHETYPE_BASIC_RAIDER, ENEMY_ARCHETYPE_FAST_RAIDER, ENEMY_ARCHETYPE_TANK_RAIDER, ENEMY_ARCHETYPE_RANGED_RAIDER, ENEMY_ARCHETYPE_HEALING_RAIDER, ENEMY_ARCHETYPE_TRENCHCOAT_GOBLIN, ENEMY_ARCHETYPE_GOBLIN:
			return archetype
		_:
			return ENEMY_ARCHETYPE_BASIC_RAIDER

func _get_archetype_texture_path(archetype: StringName) -> String:
	match archetype:
		ENEMY_ARCHETYPE_FAST_RAIDER:
			return "res://assets/characters/fast_raider.png"
		ENEMY_ARCHETYPE_TANK_RAIDER:
			return "res://assets/characters/tank_raider.png"
		ENEMY_ARCHETYPE_RANGED_RAIDER:
			return "res://assets/characters/ranged_raider.png"
		ENEMY_ARCHETYPE_HEALING_RAIDER:
			return "res://assets/characters/healing_raider.png"
		ENEMY_ARCHETYPE_TRENCHCOAT_GOBLIN:
			return "res://assets/characters/trenchcoat_goblins.png"
		ENEMY_ARCHETYPE_GOBLIN:
			return "res://assets/characters/goblin.png"
		ENEMY_ARCHETYPE_BASIC_RAIDER:
			return "res://assets/characters/raider.png"
		_:
			return DEFAULT_ENEMY_TEXTURE_PATH

func _load_texture_cached(path: String) -> Texture2D:
	if path == "":
		return null
	if _texture_cache.has(path):
		var cached_value: Variant = _texture_cache[path]
		if cached_value is Texture2D:
			return cached_value as Texture2D
		return null

	var texture: Texture2D = load(path) as Texture2D
	_texture_cache[path] = texture
	return texture

func _is_ranged_archetype() -> bool:
	return enemy_archetype == ENEMY_ARCHETYPE_RANGED_RAIDER

func _is_healer_archetype() -> bool:
	return enemy_archetype == ENEMY_ARCHETYPE_HEALING_RAIDER

func _update_idle_bounce() -> void:
	if _sprite == null:
		return
	var bounce_height: float = maxf(idle_bounce_height, 0.0)
	var bounce_speed: float = maxf(idle_bounce_speed, 0.1)
	_sprite.position.y = sin(Time.get_ticks_msec() / 1000.0 * bounce_speed) * bounce_height

func _play_attack_tilt() -> void:
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

func _update_health_bar() -> void:
	if _health_bar == null:
		return

	_health_bar.max_value = _health_component.max_health
	_health_bar.value = _health_component.current_health
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

	var should_show: bool = always_show_health_bar or _health_bar_visible_time_left > 0.0
	if _health_component.is_dead:
		should_show = false
	_health_bar.visible = should_show

func _sync_health_max_from_export() -> void:
	_health_component.set_max_health(max_health)

func _find_closest_target_in_groups(group_names: PackedStringArray, radius: float) -> Node2D:
	var find_start_us: int = Time.get_ticks_usec()
	var spatial_index := _resolve_spatial_index()
	if spatial_index != null:
		var nearest: Node2D = spatial_index.find_closest_in_groups(global_position, group_names, radius, self)
		_perf_mark_scope(&"enemy.find_target_in_groups", find_start_us, {
			"path": "spatial_index",
			"radius": radius,
		})
		return nearest

	var closest_target: Node2D
	var closest_distance_sq: float = INF
	var has_radius_limit: bool = radius > 0.0
	var radius_sq: float = radius * radius

	for group_name in group_names:
		for candidate in get_tree().get_nodes_in_group(group_name):
			if candidate == self:
				continue
			if not candidate is Node2D:
				continue

			var candidate_2d := candidate as Node2D
			var distance_sq := global_position.distance_squared_to(candidate_2d.global_position)
			if has_radius_limit and distance_sq > radius_sq:
				continue

			if distance_sq < closest_distance_sq:
				closest_distance_sq = distance_sq
				closest_target = candidate_2d

	_perf_mark_scope(&"enemy.find_target_in_groups", find_start_us, {
		"path": "group_scan",
		"radius": radius,
	})
	return closest_target

func _find_closest_target_in_group(group_name: StringName) -> Node2D:
	var find_start_us: int = Time.get_ticks_usec()
	if group_name == StringName():
		_perf_mark_scope(&"enemy.find_target_in_group", find_start_us, {
			"status": "empty_group",
		})
		return null

	var spatial_index := _resolve_spatial_index()
	if spatial_index != null:
		var nearest: Node2D = spatial_index.find_closest_in_group(global_position, group_name, -1.0, self)
		_perf_mark_scope(&"enemy.find_target_in_group", find_start_us, {
			"path": "spatial_index",
			"group": String(group_name),
		})
		return nearest

	var closest_target: Node2D
	var closest_distance_sq: float = INF

	for candidate in get_tree().get_nodes_in_group(group_name):
		if candidate == self:
			continue
		if not candidate is Node2D:
			continue

		var candidate_2d := candidate as Node2D
		var distance_sq := global_position.distance_squared_to(candidate_2d.global_position)
		if distance_sq < closest_distance_sq:
			closest_distance_sq = distance_sq
			closest_target = candidate_2d

	_perf_mark_scope(&"enemy.find_target_in_group", find_start_us, {
		"path": "group_scan",
		"group": String(group_name),
	})
	return closest_target

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

func _resolve_spatial_index() -> SpatialIndex2D:
	if is_instance_valid(_spatial_index):
		return _spatial_index

	_spatial_index = get_node_or_null("/root/SpatialIndex") as SpatialIndex2D
	return _spatial_index

func _is_far_from_player() -> bool:
	var distance_threshold: float = maxf(far_lod_distance, 200.0)
	var player_target: Node2D = _find_closest_target_in_group(&"players")
	if player_target == null:
		return false

	return global_position.distance_squared_to(player_target.global_position) > distance_threshold * distance_threshold

func _get_stop_distance(target: Node2D) -> float:
	var self_radius := _estimate_collision_radius(self)
	var target_radius := _estimate_collision_radius(target)
	var collision_stop_distance := self_radius + target_radius + target_stop_padding
	return maxf(target_reach_distance, collision_stop_distance)

func _get_surface_stop_distance(_target: Node2D) -> float:
	var self_radius: float = _estimate_collision_radius(self)
	var collision_stop_distance: float = self_radius + target_stop_padding
	return maxf(target_reach_distance, collision_stop_distance)

func _get_target_surface_distance(target: Node2D, target_center_distance: float = -1.0) -> float:
	if target == null:
		return INF

	var center_distance: float = target_center_distance
	if center_distance < 0.0:
		center_distance = global_position.distance_to(target.global_position)

	var target_radius: float = _estimate_collision_radius(target)
	return maxf(center_distance - target_radius, 0.0)

func _estimate_collision_radius(body: Node2D) -> float:
	var collision_shape := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null or collision_shape.shape == null:
		return 0.0

	var max_scale := maxf(absf(collision_shape.global_scale.x), absf(collision_shape.global_scale.y))

	if collision_shape.shape is RectangleShape2D:
		var rect_shape: RectangleShape2D = collision_shape.shape as RectangleShape2D
		return rect_shape.size.length() * 0.5 * max_scale

	if collision_shape.shape is CircleShape2D:
		var circle_shape: CircleShape2D = collision_shape.shape as CircleShape2D
		return circle_shape.radius * max_scale

	if collision_shape.shape is CapsuleShape2D:
		var capsule_shape: CapsuleShape2D = collision_shape.shape as CapsuleShape2D
		return (capsule_shape.height * 0.5 + capsule_shape.radius) * max_scale

	return 0.0
