extends RefCounted
class_name PlayerInteractionComponent


func initialize(player: Player) -> void:
	pass

func handle_interaction_input(player: Player) -> void:
	var nearest_tree: Node = _find_nearest_harvestable_tree(player)
	var nearest_crystal: Node = _find_nearest_harvestable_crystal(player)
	var nearest_phone: Node = _find_nearest_phone(player)
	var nearest_map: Node = _find_nearest_map(player)

	var nearest_tree_distance_sq: float = INF
	if nearest_tree is Node2D:
		nearest_tree_distance_sq = player.global_position.distance_squared_to((nearest_tree as Node2D).global_position)

	var nearest_crystal_distance_sq: float = INF
	if nearest_crystal is Node2D:
		nearest_crystal_distance_sq = player.global_position.distance_squared_to((nearest_crystal as Node2D).global_position)

	var nearest_phone_distance_sq: float = INF
	if nearest_phone is Node2D:
		nearest_phone_distance_sq = player.global_position.distance_squared_to((nearest_phone as Node2D).global_position)

	var nearest_map_distance_sq: float = INF
	if nearest_map is Node2D:
		nearest_map_distance_sq = player.global_position.distance_squared_to((nearest_map as Node2D).global_position)

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
		var _harvested: int = int(nearest_tree.call("harvest_fruit", player.harvest_amount_per_interaction))
		return

	if nearest_crystal != null and nearest_interactable == nearest_crystal:
		nearest_crystal.harvest_fruit()
		return

	if nearest_interactable != null and nearest_interactable.has_method("interact"):
		nearest_interactable.call("interact", player)
		return

	try_use_item(player)

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

func _find_nearest_harvestable_tree(player: Player) -> Node:
	var trees: Array = player.get_tree().get_nodes_in_group("trees")
	var nearest_tree: Node = null
	var nearest_distance_sq: float = player.harvest_range * player.harvest_range

	for tree in trees:
		if not (tree is Node2D):
			continue
		if not tree.has_method("can_harvest") or not tree.has_method("harvest_fruit"):
			continue
		if not bool(tree.call("can_harvest")):
			continue

		var tree_node: Node2D = tree as Node2D
		var distance_sq: float = player.global_position.distance_squared_to(tree_node.global_position)
		if distance_sq > nearest_distance_sq:
			continue

		nearest_distance_sq = distance_sq
		nearest_tree = tree

	return nearest_tree

func _find_nearest_harvestable_crystal(player: Player) -> Node:
	var crystals: Array = player.get_tree().get_nodes_in_group("crystals")
	var nearest_crystal: Node = null
	var nearest_distance_sq: float = player.harvest_range * player.harvest_range

	for crystal in crystals:
		if not (crystal is Node2D):
			continue
		if not crystal.has_method("can_harvest") or not crystal.has_method("harvest_fruit"):
			continue
		if not bool(crystal.call("can_harvest")):
			continue

		var crystal_node: Node2D = crystal as Node2D
		var distance_sq: float = player.global_position.distance_squared_to(crystal_node.global_position)
		if distance_sq > nearest_distance_sq:
			continue

		nearest_distance_sq = distance_sq
		nearest_crystal = crystal

	return nearest_crystal

func _find_nearest_phone(player: Player) -> Node:
	var phones: Array = player.get_tree().get_nodes_in_group("phones")
	var nearest_phone: Node = null
	var nearest_distance_sq: float = INF

	for phone in phones:
		if not (phone is Node2D):
			continue
		if not phone.has_method("interact"):
			continue
		if phone.has_method("can_interact_with_player") and not bool(phone.call("can_interact_with_player", player)):
			continue

		var phone_node: Node2D = phone as Node2D
		var distance_sq: float = player.global_position.distance_squared_to(phone_node.global_position)
		if distance_sq >= nearest_distance_sq:
			continue

		nearest_distance_sq = distance_sq
		nearest_phone = phone

	return nearest_phone

func _find_nearest_map(player: Player) -> Node:
	var maps: Array = player.get_tree().get_nodes_in_group("maps")
	var nearest_map: Node = null
	var nearest_distance_sq: float = INF

	for map_interactable in maps:
		if not (map_interactable is Node2D):
			continue
		if not map_interactable.has_method("interact"):
			continue
		if map_interactable.has_method("can_interact_with_player") and not bool(map_interactable.call("can_interact_with_player", player)):
			continue

		var map_node: Node2D = map_interactable as Node2D
		var distance_sq: float = player.global_position.distance_squared_to(map_node.global_position)
		if distance_sq >= nearest_distance_sq:
			continue

		nearest_distance_sq = distance_sq
		nearest_map = map_interactable

	return nearest_map
