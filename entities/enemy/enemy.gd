extends CharacterBody2D

@export var move_speed: float = 90.0
@export var repath_interval: float = 0.3
@export var target_reach_distance: float = 32.0
@export var target_stop_padding: float = 2.0
@export var nearby_target_groups: PackedStringArray = ["summons"]
@export var fallback_target_group: StringName = &"house"
@export var nearby_target_radius: float = 180.0
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

const PHYSICS_LAYER_WORLD: int = 1 << 0
const PHYSICS_LAYER_ENEMY: int = 1 << 2

var _current_target: Node2D
var _time_to_repath: float = 0.0
var _time_to_next_melee_hit: float = 0.0
var _current_health: float = 0.0
var _time_to_nav_goal_refresh: float = 0.0
var _time_to_visibility_refresh: float = 0.0
var _last_nav_goal_target: Node2D
var _cached_has_clear_path: bool = false

@onready var _health_bar: ProgressBar = get_node_or_null("HealthBar") as ProgressBar
@onready var _navigation_agent: NavigationAgent2D = get_node_or_null("NavigationAgent2D") as NavigationAgent2D

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = PHYSICS_LAYER_ENEMY
	collision_mask = PHYSICS_LAYER_WORLD
	add_to_group("enemies")
	if _navigation_agent != null:
		_navigation_agent.path_desired_distance = maxf(nav_path_desired_distance, 4.0)
		_navigation_agent.target_desired_distance = maxf(nav_target_desired_distance, 6.0)
		_navigation_agent.set_navigation_map(get_world_2d().navigation_map)
	_current_health = max_health
	_update_health_bar()

func _physics_process(delta: float) -> void:
	_time_to_repath -= delta
	_time_to_nav_goal_refresh = maxf(_time_to_nav_goal_refresh - delta, 0.0)
	_time_to_visibility_refresh = maxf(_time_to_visibility_refresh - delta, 0.0)
	_time_to_next_melee_hit = maxf(_time_to_next_melee_hit - delta, 0.0)
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
		if target_distance > stop_distance or not can_engage:
			velocity = _get_navigation_velocity(_current_target.global_position)
		else:
			velocity = Vector2.ZERO

		_try_melee_attack(_current_target, target_distance, stop_distance, _cached_has_clear_path, allow_attack_without_clear_path)
	else:
		velocity = Vector2.ZERO
		_clear_navigation_target()

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

func take_damage(amount: float) -> void:
	if amount <= 0.0:
		return

	_current_health = clampf(_current_health - amount, 0.0, max_health)
	_update_health_bar()

	if _current_health <= 0.0:
		_die()

func _die() -> void:
	queue_free()

func _update_health_bar() -> void:
	if _health_bar == null:
		return

	_health_bar.max_value = max_health
	_health_bar.value = _current_health
	_health_bar.visible = true

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
