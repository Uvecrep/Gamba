extends CharacterBody2D

@export var speed: float = 400.0
@export var harvest_range: float = 96.0
@export var harvest_amount_per_interaction: int = 1
@export var harvest_action: StringName = &"interact"
@export var use_lootbox_action: StringName = &"use_lootbox"
@export var active_lootbox: Lootbox = preload("res://entities/lootbox/main_starting_lootbox.tres")

signal lootbox_inventory_changed(current: int, previous: int)

const PHYSICS_LAYER_WORLD: int = 1 << 0
const PHYSICS_LAYER_PLAYER: int = 1 << 1

@onready var camera: Camera2D = $Camera2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D

var inventory: PlayerInventory = PlayerInventory.new()
var world_bounds: Rect2 = Rect2()
var has_world_bounds: bool = false
var player_bounds_padding: Vector2 = Vector2.ZERO

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = PHYSICS_LAYER_PLAYER
	collision_mask = PHYSICS_LAYER_WORLD
	add_to_group("players")
	player_bounds_padding = _get_player_bounds_padding()
	_configure_world_bounds()

	if not inventory.lootboxes_changed.is_connected(_on_inventory_lootboxes_changed):
		inventory.lootboxes_changed.connect(_on_inventory_lootboxes_changed)

func get_lootbox_count() -> int:
	return inventory.get_lootbox_count()

func _on_inventory_lootboxes_changed(current: int, previous: int) -> void:
	lootbox_inventory_changed.emit(current, previous)

func get_input() -> void:
	var input_direction: Vector2 = Input.get_vector("left", "right", "up", "down")
	velocity = input_direction * speed

func _physics_process(_delta: float) -> void:
	get_input()
	move_and_slide()
	_clamp_player_to_world_bounds()

	if Input.is_action_just_pressed(harvest_action):
		_handle_interaction_input()

	if not Input.is_action_just_pressed(use_lootbox_action):
		return
	if not inventory.try_spend_lootboxes(null,1):
		return

	if not _open_active_lootbox():
		# Refund on roll/outcome failure so lootboxes are not lost by configuration errors.
		inventory.add_lootboxes(null, 1)

func _handle_interaction_input() -> void:
	var nearest_tree: Node = _find_nearest_harvestable_tree()
	var nearest_phone: Node = _find_nearest_phone()
	var nearest_map: Node = _find_nearest_map()

	var nearest_tree_distance_sq: float = INF
	if nearest_tree is Node2D:
		nearest_tree_distance_sq = global_position.distance_squared_to((nearest_tree as Node2D).global_position)

	var nearest_phone_distance_sq: float = INF
	if nearest_phone is Node2D:
		nearest_phone_distance_sq = global_position.distance_squared_to((nearest_phone as Node2D).global_position)

	var nearest_map_distance_sq: float = INF
	if nearest_map is Node2D:
		nearest_map_distance_sq = global_position.distance_squared_to((nearest_map as Node2D).global_position)

	var nearest_interactable: Node = null
	var nearest_distance_sq: float = INF

	if nearest_tree != null and nearest_tree_distance_sq < nearest_distance_sq:
		nearest_interactable = nearest_tree
		nearest_distance_sq = nearest_tree_distance_sq

	if nearest_phone != null and nearest_phone_distance_sq < nearest_distance_sq:
		nearest_interactable = nearest_phone
		nearest_distance_sq = nearest_phone_distance_sq

	if nearest_map != null and nearest_map_distance_sq < nearest_distance_sq:
		nearest_interactable = nearest_map
		nearest_distance_sq = nearest_map_distance_sq

	if nearest_interactable == null:
		return

	if nearest_interactable == nearest_tree:
		var harvested: int = int(nearest_tree.call("harvest_fruit", harvest_amount_per_interaction))
		if harvested > 0:
			inventory.add_lootboxes(null, harvested)
		return

	if nearest_interactable.has_method("interact"):
		nearest_interactable.call("interact", self)

func _find_nearest_harvestable_tree() -> Node:
	var trees: Array = get_tree().get_nodes_in_group("trees")
	var nearest_tree: Node = null
	var nearest_distance_sq: float = harvest_range * harvest_range

	for tree in trees:
		if not (tree is Node2D):
			continue
		if not tree.has_method("can_harvest") or not tree.has_method("harvest_fruit"):
			continue
		if not bool(tree.call("can_harvest")):
			continue

		var tree_node: Node2D = tree as Node2D
		var distance_sq: float = global_position.distance_squared_to(tree_node.global_position)
		if distance_sq > nearest_distance_sq:
			continue

		nearest_distance_sq = distance_sq
		nearest_tree = tree

	return nearest_tree

func _find_nearest_phone() -> Node:
	var phones: Array = get_tree().get_nodes_in_group("phones")
	var nearest_phone: Node = null
	var nearest_distance_sq: float = INF

	for phone in phones:
		if not (phone is Node2D):
			continue
		if not phone.has_method("interact"):
			continue
		if phone.has_method("can_interact_with_player") and not bool(phone.call("can_interact_with_player", self)):
			continue

		var phone_node: Node2D = phone as Node2D
		var distance_sq: float = global_position.distance_squared_to(phone_node.global_position)
		if distance_sq >= nearest_distance_sq:
			continue

		nearest_distance_sq = distance_sq
		nearest_phone = phone

	return nearest_phone

func _find_nearest_map() -> Node:
	var maps: Array = get_tree().get_nodes_in_group("maps")
	var nearest_map: Node = null
	var nearest_distance_sq: float = INF

	for map_interactable in maps:
		if not (map_interactable is Node2D):
			continue
		if not map_interactable.has_method("interact"):
			continue
		if map_interactable.has_method("can_interact_with_player") and not bool(map_interactable.call("can_interact_with_player", self)):
			continue

		var map_node: Node2D = map_interactable as Node2D
		var distance_sq: float = global_position.distance_squared_to(map_node.global_position)
		if distance_sq >= nearest_distance_sq:
			continue

		nearest_distance_sq = distance_sq
		nearest_map = map_interactable

	return nearest_map

func _open_active_lootbox() -> bool:
	if active_lootbox == null:
		push_warning("Player: active_lootbox is not configured; cannot open lootbox.")
		return false

	var rolled_entry: LootEntry = active_lootbox.roll()
	if rolled_entry == null:
		push_warning("Player: active_lootbox returned no LootEntry.")
		return false
	if rolled_entry.outcome == null:
		push_warning("Player: rolled LootEntry has no outcome.")
		return false

	var context: Dictionary = {
		"opener": self,
		"player": self,
		"current_scene": get_tree().current_scene,
	}

	return bool(rolled_entry.outcome.execute(context))

func _configure_world_bounds() -> void:
	var tile_map_layer: Node = _find_world_tile_map_layer()
	if tile_map_layer == null:
		push_warning("Player: could not find TileMapLayer for world bounds.")
		return
	if not tile_map_layer.has_method("get_used_rect") or not tile_map_layer.has_method("map_to_local"):
		push_warning("Player: world TileMapLayer is missing required bounds methods.")
		return

	var used_rect: Rect2i = tile_map_layer.call("get_used_rect")
	if used_rect.size == Vector2i.ZERO:
		push_warning("Player: world TileMapLayer has no used cells; bounds not applied.")
		return

	var tile_size: Vector2 = Vector2(32.0, 32.0)
	var tile_set: Variant = tile_map_layer.get("tile_set")
	if tile_set is TileSet:
		tile_size = Vector2((tile_set as TileSet).tile_size)

	var top_left_local: Vector2 = tile_map_layer.call("map_to_local", used_rect.position) - (tile_size * 0.5)
	var bottom_right_local: Vector2 = top_left_local + (Vector2(used_rect.size) * tile_size)

	var top_left_global: Vector2 = tile_map_layer.to_global(top_left_local)
	var bottom_right_global: Vector2 = tile_map_layer.to_global(bottom_right_local)
	var min_point: Vector2 = Vector2(min(top_left_global.x, bottom_right_global.x), min(top_left_global.y, bottom_right_global.y))
	var max_point: Vector2 = Vector2(max(top_left_global.x, bottom_right_global.x), max(top_left_global.y, bottom_right_global.y))

	world_bounds = Rect2(min_point, max_point - min_point)
	has_world_bounds = true
	_apply_camera_world_limits()
	_clamp_player_to_world_bounds()

func _apply_camera_world_limits() -> void:
	if camera == null or not has_world_bounds:
		return

	camera.limit_left = int(floor(world_bounds.position.x))
	camera.limit_top = int(floor(world_bounds.position.y))
	camera.limit_right = int(ceil(world_bounds.end.x))
	camera.limit_bottom = int(ceil(world_bounds.end.y))
	camera.limit_smoothed = true
	camera.reset_smoothing()

func _clamp_player_to_world_bounds() -> void:
	if not has_world_bounds:
		return

	var min_position: Vector2 = world_bounds.position + player_bounds_padding
	var max_position: Vector2 = world_bounds.end - player_bounds_padding

	if min_position.x > max_position.x:
		var center_x: float = (world_bounds.position.x + world_bounds.end.x) * 0.5
		min_position.x = center_x
		max_position.x = center_x
	if min_position.y > max_position.y:
		var center_y: float = (world_bounds.position.y + world_bounds.end.y) * 0.5
		min_position.y = center_y
		max_position.y = center_y

	var clamped_position: Vector2 = global_position.clamp(min_position, max_position)
	if clamped_position.is_equal_approx(global_position):
		return

	if not is_equal_approx(clamped_position.x, global_position.x):
		velocity.x = 0.0
	if not is_equal_approx(clamped_position.y, global_position.y):
		velocity.y = 0.0
	global_position = clamped_position

func _get_player_bounds_padding() -> Vector2:
	if collision_shape_2d == null or collision_shape_2d.shape == null:
		return Vector2.ZERO

	var shape: Shape2D = collision_shape_2d.shape
	if shape is RectangleShape2D:
		return (shape as RectangleShape2D).size * 0.5
	if shape is CircleShape2D:
		var radius: float = (shape as CircleShape2D).radius
		return Vector2(radius, radius)
	if shape is CapsuleShape2D:
		var capsule: CapsuleShape2D = shape as CapsuleShape2D
		return Vector2(capsule.radius, capsule.height * 0.5)

	return Vector2.ZERO

func _find_world_tile_map_layer() -> Node:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return null

	var world_node: Node = current_scene.get_node_or_null("World")
	if world_node != null:
		var world_tile_map: Node = world_node.get_node_or_null("TileMapLayer")
		if world_tile_map != null:
			return world_tile_map

	var fallback: Node = current_scene.find_child("TileMapLayer", true, false)
	if fallback != null:
		return fallback

	return null
