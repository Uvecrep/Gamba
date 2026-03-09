extends Resource
class_name LootboxOutcome

# Base class for outcomes of a Lootbox roll

func execute(_context: Dictionary = {}) -> bool:
	push_warning("LootboxOutcome.execute() called on base class; no outcome was applied.")
	return false
