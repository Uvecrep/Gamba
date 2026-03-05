extends LootboxOutcome
class_name LootboxOutcomePrint

# Simple debug Lootbox outcome

@export var to_print : String

func execute() -> void:
	print("LootboxOutcomePrint: " + to_print)
