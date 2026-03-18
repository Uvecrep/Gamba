extends CharacterBody2D
class_name Player


@export var interact_action: StringName = &"interact"
@export var summon_command_hold_action: StringName = &"summon_command_hold"
@export var summon_command_follow_action: StringName = &"summon_command_follow"
@export var summon_command_auto_action: StringName = &"summon_command_auto"
@export var scroll_up_action: StringName = &"scroll_up"
@export var scroll_down_action: StringName = &"scroll_down"

@export var speed: float = 400.0
@export var harvest_range: float = 96.0
@export var harvest_amount_per_interaction: int = 1
@export var summon_selection_radius: float = 72.0
@export var summon_selection_drag_step: float = 22.0
@export var summon_selection_preview_fill_color: Color = Color(1.0, 0.95, 0.45, 0.14)
@export var summon_selection_preview_line_color: Color = Color(1.0, 0.95, 0.45, 0.95)
@export var summon_selection_preview_line_width: float = 2.0

@export var sapling_plant_range: float = 640.0
@export var sapling_tree_scene: PackedScene = preload("res://entities/tree/tree.tscn")
@export var max_health: float = 180.0
@export var respawn_delay_seconds: float = 1.05
@export var respawn_invulnerability_seconds: float = 1.5
@export var respawn_distance_from_house: float = 92.0
@export var house_regen_radius: float = 180.0
@export var house_regen_per_second: float = 2.0
@export var house_regen_tick_interval: float = 0.5

@onready var camera: Camera2D = $Camera2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var health_bar: ProgressBar = $HealthBar

var current_health: float = 0.0

var player_inventory: PlayerInventory = PlayerInventory.new()
var world_bounds: Rect2 = Rect2()
var has_world_bounds: bool = false
var player_bounds_padding: Vector2 = Vector2.ZERO
var pickups_following_me: Array[Pickup] = []
var _perf_debug: PerfDebugService

var _movement_component: PlayerMovementComponent = PlayerMovementComponent.new()
var _world_bounds_component: PlayerWorldBoundsComponent = PlayerWorldBoundsComponent.new()
var _pickup_magnet_component: PlayerPickupMagnetComponent = PlayerPickupMagnetComponent.new()
var _summon_command_component: PlayerSummonCommandComponent = PlayerSummonCommandComponent.new()
var _health_component: PlayerHealthComponent = PlayerHealthComponent.new()
var _interaction_component: PlayerInteractionComponent = PlayerInteractionComponent.new()

@export var pickup_packed_scene: PackedScene
@export var thrown_lootbox_packed_scene: PackedScene
@export var thrown_sapling_packed_scene: PackedScene
@export var thrown_pickup_packed_scene: PackedScene
@export var toss_reticle: Node2D
@export var toss_line: Line2D
var _is_tossing = false

func _ready() -> void:
	_perf_debug = get_node_or_null("/root/PerfDebug") as PerfDebugService
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = Const.COLLISION_LAYERS.PLAYER
	collision_mask = Const.COLLISION_LAYERS.WORLD
	add_to_group("players")

	_world_bounds_component.initialize(self)
	_health_component.initialize(self)
	_interaction_component.initialize(self)

	player_inventory.inventory_changed.connect(_pickup_magnet_component.on_inventory_changed.bind(player_inventory,pickups_following_me))

func get_input() -> void:
	_movement_component.get_input(self)

func _process(delta: float) -> void:
	_health_component.process(self, delta)
	if _health_component._invulnerability_time_left > 0.0:
		_health_component._invulnerability_time_left = maxf(_health_component._invulnerability_time_left - delta, 0.0)
	_update_house_regen(delta)
	
	_update_health_bar()
	
	if _is_tossing:
		toss_reticle.position = get_local_mouse_position()
		toss_line.points[1] = get_local_mouse_position()

func _physics_process(_delta: float) -> void:
	if _health_component.is_dead():
		velocity = Vector2.ZERO
		return

	_summon_command_component.physics_update(self)
	get_input()
	move_and_slide()
	_clamp_player_to_world_bounds()
	_handle_summon_command_shortcuts()

	if Input.is_action_just_pressed(interact_action):
		_handle_interaction_input()

	_movement_component.handle_scroll_and_camera(self)

func _input(event: InputEvent) -> void:
	if _health_component.is_dead():
		return

	_summon_command_component.handle_input(self, event)

func is_dead() -> bool:
	return _health_component.is_dead()

func take_hit(amount: float, source: Node2D = null, options: Dictionary = {}) -> void:
	_health_component.take_hit(self, amount, source, options)

func take_damage(amount: float) -> void:
	_health_component.take_damage(self, amount)

func heal(amount: float) -> void:
	_health_component.heal(self, amount)

func grant_hit_shield() -> bool:
	return _health_component.grant_hit_shield(self)

func has_hit_shield() -> bool:
	return _health_component.has_hit_shield()

func _update_house_regen(delta: float) -> void:
	_health_component.update_house_regen(self, delta)

func _begin_respawn_flow() -> void:
	_health_component.begin_respawn_flow(self)

func _run_respawn_timer() -> void:
	_health_component.run_respawn_timer(self)

func _respawn_player() -> void:
	_health_component.respawn_player(self)

func _get_respawn_position() -> Vector2:
	return _health_component.get_respawn_position(self)

func _find_nearest_house_anywhere() -> Node2D:
	return _health_component.find_nearest_house_anywhere(self)

func _setup_death_indicator() -> void:
	_health_component.setup_death_indicator(self)

func _show_death_indicator() -> void:
	_health_component.show_death_indicator(self)

func _hide_death_indicator() -> void:
	_health_component.hide_death_indicator()

func _update_health_bar() -> void:
	_health_component.update_health_bar(self)

func _handle_interaction_input() -> void:
	_interaction_component.handle_interaction_input(self)

func _try_use_item() -> bool:
	return _interaction_component.try_use_item(self)

func _try_plant_sapling_near_house() -> bool:
	return _interaction_component.try_plant_sapling_near_house(self)

func can_plant_sapling_here() -> bool:
	return _interaction_component.can_plant_sapling_here(self)

func _open_lootbox(lootbox: Lootbox) -> bool:
	return _interaction_component.open_lootbox(self, lootbox)

func _configure_world_bounds() -> void:
	_world_bounds_component.configure_world_bounds(self)

func _apply_camera_world_limits() -> void:
	_world_bounds_component.apply_camera_world_limits(self)

func _clamp_player_to_world_bounds() -> void:
	_world_bounds_component.clamp_player_to_world_bounds(self)

func _get_node_bounds_padding(node_2d: Node2D) -> Vector2:
	return _world_bounds_component.get_node_bounds_padding(node_2d)

func _get_player_bounds_padding() -> Vector2:
	return player_bounds_padding

func _find_world_tile_map_layer() -> Node:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return null

	var world_node: Node = current_scene.get_node_or_null("World")
	if world_node != null:
		var world_tile_map: Node = world_node.get_node_or_null("TileMapGround")
		if world_tile_map != null:
			return world_tile_map

	return current_scene.find_child("TileMapGround", true, false)

func _begin_middle_mouse_selection() -> void:
	_summon_command_component.begin_middle_mouse_selection(self)

func _end_middle_mouse_selection() -> void:
	_summon_command_component.end_middle_mouse_selection(self)

func _update_middle_mouse_drag_selection() -> void:
	_summon_command_component.update_middle_mouse_drag_selection(self)

func _reset_middle_mouse_selection_state() -> void:
	_summon_command_component.reset_middle_mouse_selection_state(self)

func _clear_selected_summons() -> void:
	_summon_command_component.clear_selected_summons(self)

func _handle_summon_command_shortcuts() -> void:
	_summon_command_component.handle_summon_command_shortcuts(self)

func _is_map_open() -> bool:
	return _summon_command_component.is_map_open(self)

func _draw() -> void:
	_summon_command_component.draw(self)

func _on_pickup_touched_radius(area: Area2D) -> void:
	_pickup_magnet_component.on_pickup_touched_radius(self, area, pickups_following_me)

func _on_pickup_touched_me(area: Area2D) -> void:
	_pickup_magnet_component.on_pickup_touched_me(self, area, pickups_following_me)

func _perf_mark_scope(scope_name: StringName, start_us: int, metadata: Dictionary = {}) -> void:
	if not is_instance_valid(_perf_debug):
		return

	_perf_debug.add_scope_time_us(scope_name, Time.get_ticks_usec() - start_us, metadata)

func _perf_inc(counter_name: StringName, amount: int = 1) -> void:
	if not is_instance_valid(_perf_debug):
		return

	_perf_debug.increment_counter(counter_name, amount)

func _perf_mark_event(event_name: String, metadata: Dictionary = {}) -> void:
	if not is_instance_valid(_perf_debug):
		return

	_perf_debug.mark_event(event_name, metadata)

func _try_perform_item_action(_is_left : bool) -> void:
	if player_inventory.inventory_item_counts[player_inventory.selected_index] == 0: return

	# right click immediately drops an item
	if not _is_left:
		# If we're dropping, place the item down. Need to have support for more actions
		var held_item_id = player_inventory.inventory_items[player_inventory.selected_index]
		if not player_inventory.remove_items(player_inventory.selected_index,1): return


		var dropped_pickup : Pickup = pickup_packed_scene.instantiate()
		get_parent().add_child(dropped_pickup)
		dropped_pickup.global_position = position + ((get_global_mouse_position() - global_position).normalized() * 100)
		dropped_pickup.set_data(held_item_id)
		return
	
	# TODO Do something with left and right click actions here
	
	_begin_tossing()

func _begin_tossing() -> void:
	if _is_tossing: return
	
	toss_reticle.visible = true
	toss_line.visible = true
	_is_tossing = true

func _stop_tossing() -> void:
	if not _is_tossing: return
	var held_item_id = player_inventory.inventory_items[player_inventory.selected_index]
	if not player_inventory.remove_items(player_inventory.selected_index,1): return
	
	var lootbox : Lootbox
	if held_item_id.begins_with("lootbox_"):
		var box_id: StringName = StringName(held_item_id.split("_")[1])
		if not LootboxGlobals.lootboxes.has(box_id):
			push_warning("Player: Tried to open a lootbox '" + box_id + "' which is not present in the global array")
			return
		lootbox = LootboxGlobals.lootboxes[box_id]
	
	var thrown_object : ThrownObject
	if lootbox != null:
		var thrown_lootbox : ThrownLootbox = thrown_lootbox_packed_scene.instantiate()
		thrown_lootbox.player = self
		thrown_lootbox.lootbox = lootbox
		thrown_object = thrown_lootbox as ThrownObject
	elif held_item_id == &"sapling":
		var thrown_sapling : ThrownSapling = thrown_sapling_packed_scene.instantiate()
		thrown_object = thrown_sapling as ThrownObject
	else:
		# Maybe it's a pickup?
		var thrown_pickup : ThrownPickup = thrown_pickup_packed_scene.instantiate()
		thrown_pickup.pickup_item_id = held_item_id
		thrown_object = thrown_pickup
		
	if not thrown_object: return

	get_parent().add_child(thrown_object)
	thrown_object.global_position = get_global_mouse_position()
	thrown_object.target_pos = get_global_mouse_position()
	thrown_object.start_pos = global_position
	
	
	toss_reticle.visible = false
	toss_line.visible = false
	_is_tossing = false
