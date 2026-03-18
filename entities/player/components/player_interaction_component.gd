extends RefCounted
class_name PlayerInteractionComponent

const HARVEST_NODE_SCRIPT: Script = preload("res://entities/shared/harvest_node.gd")


func initialize(_player: Player) -> void:
	pass

func handle_interaction_input(player: Player) -> void:
	var nearest_harvest_node: Node2D = _find_nearest_harvestable_node(player)
	var nearest_phone: PhoneInteractable = _find_nearest_phone(player)
	var nearest_map: MapInteractable = _find_nearest_map(player)
	var nearest_blood: Node2D = _find_nearest_in_group(player, "blood_confluence")

	var nearest_harvest_distance_sq: float = INF
	if nearest_harvest_node != null:
		nearest_harvest_distance_sq = player.global_position.distance_squared_to(nearest_harvest_node.global_position)

	var nearest_phone_distance_sq: float = INF
	if nearest_phone != null:
		nearest_phone_distance_sq = player.global_position.distance_squared_to(nearest_phone.global_position)

	var nearest_map_distance_sq: float = INF
	if nearest_map != null:
		nearest_map_distance_sq = player.global_position.distance_squared_to(nearest_map.global_position)

	var nearest_interactable: Node = null
	var nearest_distance_sq: float = INF

	if nearest_harvest_node != null and nearest_harvest_distance_sq < nearest_distance_sq:
		nearest_interactable = nearest_harvest_node
		nearest_distance_sq = nearest_harvest_distance_sq

	if nearest_phone != null and nearest_phone_distance_sq < nearest_distance_sq:
		nearest_interactable = nearest_phone
		nearest_distance_sq = nearest_phone_distance_sq

	if nearest_map != null and nearest_map_distance_sq < nearest_distance_sq:
		nearest_interactable = nearest_map
		nearest_distance_sq = nearest_map_distance_sq

	if nearest_blood != null and player.global_position.distance_squared_to(nearest_blood.global_position) < nearest_distance_sq:
		nearest_interactable = nearest_blood
		nearest_distance_sq = player.global_position.distance_squared_to(nearest_blood.global_position)


	if nearest_harvest_node != null and nearest_interactable == nearest_harvest_node:
		nearest_harvest_node.call("harvest_fruit", player.harvest_amount_per_interaction)
		return

	if nearest_interactable is PhoneInteractable:
		(nearest_interactable as PhoneInteractable).interact(player)
		return
	if nearest_interactable is MapInteractable:
		(nearest_interactable as MapInteractable).interact(player)
		return
	
	if nearest_interactable is BloodConfluence:
		(nearest_interactable as BloodConfluence).try_purchase_lootbox(player)
		return


	# TODO Just implemented this logic living in the thrown items. Should figure that out more. This 'use_item' code will change
	#try_use_item(player)

func try_use_item(player: Player) -> bool:
	if player.is_dead():
		return false

	var selected_item: StringName = player.player_inventory.inventory_items[player.player_inventory.selected_index]
	if selected_item == &"":
		return false

	if selected_item == &"sapling":
		if not try_plant_sapling_near_house(player):
			return false
		player.player_inventory.remove_items(player.player_inventory.selected_index, 1)
		return true

	if selected_item.begins_with("lootbox_"):
		var box_id: StringName = StringName(selected_item.split("_")[1])
		if not LootboxGlobals.lootboxes.has(box_id):
			push_warning("Player: Tried to open a lootbox '" + box_id + "' which is not present in the global array")
			return false
		if not open_lootbox(player, LootboxGlobals.lootboxes[box_id]):
			return false
		player.player_inventory.remove_items(player.player_inventory.selected_index, 1)
		return true

	return false

func try_plant_sapling_near_house(player: Player) -> bool:
	var plant_start_us: int = Time.get_ticks_usec()

	var target_house: Node = _find_nearest_house_for_planting(player)
	if target_house == null:
		player._perf_mark_scope(&"player.try_plant_sapling", plant_start_us, {
			"status": "no_house",
		})
		return false
	if player.sapling_tree_scene == null:
		push_warning("Player: sapling_tree_scene is not configured; cannot plant sapling.")
		player._perf_mark_scope(&"player.try_plant_sapling", plant_start_us, {
			"status": "missing_scene",
		})
		return false

	var new_tree: Node = player.sapling_tree_scene.instantiate()
	if not (new_tree is Node2D):
		push_warning("Player: sapling_tree_scene root must inherit from Node2D.")
		new_tree.queue_free()
		player._perf_mark_scope(&"player.try_plant_sapling", plant_start_us, {
			"status": "invalid_tree_root",
		})
		return false

	var new_tree_2d: Node2D = new_tree as Node2D
	var plant_position: Vector2 = _get_plant_position(player, target_house as Node2D, new_tree_2d)

	var parent_node: Node = player.get_tree().current_scene
	if parent_node == null:
		parent_node = player.get_parent()
	if parent_node == null:
		push_warning("Player: could not determine parent scene for planted tree.")
		new_tree_2d.queue_free()
		player._perf_mark_scope(&"player.try_plant_sapling", plant_start_us, {
			"status": "missing_parent",
		})
		return false

	parent_node.add_child(new_tree_2d)
	new_tree_2d.global_position = plant_position
	player._perf_inc(&"player.tree_placements")
	player._perf_mark_event("player_tree_placed", {
		"x": snappedf(plant_position.x, 1.0),
		"y": snappedf(plant_position.y, 1.0),
	})
	player._perf_mark_scope(&"player.try_plant_sapling", plant_start_us, {
		"status": "success",
	})
	return true

func can_plant_sapling_here(player: Player) -> bool:
	if player.is_dead(): return false
	if player.sapling_tree_scene == null: return false

	return _find_nearest_house_for_planting(player) != null

func open_lootbox(player: Player, lootbox: Lootbox) -> bool:
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
		"opener": player,
		"player": player,
		"current_scene": player.get_tree().current_scene,
	}

	return bool(rolled_entry.outcome.execute(context))

func _find_nearest_house_for_planting(player: Player) -> Node:
	var houses: Array = player.get_tree().get_nodes_in_group("house")
	var nearest_house: Node = null
	var nearest_distance_sq: float = player.sapling_plant_range * player.sapling_plant_range

	for house in houses:
		if not (house is Node2D):
			continue

		var house_node: Node2D = house as Node2D
		var distance_sq: float = player.global_position.distance_squared_to(house_node.global_position)
		if distance_sq > nearest_distance_sq:
			continue

		nearest_distance_sq = distance_sq
		nearest_house = house

	return nearest_house

func _get_plant_position(player: Player, target_house: Node2D, tree_node: Node2D) -> Vector2:
	var from_house: Vector2 = player.global_position - target_house.global_position
	var outward_direction: Vector2 = from_house.normalized()
	if outward_direction == Vector2.ZERO:
		outward_direction = Vector2.DOWN

	var player_radius: float = maxf(player.player_bounds_padding.x, player.player_bounds_padding.y)
	var tree_padding: Vector2 = player._get_node_bounds_padding(tree_node)
	var tree_radius: float = maxf(tree_padding.x, tree_padding.y)

	var adjacent_distance: float = maxf(player_radius + tree_radius + 8.0, 48.0)
	var plant_position: Vector2 = player.global_position + (outward_direction * adjacent_distance)

	var minimum_house_clearance: float = 72.0
	var from_house_to_plant: Vector2 = plant_position - target_house.global_position
	if from_house_to_plant.length() < minimum_house_clearance:
		var clearance_direction: Vector2 = from_house_to_plant.normalized()
		if clearance_direction == Vector2.ZERO:
			clearance_direction = outward_direction
		plant_position = target_house.global_position + (clearance_direction * minimum_house_clearance)

	return plant_position

func _find_nearest_harvestable_node(player: Player) -> Node2D:
	var harvest_nodes: Array = player.get_tree().get_nodes_in_group("harvest_nodes")
	var nearest_node: Node2D = null
	var nearest_distance_sq: float = player.harvest_range * player.harvest_range

	for harvest_node in harvest_nodes:
		if not (harvest_node is HARVEST_NODE_SCRIPT):
			continue
		if not (harvest_node is Node2D):
			continue
		if not bool(harvest_node.call("can_harvest")):
			continue
		var typed_node: Node2D = harvest_node as Node2D

		var distance_sq: float = player.global_position.distance_squared_to(typed_node.global_position)
		if distance_sq > nearest_distance_sq:
			continue

		nearest_distance_sq = distance_sq
		nearest_node = typed_node

	return nearest_node

func _find_nearest_phone(player: Player) -> PhoneInteractable:
	var phones: Array = player.get_tree().get_nodes_in_group("phones")
	var nearest_phone: PhoneInteractable = null
	var nearest_distance_sq: float = INF

	for phone in phones:
		if not phone is PhoneInteractable:
			continue
		var phone_node: PhoneInteractable = phone as PhoneInteractable
		if not phone_node.can_interact_with_player(player):
			continue

		var distance_sq: float = player.global_position.distance_squared_to(phone_node.global_position)
		if distance_sq >= nearest_distance_sq:
			continue

		nearest_distance_sq = distance_sq
		nearest_phone = phone_node

	return nearest_phone

func _find_nearest_map(player: Player) -> MapInteractable:
	var maps: Array = player.get_tree().get_nodes_in_group("maps")
	var nearest_map: MapInteractable = null
	var nearest_distance_sq: float = INF

	for map_interactable in maps:
		if not map_interactable is MapInteractable:
			continue
		var map_node: MapInteractable = map_interactable as MapInteractable
		if not map_node.can_interact_with_player(player):
			continue

		var distance_sq: float = player.global_position.distance_squared_to(map_node.global_position)
		if distance_sq >= nearest_distance_sq:
			continue

		nearest_distance_sq = distance_sq
		nearest_map = map_node

	return nearest_map

func _find_nearest_in_group(player: Player, group_name : String) -> Node2D:
	var interactables: Array = player.get_tree().get_nodes_in_group(group_name)
	
	var nearest_distance_sq: float = INF
	var nearest_interactable: Node2D

	for node in interactables:
		var distance_sq: float = player.global_position.distance_squared_to(node.global_position)
		if distance_sq >= nearest_distance_sq:
			continue

		nearest_distance_sq = distance_sq
		nearest_interactable = node

	return nearest_interactable
