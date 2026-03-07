extends CharacterBody2D

@export var move_speed: float = 110.0
@export var repath_interval: float = 0.15
@export var target_reach_distance: float = 14.0
@export var follow_player_distance: float = 80.0
@export var attack_range: float = 210.0
@export var attack_damage: float = 20.0
@export var attack_cooldown: float = 0.8
@export var attack_projectile_scene: PackedScene = preload("res://entities/summon/summon_attack.tscn")

const PHYSICS_LAYER_WORLD := 1 << 0
const PHYSICS_LAYER_SUMMON := 1 << 3

var _enemy_target: Node2D
var _player_target: Node2D
var _time_to_repath: float = 0.0
var _time_to_next_attack: float = 0.0

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = PHYSICS_LAYER_SUMMON
	collision_mask = PHYSICS_LAYER_WORLD
	add_to_group("summons")
	_player_target = _find_player()

func _physics_process(delta: float) -> void:
	_time_to_repath -= delta
	_time_to_next_attack = maxf(_time_to_next_attack - delta, 0.0)
	if _time_to_repath <= 0.0:
		_enemy_target = _find_closest_enemy()
		if not is_instance_valid(_player_target):
			_player_target = _find_player()
		_time_to_repath = repath_interval

	if is_instance_valid(_enemy_target):
		var distance_to_enemy := global_position.distance_to(_enemy_target.global_position)
		if distance_to_enemy <= attack_range:
			velocity = Vector2.ZERO
			_try_attack(_enemy_target)
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

func _try_attack(target: Node2D) -> void:
	if _time_to_next_attack > 0.0:
		return

	_time_to_next_attack = attack_cooldown
	_launch_attack(target)

func _launch_attack(target: Node2D) -> void:
	if attack_projectile_scene == null:
		if target.has_method("take_damage"):
			target.call("take_damage", attack_damage)
		return

	var attack_instance := attack_projectile_scene.instantiate()
	if not attack_instance is Node2D:
		return

	var projectile := attack_instance as Node2D
	projectile.global_position = global_position
	if projectile.has_method("setup"):
		projectile.call("setup", target, attack_damage)

	get_tree().current_scene.add_child(projectile)

func _move_towards(target_position: Vector2) -> void:
	if global_position.distance_to(target_position) > target_reach_distance:
		velocity = global_position.direction_to(target_position) * move_speed
	else:
		velocity = Vector2.ZERO

func _find_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("players")
	if not players.is_empty() and players[0] is Node2D:
		return players[0] as Node2D

	if get_tree().current_scene != null:
		var by_name := get_tree().current_scene.find_child("player", true, false)
		if by_name is Node2D:
			return by_name as Node2D

	return null

func _find_closest_enemy() -> Node2D:
	var closest_enemy: Node2D
	var closest_distance_sq := INF

	for candidate in get_tree().get_nodes_in_group("enemies"):
		if not candidate is Node2D:
			continue

		var enemy_2d := candidate as Node2D
		var distance_sq := global_position.distance_squared_to(enemy_2d.global_position)
		if distance_sq < closest_distance_sq:
			closest_distance_sq = distance_sq
			closest_enemy = enemy_2d

	return closest_enemy
