extends Pickup
class_name BoxPickup

@export var lootbox_id : StringName

func apply_pickup(player : Player) -> void:
	if not LootboxGlobals.lootboxes.has(lootbox_id):
		push_error("BoxPickup.apply_pickup(): Tried to pick up lootbot with invalid ID '" + lootbox_id + "'.")
		return
	
	var lootbox = LootboxGlobals.lootboxes[lootbox_id]
	print("Picked up box" + lootbox.name)
	player.inventory.add_lootboxes(lootbox,1)
	queue_free()
