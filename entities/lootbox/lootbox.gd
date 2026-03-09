extends Resource
class_name Lootbox

@export var name : String
@export var color : String
@export var description : String
@export var modifications : Array[LootboxMod] = []
@export var lootTable: Array[LootEntry] = []


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
