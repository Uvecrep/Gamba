extends CharacterBody2D

const CombatText = preload("res://scripts/floating_combat_text.gd")

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
@export var nav_goal_update_interval: float = 0.45
@export var visibility_check_interval: float = 0.2
@export var status_tick_interval: float = 0.2
@export var max_sting_stacks: int = 8
@export var knockback_decay: float = 900.0
@export var health_bar_show_duration: float = 2.0
@export var always_show_health_bar: bool = false

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
var _burn_vfx_sprite: Sprite2D
var _root_vfx_sprite: Sprite2D
var _vfx_burn_effect: Texture2D
var _vfx_rooted: Texture2D
var _vfx_hit_marker: Texture2D
var _vfx_knockback: Texture2D

@onready var _health_bar: ProgressBar = get_node_or_null("HealthBar") as ProgressBar
@onready var _navigation_agent: NavigationAgent2D = get_node_or_null("NavigationAgent2D") as NavigationAgent2D

func _ready() -> void:
	_load_vfx_assets()
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = PHYSICS_LAYER_ENEMY
	collision_mask = PHYSICS_LAYER_WORLD
	add_to_group("enemies")
	if _navigation_agent != null:
		_navigation_agent.path_desired_distance = maxf(nav_path_desired_distance, 4.0)
		_navigation_agent.target_desired_distance = maxf(nav_target_desired_distance, 6.0)
		_navigation_agent.set_navigation_map(get_world_2d().navigation_map)
	_current_health = max_health
	_health_bar_visible_time_left = 0.0
	_update_health_bar()
	_setup_status_vfx()

func _physics_process(delta: float) -> void:
	_time_to_repath -= delta
	_time_to_nav_goal_refresh = maxf(_time_to_nav_goal_refresh - delta, 0.0)
	_time_to_visibility_refresh = maxf(_time_to_visibility_refresh - delta, 0.0)
	_time_to_next_melee_hit = maxf(_time_to_next_melee_hit - delta, 0.0)
	var previous_health_bar_visible_time_left: float = _health_bar_visible_time_left
	_health_bar_visible_time_left = maxf(_health_bar_visible_time_left - delta, 0.0)
	_update_status_effects(delta)
	_external_push_velocity = _external_push_velocity.move_toward(Vector2.ZERO, maxf(knockback_decay, 0.0) * delta)
	if previous_health_bar_visible_time_left > 0.0 and _health_bar_visible_time_left <= 0.0:
		_refresh_health_bar_visibility()
	var is_rooted: bool = _root_time_left > 0.0
	if _time_to_repath <= 0.0:
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
			_time_to_visibility_refresh = maxf(visibility_check_interval, 0.05)
		else:
			_last_nav_goal_target = null
			_time_to_nav_goal_refresh = 0.0
			_time_to_visibility_refresh = 0.0
			_cached_has_clear_path = false
			_clear_navigation_target()
		_time_to_repath = repath_interval

	if is_instance_valid(_current_target):
		if _time_to_visibility_refresh <= 0.0:
			_cached_has_clear_path = _has_clear_path_to_target(_current_target)
			_time_to_visibility_refresh = maxf(visibility_check_interval, 0.05)

		var target_center_distance: float = global_position.distance_to(_current_target.global_position)
		var target_distance: float = _get_target_surface_distance(_current_target, target_center_distance)
		# Stop/attack thresholds are measured from target collider surface distance.
		var stop_distance: float = _get_surface_stop_distance(_current_target)
		var allow_attack_without_clear_path: bool = _current_target.is_in_group("house")
		var can_engage: bool = _cached_has_clear_path or allow_attack_without_clear_path
		if is_rooted:
			velocity = Vector2.ZERO
		elif target_distance > stop_distance or not can_engage:
			velocity = _get_navigation_velocity(_current_target.global_position)
		else:
			velocity = Vector2.ZERO

		if not is_rooted:
			_try_melee_attack(_current_target, target_distance, stop_distance, _cached_has_clear_path, allow_attack_without_clear_path)
	else:
		velocity = Vector2.ZERO
		_clear_navigation_target()

	velocity += _external_push_velocity
	move_and_slide()

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
	if target == null:
		return

	if _navigation_agent == null or _navigation_agent.get_navigation_map() == RID():
		_set_navigation_target(target.global_position)
		return

	var desired_stop_distance: float = _get_stop_distance(target)
	var best_target: Vector2 = _choose_best_navigation_target(target.global_position, desired_stop_distance, target.is_in_group("house"))
	_set_navigation_target(best_target)

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

	for i in range(ring_points):
		var angle_offset: float = TAU * float(i) / float(ring_points)
		var ring_target: Vector2 = target_position + (direction_from_target.rotated(angle_offset) * desired_ring_distance)
		var projected_ring: Vector2 = NavigationServer2D.map_get_closest_point(nav_map, ring_target)
		var candidate_score: float = projected_ring.distance_to(ring_target)
		if candidate_score < best_score:
			best_score = candidate_score
			best_candidate = projected_ring

	return best_candidate

func _clear_navigation_target() -> void:
	if _navigation_agent == null:
		return

	_navigation_agent.target_position = global_position

func _try_melee_attack(target: Node2D, target_distance: float, stop_distance: float, has_clear_path: bool, allow_without_clear_path: bool) -> void:
	if melee_damage <= 0.0 or melee_attack_cooldown <= 0.0:
		return
	if not target.has_method("take_damage"):
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
	target.call("take_damage", melee_damage)

func _has_clear_path_to_target(target: Node2D) -> bool:
	if target == null:
		return false

	var world_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	if world_state == null:
		return true

	var query := PhysicsRayQueryParameters2D.create(global_position, target.global_position)
	query.collision_mask = PHYSICS_LAYER_WORLD
	query.exclude = [get_rid()]

	var hit: Dictionary = world_state.intersect_ray(query)
	if hit.is_empty():
		return true

	var collider: Variant = hit.get("collider")
	return collider == target

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

func _die() -> void:
	queue_free()

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

	var should_show: bool = always_show_health_bar or _health_bar_visible_time_left > 0.0
	if _current_health <= 0.0:
		should_show = false
	_health_bar.visible = should_show

func _find_closest_target_in_groups(group_names: PackedStringArray, radius: float) -> Node2D:
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

	return closest_target

func _find_closest_target_in_group(group_name: StringName) -> Node2D:
	if group_name == StringName():
		return null

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

	return closest_target

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
