extends "res://entities/shared/harvest_node.gd"
class_name BoulderResource

signal gold_ready_changed(has_gold: bool)

@export var starting_gold: int = 3
@export var max_gold: int = 3
@export var side_drop_min_offset: float = 24.0
@export var side_drop_max_offset: float = 38.0
@export var side_drop_vertical_jitter: float = 6.0
@export var min_drop_distance_from_player: float = 56.0
@export var mined_pickup_interaction_radius_multiplier: float = 1.75

@onready var _gold_ready_sprite: Sprite2D = $GoldReadySprite

func _ready() -> void:
	add_to_group("boulders")
	super._ready()

func _get_starting_harvest_count() -> int:
	return starting_gold

func _get_harvest_capacity() -> int:
	return max_gold

func _on_harvest_count_changed(_previous_count: int, current_count: int) -> void:
	_update_gold_visual(current_count)
	gold_ready_changed.emit(current_count > 0)

func _update_gold_visual(current_count: int) -> void:
	if _gold_ready_sprite == null:
		return

	_gold_ready_sprite.visible = current_count > 0

func _spawn_lootbox_pickups(amount: int) -> void:
	if pickup_scene == null:
		return

	var pickup_parent: Node = get_node_or_null(pickup_parent_path)
	if pickup_parent == null:
		pickup_parent = get_parent()
	if pickup_parent == null:
		return

	var follow_target: Node2D = null
	if not pickup_follow_target_path.is_empty():
		follow_target = get_node_or_null(pickup_follow_target_path) as Node2D

	for _i in range(amount):
		var pickup_node: Node = pickup_scene.instantiate()
		if not (pickup_node is Pickup):
			if is_instance_valid(pickup_node):
				pickup_node.queue_free()
			continue

		var side_sign: float = -1.0 if randf() < 0.5 else 1.0
		var side_offset_x: float = randf_range(side_drop_min_offset, side_drop_max_offset) * side_sign
		var side_offset_y: float = randf_range(-side_drop_vertical_jitter, side_drop_vertical_jitter)
		var drop_position: Vector2 = global_position + Vector2(side_offset_x, side_offset_y)
		drop_position = _push_drop_outside_player_collect_radius(drop_position)

		var new_pickup: Pickup = pickup_node as Pickup
		new_pickup.set_data(produced_lootbox_id)
		new_pickup.set_interaction_radius_multiplier(mined_pickup_interaction_radius_multiplier)
		_set_pickup_position_before_spawn(new_pickup, pickup_parent, drop_position)
		new_pickup.floating_towards = follow_target
		pickup_parent.add_child(new_pickup)
		new_pickup.global_position = drop_position

func _set_pickup_position_before_spawn(pickup: Pickup, pickup_parent: Node, world_position: Vector2) -> void:
	if pickup_parent is Node2D:
		pickup.position = (pickup_parent as Node2D).to_local(world_position)
		return

	pickup.position = world_position

func _push_drop_outside_player_collect_radius(drop_position: Vector2) -> Vector2:
	var min_distance: float = maxf(min_drop_distance_from_player, 0.0)
	if min_distance <= 0.0:
		return drop_position

	var min_distance_sq: float = min_distance * min_distance
	var adjusted_position: Vector2 = drop_position
	for node in get_tree().get_nodes_in_group("players"):
		var player_node: Node2D = node as Node2D
		if player_node == null:
			continue

		var to_drop: Vector2 = adjusted_position - player_node.global_position
		if to_drop.length_squared() >= min_distance_sq:
			continue

		var direction: Vector2 = to_drop.normalized()
		if direction == Vector2.ZERO:
			direction = Vector2.RIGHT.rotated(randf() * TAU)

		adjusted_position = player_node.global_position + (direction * min_distance)

	return adjusted_position
