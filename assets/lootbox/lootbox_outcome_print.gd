extends LootboxOutcome
class_name LootboxOutcomePrint

# Simple debug Lootbox outcome

@export var to_print : String

func execute(_context: Dictionary = {}) -> bool:
	print("LootboxOutcomePrint: " + to_print)
	return true
