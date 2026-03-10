extends LootboxMod
class_name LootboxOddsMod

@export var weight_modifier: float = 1
@export_enum("Multiplication", "Division", "Addition") var change : String
@export var target : String

# Changes the loottable roll odds, can apply to any type of loot entry
func modify(lootTable: Array[LootEntry]) -> bool:
	for roll in lootTable:
		if roll.name == target or modification_type == "All":
			if change == "Multiplication":
				roll.weight = roll.weight * weight_modifier
				return true
			elif change == "Division":
				roll.weight = roll.weight / weight_modifier
				return true
			elif change == "Addition":
				roll.weight = roll.weight + weight_modifier
				return true
			else:
				assert(false, "LootboxMod.modify() failed: not valid change string")
				return false
	assert(false, "LootboxMod.modify() failed: Did not find targeted lootEntry")
	return false
