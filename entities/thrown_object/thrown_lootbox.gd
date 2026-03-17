extends ThrownObject
class_name ThrownLootbox

var lootbox : Lootbox
var player : Player

# Meant to be overridden with whatever should happen when the object hits the ground
func on_landed():
	open_lootbox()
	queue_free()


func open_lootbox() -> bool:
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
		"player": player,
		"current_scene": player.get_tree().current_scene,
	}

	return bool(rolled_entry.outcome.execute(context))