extends Resource
class_name LootboxMod

# Could be a bool, was messing with modification type
@export_enum("All", "One") var modification_type : String
@export var modification_description : String

# Base class for modifiers

func modify(_lootTable: Array[LootEntry]) -> bool:
	push_warning("modifiers.modify() called on base class. No modifications applied")
	return false
