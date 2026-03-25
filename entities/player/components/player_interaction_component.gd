extends RefCounted
class_name PlayerInteractionComponent

const HARVEST_NODE_SCRIPT: Script = preload("res://entities/shared/harvest_node.gd")


func initialize(_player: Player) -> void:
	pass

func handle_interaction_input(player: Player) -> void:
	var nearest_harvest_node: Node2D = _find_nearest_harvestable_node(player)
	var nearest_phone: PhoneInteractable = _find_nearest_phone(player)
	var nearest_map: MapInteractable = _find_nearest_map(player)
	var nearest_shop: ShopInteractable = _find_nearest_shop(player)
	var nearest_blood: Node2D = _find_nearest_in_group(player, "blood_confluence")
	var nearest_soul: Node2D = _find_nearest_in_group(player, "soul_tower")

	var nearest_harvest_distance_sq: float = INF
	if nearest_harvest_node != null:
		nearest_harvest_distance_sq = player.global_position.distance_squared_to(nearest_harvest_node.global_position)

	var nearest_phone_distance_sq: float = INF
	if nearest_phone != null:
		nearest_phone_distance_sq = player.global_position.distance_squared_to(nearest_phone.global_position)

	var nearest_map_distance_sq: float = INF
	if nearest_map != null:
		nearest_map_distance_sq = player.global_position.distance_squared_to(nearest_map.global_position)

	var nearest_shop_distance_sq: float = INF
	if nearest_shop != null:
		nearest_shop_distance_sq = player.global_position.distance_squared_to(nearest_shop.global_position)

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

	if nearest_shop != null and nearest_shop_distance_sq < nearest_distance_sq:
		nearest_interactable = nearest_shop
		nearest_distance_sq = nearest_shop_distance_sq

	if nearest_blood != null and player.global_position.distance_squared_to(nearest_blood.global_position) < nearest_distance_sq:
		nearest_interactable = nearest_blood
		nearest_distance_sq = player.global_position.distance_squared_to(nearest_blood.global_position)

	if nearest_soul != null and player.global_position.distance_squared_to(nearest_soul.global_position) < nearest_distance_sq:
		nearest_interactable = nearest_soul
		nearest_distance_sq = player.global_position.distance_squared_to(nearest_soul.global_position)

	if nearest_harvest_node != null and nearest_interactable == nearest_harvest_node:
		nearest_harvest_node.call("harvest_fruit", player.harvest_amount_per_interaction)
		return

	if nearest_interactable is PhoneInteractable:
		(nearest_interactable as PhoneInteractable).interact(player)
		return
	if nearest_interactable is MapInteractable:
		(nearest_interactable as MapInteractable).interact(player)
		return
	if nearest_interactable is ShopInteractable:
		(nearest_interactable as ShopInteractable).interact(player)
		return
	
	if nearest_interactable is BloodConfluence:
		(nearest_interactable as BloodConfluence).try_purchase_lootbox(player)
		return

	if nearest_interactable is SoulTower:
		(nearest_interactable as SoulTower).interact(player)
		return

func can_plant_sapling_here(player: Player) -> bool:
	if player.is_dead(): return false
	if player.sapling_tree_scene == null: return false

	return _find_nearest_house_for_planting(player) != null

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

func _find_nearest_harvestable_node(player: Player) -> Node2D:
	var harvest_nodes: Array = player.get_tree().get_nodes_in_group("harvest_nodes")
	var nearest_node: Node2D = null
	var nearest_distance_sq: float = player.harvest_range * player.harvest_range

	for harvest_node in harvest_nodes:
		if not (harvest_node is HARVEST_NODE_SCRIPT):
			continue
		if harvest_node is BloodConfluence:
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

func _find_nearest_shop(player: Player) -> ShopInteractable:
	var shops: Array = player.get_tree().get_nodes_in_group("shops")
	var nearest_shop: ShopInteractable = null
	var nearest_distance_sq: float = INF

	for shop_interactable in shops:
		if not shop_interactable is ShopInteractable:
			continue
		var shop_node: ShopInteractable = shop_interactable as ShopInteractable
		if not shop_node.can_interact_with_player(player):
			continue

		var distance_sq: float = player.global_position.distance_squared_to(shop_node.global_position)
		if distance_sq >= nearest_distance_sq:
			continue

		nearest_distance_sq = distance_sq
		nearest_shop = shop_node

	return nearest_shop

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
