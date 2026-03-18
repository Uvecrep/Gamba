extends RefCounted
class_name PlayerPickupMagnetComponent

func on_pickup_touched_radius(player: Player, area: Area2D, pickups_following_me: Array[Pickup]) -> void:
	var pickup := area.get_parent()
	if pickup == null: return
	if pickup is not Pickup: return
	if not is_instance_valid(pickup): return
	if pickups_following_me.has(pickup): return
	if not player.player_inventory.would_item_fit(pickup.item_id): return
	
	pickup.floating_towards = player
	pickups_following_me.append(pickup)

func on_pickup_touched_me(player: Player, area: Area2D, pickups_following_me: Array[Pickup]) -> void:
	var pickup := area.get_parent()
	if pickup == null: return
	if pickup is not Pickup: return
	if not is_instance_valid(pickup): return

	if player.player_inventory.add_items(pickup.item_id, 1):
		pickup.floating_towards = null
		pickup.queue_free()
		var index: int = pickups_following_me.find(pickup)
		if index >= 0:
			pickups_following_me.remove_at(index)

func on_inventory_changed(player_inventory: PlayerInventory, pickups_following_me: Array[Pickup]) -> void:
	for i in range(pickups_following_me.size() - 1, -1, -1):
		var pickup: Pickup = pickups_following_me[i]
		if not is_instance_valid(pickup):
			pickups_following_me.remove_at(i)
			continue
		if not player_inventory.would_item_fit(pickup.item_id):
			pickup.floating_towards = null
			pickups_following_me.remove_at(i)
