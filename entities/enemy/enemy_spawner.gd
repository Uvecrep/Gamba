extends Node2D

@export var enemy_scene: PackedScene
@export var spawn_interval: float = 15
@export var max_alive_enemies: int = 8
@export var auto_start: bool = true
@export var spawn_points_root_path: NodePath = NodePath("SpawnPoints")
@export var target_parent_path: NodePath

@onready var _spawn_timer: Timer = $SpawnTimer

func _ready() -> void:
	if enemy_scene == null:
		push_warning("EnemySpawner has no enemy_scene configured.")

	_spawn_timer.wait_time = spawn_interval
	_spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	if auto_start:
		_spawn_timer.start()

func _on_spawn_timer_timeout() -> void:
	if enemy_scene == null:
		return
	if _alive_enemy_count() >= max_alive_enemies:
		return

	var enemy_instance := enemy_scene.instantiate()
	if not enemy_instance is Node2D:
		push_warning("enemy_scene is not a Node2D scene.")
		return

	var enemy_2d := enemy_instance as Node2D
	enemy_2d.global_position = _pick_spawn_position()
	_resolve_target_parent().add_child(enemy_instance)

func _alive_enemy_count() -> int:
	var count := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			count += 1
	return count

func _pick_spawn_position() -> Vector2:
	var spawn_root := get_node_or_null(spawn_points_root_path)
	if spawn_root == null:
		return global_position

	var points := spawn_root.get_children()
	if points.is_empty():
		return global_position

	var random_point := points[randi() % points.size()]
	if random_point is Node2D:
		return (random_point as Node2D).global_position

	return global_position

func _resolve_target_parent() -> Node:
	if target_parent_path != NodePath(""):
		var configured_parent := get_node_or_null(target_parent_path)
		if configured_parent != null:
			return configured_parent

	if get_parent() != null:
		return get_parent()

	return self
