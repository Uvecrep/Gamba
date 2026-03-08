extends Node2D

@export var enemy_scene: PackedScene
@export var spawn_interval: float = 15
@export var max_alive_enemies: int = 8
@export var auto_start: bool = true
@export var spawn_points_root_path: NodePath = NodePath("SpawnPoints")

@onready var _spawn_timer: Timer = $SpawnTimer

func _ready() -> void:
	if enemy_scene == null:
		push_warning("EnemySpawner needs enemy_scene set for wave spawns.")

	_spawn_timer.wait_time = spawn_interval
	_spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	if auto_start:
		start_spawning()

func start_spawning() -> void:
	if _spawn_timer == null:
		return

	_spawn_timer.wait_time = spawn_interval
	if _spawn_timer.is_stopped():
		_spawn_timer.start()

func stop_spawning() -> void:
	if _spawn_timer == null:
		return

	_spawn_timer.stop()

func _on_spawn_timer_timeout() -> void:
	if enemy_scene == null:
		return

	# Keep early waves readable by capping total active enemies.
	var alive_count := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			alive_count += 1
	if alive_count >= max_alive_enemies:
		return

	var enemy := enemy_scene.instantiate() as Node2D
	if enemy == null:
		return

	enemy.global_position = _pick_spawn_position()
	if get_parent() != null:
		get_parent().add_child(enemy)
	else:
		add_child(enemy)

func _pick_spawn_position() -> Vector2:
	var spawn_root := get_node_or_null(spawn_points_root_path)
	if spawn_root == null:
		return global_position

	var points := spawn_root.get_children()
	if points.is_empty():
		return global_position

	var random_point := points[randi() % points.size()]
	if random_point is Node2D:
		return random_point.global_position

	return global_position
