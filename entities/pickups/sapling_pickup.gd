extends Pickup
class_name SaplingPickup

func apply_pickup(player: Player) -> bool:
	if player == null:
		return false
	if not player.has_method("pick_up_sapling"):
		push_warning("SaplingPickup: player is missing pick_up_sapling().")
		return false

	return bool(player.call("pick_up_sapling"))
