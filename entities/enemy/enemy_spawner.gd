extends Node2D

@export var enemy_scene: PackedScene
@export var spawn_interval: float = 15
@export var max_alive_enemies: int = 8
@export var auto_start: bool = true
@export var spawn_points_root_path: NodePath = NodePath("SpawnPoints")

@onready var _spawn_timer: Timer = $SpawnTimer

func _ready() -> void:
	add_to_group("enemy_towers")

	if enemy_scene == null:
		push_warning("EnemySpawner needs enemy_scene set for wave spawns.")

	_spawn_timer.wait_time = spawn_interval
	if not _spawn_timer.timeout.is_connected(_on_spawn_timer_timeout):
		_spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	_spawn_timer.autostart = false
	if auto_start:
		start_spawning()
	else:
		_spawn_timer.stop()

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

func spawn_wave(enemy_count: int, ignore_alive_cap: bool = false) -> int:
	if enemy_scene == null:
		return 0

	var requested_count: int = maxi(enemy_count, 0)
	if requested_count <= 0:
		return 0

	var spawned_count: int = 0
	var alive_count: int = _get_alive_enemy_count()
	for _i in requested_count:
		if not ignore_alive_cap and alive_count >= max_alive_enemies:
			break

		if _spawn_single_enemy():
			spawned_count += 1
			alive_count += 1

	return spawned_count

func _on_spawn_timer_timeout() -> void:
	if enemy_scene == null:
		return

	# Keep early waves readable by capping total active enemies.
	if _get_alive_enemy_count() >= max_alive_enemies:
		return

	_spawn_single_enemy()

func _get_alive_enemy_count() -> int:
	var alive_count: int = 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			alive_count += 1

	return alive_count

func _spawn_single_enemy() -> bool:
	if enemy_scene == null:
		return false

	var enemy: Node2D = enemy_scene.instantiate() as Node2D
	if enemy == null:
		return false

	enemy.global_position = _pick_spawn_position()
	if get_parent() != null:
		get_parent().add_child(enemy)
	else:
		add_child(enemy)

	return true

func _pick_spawn_position() -> Vector2:
	var spawn_root: Node = get_node_or_null(spawn_points_root_path)
	if spawn_root == null:
		return global_position

	var points: Array = spawn_root.get_children()
	if points.is_empty():
		return global_position

	var random_point: Node = points[randi() % points.size()]
	if random_point is Node2D:
		return random_point.global_position

	return global_position
