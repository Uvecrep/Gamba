extends CharacterBody2D
class_name Player

signal lootbox_inventory_changed(chaos_count: int, forest_count: int, selected_kind: int)


@export var speed: float = 400.0
@export var harvest_range: float = 96.0
@export var harvest_amount_per_interaction: int = 1
@export var interact_action: StringName = &"interact"
@export var summon_command_hold_action: StringName = &"summon_command_hold"
@export var summon_command_follow_action: StringName = &"summon_command_follow"
@export var summon_command_auto_action: StringName = &"summon_command_auto"
@export var summon_selection_radius: float = 72.0
@export var summon_selection_drag_step: float = 22.0
@export var summon_selection_preview_fill_color: Color = Color(1.0, 0.95, 0.45, 0.14)
@export var summon_selection_preview_line_color: Color = Color(1.0, 0.95, 0.45, 0.95)
@export var summon_selection_preview_line_width: float = 2.0
@export var chaos_lootbox: Lootbox = preload("res://entities/lootbox/chaos_lootbox.tres")
@export var forest_lootbox: Lootbox = preload("res://entities/lootbox/forest_lootbox.tres")
@export var scroll_up_action: StringName = &"scroll_up"
@export var scroll_down_action: StringName = &"scroll_down"
@export var sapling_plant_range: float = 640.0
@export var sapling_tree_scene: PackedScene = preload("res://entities/tree/tree.tscn")

@onready var camera: Camera2D = $Camera2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var health_bar: ProgressBar = $HealthBar

var max_health: float = 100
var current_health: float

var player_inventory: PlayerInventory = PlayerInventory.new()
var world_bounds: Rect2 = Rect2()
var has_world_bounds: bool = false
var player_bounds_padding: Vector2 = Vector2.ZERO
var _is_middle_mouse_selecting: bool = false
var _middle_select_last_world_point: Vector2 = Vector2.ZERO
var _middle_select_found_summon: bool = false
var _middle_select_preview_world_point: Vector2 = Vector2.ZERO
var _summon_selection_controller: Node
var pickups_following_me: Array[Pickup] = []

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = Const.COLLISION_LAYERS.PLAYER
	collision_mask = Const.COLLISION_LAYERS.WORLD
	add_to_group("players")
	player_bounds_padding = _get_player_bounds_padding()
	_configure_world_bounds()
	player_inventory.inventory_changed.connect(_on_inventory_changed)

func get_input() -> void:
	var input_direction: Vector2 = Input.get_vector("left", "right", "up", "down")
	velocity = input_direction * speed

func _process(_delta: float) -> void:
	if health_bar == null: return
	
	health_bar.max_value = max_health
	health_bar.value = current_health

func _physics_process(_delta: float) -> void:
	if _is_middle_mouse_selecting:
		_middle_select_preview_world_point = get_global_mouse_position()
		queue_redraw()

	get_input()
	move_and_slide()
	_clamp_player_to_world_bounds()
	_handle_summon_command_shortcuts()
	
	if Input.is_action_just_pressed(interact_action):
		_handle_interaction_input()

	var mouse_scroll_delta = 0;
	if Input.is_action_just_released(scroll_up_action):
		mouse_scroll_delta += 1
	if Input.is_action_just_released(scroll_down_action):
		mouse_scroll_delta -= 1
	
	if mouse_scroll_delta != 0:
		player_inventory.selected_index = posmod(player_inventory.selected_index + mouse_scroll_delta,player_inventory.num_slots)
		player_inventory.inventory_changed.emit()
	
	var mouse_pos = get_viewport().get_mouse_position() - (get_viewport().get_visible_rect().size/2)
	camera.offset = mouse_pos * .1 # this is goofy, should plug into a better feeling damp function

func _unhandled_input(event: InputEvent) -> void:
	if _is_map_open():
		if event is InputEventMouseButton:
			var map_mouse_button: InputEventMouseButton = event as InputEventMouseButton
			if map_mouse_button.button_index == MOUSE_BUTTON_MIDDLE and not map_mouse_button.pressed:
				_reset_middle_mouse_selection_state()
		return

	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index != MOUSE_BUTTON_MIDDLE:
			return

		if mouse_button.pressed:
			_begin_middle_mouse_selection()
		else:
			_end_middle_mouse_selection()
		return

	if event is InputEventMouseMotion:
		_update_middle_mouse_drag_selection()

func get_chaos_lootbox_count() -> int:
	if chaos_lootbox == null:
		return 0

	return player_inventory.get_lootbox_count(chaos_lootbox)

func get_forest_lootbox_count() -> int:
	if forest_lootbox == null:
		return 0

	return player_inventory.get_lootbox_count(forest_lootbox)

func _emit_lootbox_inventory_changed() -> void:
	lootbox_inventory_changed.emit(get_chaos_lootbox_count(), get_forest_lootbox_count(), 0)

func _handle_interaction_input() -> void:
	var nearest_tree: Node = _find_nearest_harvestable_tree()
	var nearest_crystal: Node = _find_nearest_harvestable_crystal()
	var nearest_phone: Node = _find_nearest_phone()
	var nearest_map: Node = _find_nearest_map()

	var nearest_tree_distance_sq: float = INF
	if nearest_tree is Node2D:
		nearest_tree_distance_sq = global_position.distance_squared_to((nearest_tree as Node2D).global_position)

	var nearest_crystal_distance_sq: float = INF
	if nearest_crystal is Node2D:
		nearest_crystal_distance_sq = global_position.distance_squared_to((nearest_crystal as Node2D).global_position)

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

	if nearest_crystal != null and nearest_crystal_distance_sq < nearest_distance_sq:
		nearest_interactable = nearest_crystal
		nearest_distance_sq = nearest_crystal_distance_sq

	if nearest_phone != null and nearest_phone_distance_sq < nearest_distance_sq:
		nearest_interactable = nearest_phone
		nearest_distance_sq = nearest_phone_distance_sq

	if nearest_map != null and nearest_map_distance_sq < nearest_distance_sq:
		nearest_interactable = nearest_map
		nearest_distance_sq = nearest_map_distance_sq

	if nearest_tree != null and nearest_interactable == nearest_tree:
		var _harvested: int = int(nearest_tree.call("harvest_fruit", harvest_amount_per_interaction))
		# if harvested > 0:
			# player_inventory.add_lootboxes(forest_lootbox, harvested)
		return

	if nearest_crystal != null and nearest_interactable == nearest_crystal:
		nearest_crystal.harvest_fruit()
		return

	if nearest_interactable != null and nearest_interactable.has_method("interact"):
		nearest_interactable.call("interact", self)
		return
	
	_try_use_item()

func _try_use_item() -> bool:
	var selected_item = player_inventory.inventory_items[player_inventory.selected_index]
	if selected_item == &"":
		return false
	
	if selected_item == &"sapling":
		if not _try_plant_sapling_near_house():
			return false
		player_inventory.remove_items(player_inventory.selected_index,1)
		return true
	
	if selected_item.begins_with("lootbox_"):
		var box_id = StringName(selected_item.split("_")[1])
		if not LootboxGlobals.lootboxes.has(box_id):
			push_warning("Player: Tried to open a lootbox '" + box_id + "' which is not present in the global array")
			return false
		if not _open_lootbox(LootboxGlobals.lootboxes[box_id]):
			return false
		player_inventory.remove_items(player_inventory.selected_index,1)
		return true
	
	return false

func _try_plant_sapling_near_house() -> bool:

	var target_house: Node = _find_nearest_house_for_planting()
	if target_house == null:
		return false
	if sapling_tree_scene == null:
		push_warning("Player: sapling_tree_scene is not configured; cannot plant sapling.")
		return false

	var new_tree: Node = sapling_tree_scene.instantiate()
	if not (new_tree is Node2D):
		push_warning("Player: sapling_tree_scene root must inherit from Node2D.")
		new_tree.queue_free()
		return false

	var parent_node: Node = get_tree().current_scene
	if parent_node == null:
		parent_node = get_parent()
	if parent_node == null:
		push_warning("Player: could not determine parent scene for planted tree.")
		new_tree.queue_free()
		return false

	parent_node.add_child(new_tree)
	(new_tree as Node2D).global_position = _get_plant_position(target_house as Node2D)
	return true

func _find_nearest_house_for_planting() -> Node:
	var houses: Array = get_tree().get_nodes_in_group("house")
	var nearest_house: Node = null
	var nearest_distance_sq: float = sapling_plant_range * sapling_plant_range

	for house in houses:
		if not (house is Node2D):
			continue

		var house_node: Node2D = house as Node2D
		var distance_sq: float = global_position.distance_squared_to(house_node.global_position)
		if distance_sq > nearest_distance_sq:
			continue

		nearest_distance_sq = distance_sq
		nearest_house = house

	return nearest_house

func _get_plant_position(target_house: Node2D) -> Vector2:
	var plant_position: Vector2 = global_position
	var from_house: Vector2 = plant_position - target_house.global_position
	var minimum_house_clearance: float = 72.0

	if from_house.length() >= minimum_house_clearance:
		return plant_position

	var direction: Vector2 = from_house.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.DOWN

	return target_house.global_position + (direction * minimum_house_clearance)

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

func _find_nearest_harvestable_crystal() -> Node:
	var crystals: Array = get_tree().get_nodes_in_group("crystals")
	var nearest_crystal: Node = null
	var nearest_distance_sq: float = harvest_range * harvest_range

	for crystal in crystals:
		if not (crystal is Node2D):
			continue
		if not crystal.has_method("can_harvest") or not crystal.has_method("harvest_fruit"):
			continue
		if not bool(crystal.call("can_harvest")):
			continue

		var crystal_node: Node2D = crystal as Node2D
		var distance_sq: float = global_position.distance_squared_to(crystal_node.global_position)
		if distance_sq > nearest_distance_sq:
			continue

		nearest_distance_sq = distance_sq
		nearest_crystal = crystal

	return nearest_crystal

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

func _open_lootbox(lootbox: Lootbox) -> bool:
	if lootbox == null:
		push_warning("Player: lootbox resource is not configured; cannot open lootbox.")
		return false

	var rolled_entry: LootEntry = lootbox.roll()
	if rolled_entry == null:
		push_warning("Player: lootbox returned no LootEntry.")
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
		push_warning("Player: could not find TileMapGround for world bounds.")
		return
	if not tile_map_layer.has_method("get_used_rect") or not tile_map_layer.has_method("map_to_local"):
		push_warning("Player: world TileMapGround is missing required bounds methods.")
		return

	var used_rect: Rect2i = tile_map_layer.call("get_used_rect")
	if used_rect.size == Vector2i.ZERO:
		push_warning("Player: world TileMapGround has no used cells; bounds not applied.")
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
		var world_tile_map: Node = world_node.get_node_or_null("TileMapGround")
		if world_tile_map != null:
			return world_tile_map

	var fallback: Node = current_scene.find_child("TileMapGround", true, false)
	if fallback != null:
		return fallback

	return null

func _begin_middle_mouse_selection() -> void:
	if _is_map_open():
		return

	_is_middle_mouse_selecting = true
	_middle_select_found_summon = false
	_middle_select_last_world_point = get_global_mouse_position()
	_middle_select_preview_world_point = _middle_select_last_world_point
	queue_redraw()
	if _select_summons_in_world_radius(_middle_select_last_world_point):
		_middle_select_found_summon = true

func _end_middle_mouse_selection() -> void:
	if not _is_middle_mouse_selecting:
		return

	if not _middle_select_found_summon:
		_clear_selected_summons()

	_reset_middle_mouse_selection_state()

func _update_middle_mouse_drag_selection() -> void:
	if not _is_middle_mouse_selecting:
		return
	if _is_map_open():
		return

	var mouse_world_position: Vector2 = get_global_mouse_position()
	if _middle_select_last_world_point.distance_to(mouse_world_position) < maxf(summon_selection_drag_step, 1.0):
		return

	_middle_select_last_world_point = mouse_world_position
	_middle_select_preview_world_point = mouse_world_position
	if _select_summons_in_world_radius(mouse_world_position):
		_middle_select_found_summon = true

func _reset_middle_mouse_selection_state() -> void:
	_is_middle_mouse_selecting = false
	_middle_select_found_summon = false
	queue_redraw()

func _select_summons_in_world_radius(world_position: Vector2) -> bool:
	var selection_controller: Node = _get_summon_selection_controller()
	if selection_controller == null:
		return false
	if not selection_controller.has_method("select_summons_in_world_circle"):
		return false

	var matched_count: int = int(selection_controller.call("select_summons_in_world_circle", world_position, summon_selection_radius, true))
	return matched_count > 0

func _clear_selected_summons() -> void:
	var selection_controller: Node = _get_summon_selection_controller()
	if selection_controller == null:
		return
	if not selection_controller.has_method("clear_selection"):
		return

	selection_controller.call("clear_selection")

func _handle_summon_command_shortcuts() -> void:
	if _is_map_open():
		return

	var selection_controller: Node = _get_summon_selection_controller()
	if selection_controller == null:
		return

	if Input.is_action_just_pressed(summon_command_hold_action) and selection_controller.has_method("hold_selected_summons"):
		selection_controller.call("hold_selected_summons")

	if Input.is_action_just_pressed(summon_command_follow_action) and selection_controller.has_method("follow_selected_summons"):
		selection_controller.call("follow_selected_summons")

	if Input.is_action_just_pressed(summon_command_auto_action) and selection_controller.has_method("auto_selected_summons"):
		selection_controller.call("auto_selected_summons")

func _get_summon_selection_controller() -> Node:
	if is_instance_valid(_summon_selection_controller):
		return _summon_selection_controller

	var controllers: Array = get_tree().get_nodes_in_group("summon_selection_controllers")
	for controller in controllers:
		if is_instance_valid(controller):
			_summon_selection_controller = controller
			return _summon_selection_controller

	for map_node in get_tree().get_nodes_in_group("maps"):
		if not is_instance_valid(map_node):
			continue
		if not map_node.has_method("get_minimap_control"):
			continue

		var minimap_control: Variant = map_node.call("get_minimap_control")
		if minimap_control is Node:
			_summon_selection_controller = minimap_control as Node
			return _summon_selection_controller

	return null

func _is_map_open() -> bool:
	for map_node in get_tree().get_nodes_in_group("maps"):
		if not is_instance_valid(map_node):
			continue
		if map_node.has_method("is_map_open") and bool(map_node.call("is_map_open")):
			return true

	return false

func _draw() -> void:
	if not _is_middle_mouse_selecting:
		return

	var local_center: Vector2 = to_local(_middle_select_preview_world_point)
	draw_circle(local_center, summon_selection_radius, summon_selection_preview_fill_color)
	draw_arc(local_center, summon_selection_radius, 0.0, TAU, 48, summon_selection_preview_line_color, summon_selection_preview_line_width, true)

func _on_pickup_touched_radius(area: Area2D) -> void:
	var pickup = area.get_parent()
	if pickup == null: return
	if pickup is not Pickup: return
	if not is_instance_valid(pickup): return
	if pickups_following_me.has(pickup): return
	
	if not player_inventory.would_item_fit(pickup.item_id):
		return
	
	pickup.floating_towards = self
	pickups_following_me.append(pickup)

func _on_pickup_touched_me(area: Area2D) -> void:
	var pickup = area.get_parent()
	if pickup == null: return
	if pickup is not Pickup: return
	if not is_instance_valid(pickup): return
	if player_inventory.add_items(pickup.item_id,1):
		pickup.floating_towards = null
		pickup.queue_free()
		var index = pickups_following_me.find(pickup)
		if index >= 0:
			pickups_following_me.remove_at(index)

func _on_inventory_changed() -> void:
	# Pickups that were following me should stop if they would no longer fit in my inventory
	var invalid_pickups : Array[Pickup] = []
	var pickups_no_longer_following : Array[Pickup] = []
	for p in pickups_following_me:
		if not is_instance_valid(p):
			invalid_pickups.append(p)
			continue
		if !player_inventory.would_item_fit(p.item_id):
			p.floating_towards = null
			pickups_no_longer_following.append(p)
	for p in invalid_pickups:
		var invalid_index = pickups_following_me.find(p)
		if invalid_index >= 0:
			pickups_following_me.remove_at(invalid_index)
	for p in pickups_no_longer_following:
		var index = pickups_following_me.find(p)
		if index >= 0:
			pickups_following_me.remove_at(index)

	_emit_lootbox_inventory_changed()
