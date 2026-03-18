extends Resource
class_name Lootbox

## StringName used for loading and referencing this object on pickups, etc.
@export var id : StringName
## Human readable name displayed in game UI
@export var name : String
@export var color : String # TODO: Unused, probably remove
@export var description : String # TODO: Unused, probably remove
@export var modifications : Array[LootboxMod] = []
@export var lootTable: Array[LootEntry] = []


func get_rollable_entries() -> Array[LootEntry]:
	var valid_entries: Array[LootEntry] = []
	for entry in lootTable:
		if entry == null:
			continue
		if entry.weight <= 0.0:
			continue
		valid_entries.append(entry)
	return valid_entries


func roll() -> LootEntry:
	
	if lootTable.size() == 0:
		assert(false, "Lootbox.roll() failed: lootTable is empty")
		return null
	
	var total_weight: float = 0.0
	
	for x in lootTable:
		if x == null:
			continue
		if x.weight <= 0.0:
			continue
		total_weight += x.weight

	if total_weight <= 0.0:
		assert(false, "Lootbox.roll() failed: all loot entry weights are <= 0")
		return null
	
	var rand: float = randf() * total_weight
	var cumulative: float = 0.0
	
	for x in lootTable:
		if x == null:
			continue
		if x.weight <= 0.0:
			continue

		cumulative += x.weight
		if rand <= cumulative:
			return x
	
	assert(false, "Lootbox.roll() failed: no entry selected")
	return null

# Pass in a LootboxMod to add to the modifications array, will call modify on lootTable upon addition
func addMods(mod: LootboxMod):
	modifications.append(mod)
	mod.modify(lootTable)
	return null
