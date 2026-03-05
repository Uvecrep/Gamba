extends Resource
class_name LootBox

@export var name : String
@export var color : String
@export var description : String
@export var modifications : Array[LootBoxMod] = []
@export var lootTable: Array[LootEntry] = []


func roll() -> LootEntry:
	var total_weight := 0.0
	
	for x in lootTable:
		total_weight += x.weight
	
	var rand := randf() * total_weight
	var cumulative := 0.0
	
	for x in lootTable:
		cumulative += x.weight
		if rand <= cumulative:
			return x
	
	assert(false, "LootBox.roll() failed: no entry selected")
	return null
