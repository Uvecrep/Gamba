extends CharacterBody2D

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

const PHYSICS_LAYER_WORLD: int = 1 << 0
const PHYSICS_LAYER_SUMMON: int = 1 << 3

enum CommandMode {
	AUTO,
	MOVE,
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

@onready var _health_bar: ProgressBar = get_node_or_null("HealthBar") as ProgressBar
@onready var _navigation_agent: NavigationAgent2D = get_node_or_null("NavigationAgent2D") as NavigationAgent2D

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = PHYSICS_LAYER_SUMMON
	collision_mask = PHYSICS_LAYER_WORLD
	add_to_group("summons")
	if _navigation_agent != null:
		_navigation_agent.path_desired_distance = maxf(nav_path_desired_distance, 4.0)
		_navigation_agent.target_desired_distance = maxf(nav_target_desired_distance, 6.0)
		_navigation_agent.set_navigation_map(get_world_2d().navigation_map)
	_player_target = _find_player()
	_current_health = max_health
	_update_health_bar()

func _physics_process(delta: float) -> void:
	_time_to_repath -= delta
	_time_to_nav_goal_refresh = maxf(_time_to_nav_goal_refresh - delta, 0.0)
	_time_to_next_attack = maxf(_time_to_next_attack - delta, 0.0)
	if _time_to_repath <= 0.0:
		_enemy_target = _find_closest_enemy()
		if not is_instance_valid(_player_target):
			_player_target = _find_player()

		if _command_mode != CommandMode.MOVE:
			var nav_target: Node2D = _enemy_target
			if not is_instance_valid(nav_target):
				nav_target = _player_target

			if is_instance_valid(nav_target):
				if _last_nav_goal_target != nav_target or _time_to_nav_goal_refresh <= 0.0:
					_set_navigation_target_for_target(nav_target)
					_last_nav_goal_target = nav_target
					_time_to_nav_goal_refresh = maxf(nav_goal_update_interval, 0.05)
			else:
				_last_nav_goal_target = null
				_time_to_nav_goal_refresh = 0.0
				_clear_navigation_target()
		_time_to_repath = repath_interval

	if _command_mode == CommandMode.MOVE:
		_handle_move_command()
	elif _command_mode == CommandMode.HOLD:
		_handle_hold_command()
	elif is_instance_valid(_enemy_target):
		var distance_to_enemy: float = global_position.distance_to(_enemy_target.global_position)
		if distance_to_enemy <= attack_range:
			velocity = Vector2.ZERO
			if _time_to_next_attack <= 0.0:
				_time_to_next_attack = attack_cooldown
				_launch_attack(_enemy_target)
		else:
			_move_towards(_enemy_target.global_position)
	elif is_instance_valid(_player_target):
		if global_position.distance_to(_player_target.global_position) > follow_player_distance:
			_move_towards(_player_target.global_position)
		else:
			velocity = Vector2.ZERO
	else:
		velocity = Vector2.ZERO

	move_and_slide()

func set_move_target(target_position: Vector2) -> void:
	_move_target_position = target_position
	_command_mode = CommandMode.MOVE

func set_hold_position(should_hold: bool) -> void:
	_hold_toggle_enabled = should_hold

	if _command_mode == CommandMode.MOVE:
		# Keep moving to the commanded destination; hold applies once movement completes.
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

func is_holding_position() -> bool:
	return _command_mode == CommandMode.HOLD

func is_hold_toggle_enabled() -> bool:
	return _hold_toggle_enabled

func get_command_mode_name() -> String:
	match _command_mode:
		CommandMode.MOVE:
			return "MOVE"
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

func _try_attack_in_range() -> bool:
	if not is_instance_valid(_enemy_target):
		return false

	if global_position.distance_to(_enemy_target.global_position) > attack_range:
		return false

	if _time_to_next_attack > 0.0:
		return false

	_time_to_next_attack = attack_cooldown
	_launch_attack(_enemy_target)
	return true

func take_damage(amount: float) -> void:
	if amount <= 0.0:
		return

	_current_health = clampf(_current_health - amount, 0.0, max_health)
	_update_health_bar()

	if _current_health <= 0.0:
		queue_free()

func _update_health_bar() -> void:
	if _health_bar == null:
		return

	_health_bar.max_value = max_health
	_health_bar.value = _current_health
	_health_bar.visible = true

func _launch_attack(target: Node2D) -> void:
	if attack_projectile_scene == null:
		if target.has_method("take_damage"):
			target.call("take_damage", attack_damage)
		return

	var projectile: Node2D = attack_projectile_scene.instantiate() as Node2D
	if projectile == null:
		return

	projectile.global_position = global_position
	if projectile.has_method("setup"):
		projectile.call("setup", target, attack_damage)

	get_tree().current_scene.add_child(projectile)

func _move_towards(target_position: Vector2) -> void:
	if global_position.distance_to(target_position) > target_reach_distance:
		_set_navigation_target(target_position)
		velocity = _get_navigation_velocity(target_position)
	else:
		velocity = Vector2.ZERO
		_clear_navigation_target()

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

	var desired_distance: float = attack_range if target == _enemy_target else target_reach_distance
	var best_target: Vector2 = _choose_best_navigation_target(target.global_position, desired_distance, target == _enemy_target)
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
	if _navigation_agent == null:
		return

	_navigation_agent.target_position = global_position

func _find_player() -> Node2D:
	var players: Array = get_tree().get_nodes_in_group("players")
	if not players.is_empty() and players[0] is Node2D:
		return players[0] as Node2D

	if get_tree().current_scene != null:
		var by_name: Node = get_tree().current_scene.find_child("player", true, false)
		if by_name is Node2D:
			return by_name as Node2D

	return null

func _find_closest_enemy() -> Node2D:
	var closest_enemy: Node2D
	var closest_distance_sq: float = INF

	for candidate in get_tree().get_nodes_in_group("enemies"):
		if not candidate is Node2D:
			continue

		var enemy_2d: Node2D = candidate as Node2D
		var distance_sq: float = global_position.distance_squared_to(enemy_2d.global_position)
		if distance_sq < closest_distance_sq:
			closest_distance_sq = distance_sq
			closest_enemy = enemy_2d

	return closest_enemy
