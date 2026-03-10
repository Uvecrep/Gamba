extends LootboxMod
class_name LootboxStatsMod

@export var stat_modifier: float = 1
@export_enum("Health", "Damage") var change : String
@export var target : String

# Changes stats of spawn minion, theoretically if the name is that of a non spawn type of lootEntry
# We will run into an issue with roll.outcome.health. Also didn't add division or multiplication
# cause I was lazy, we can add that later
func modify(lootTable: Array[LootEntry]) -> bool:
	for roll in lootTable:
		if roll.name == target or modification_type == "All":
			if change == "Health":
				roll.outcome.max_health_multiplier = roll.outcome.max_health_multiplier + stat_modifier
				return true
			elif change == "Damage":
				roll.outcome.damage_multiplier = roll.outcome.damage_multiplier + stat_modifier
				return true
			else:
				assert(false, "LootboxMod.modify() failed: not valid stat modifier change")
				return false
	assert(false, "LootboxMod.modify() failed: Did not find targeted lootEntry")
	return false
