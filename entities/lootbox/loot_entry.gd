extends Resource
class_name LootEntry

const RewardDataScript = preload("res://entities/lootbox/reward_data.gd")
	
@export var outcome: LootboxOutcome
@export var weight: float = 1
@export var name: String
@export var reward_data: Resource
@export_range(-1, 4, 1) var rarity_override: int = -1


func get_reward_data() -> Resource:
	if reward_data != null:
		return reward_data

	var generated = RewardDataScript.new()
	generated.id = _resolve_reward_id()
	generated.display_name = _resolve_display_name(generated.id)
	generated.icon = _resolve_icon()
	generated.rarity = _resolve_rarity_from_weight(weight)
	return generated


func _resolve_reward_id() -> StringName:
	if not name.is_empty():
		return StringName(name.to_snake_case())

	if outcome is LootboxOutcomeSpawnSummon:
		var summon_outcome: LootboxOutcomeSpawnSummon = outcome as LootboxOutcomeSpawnSummon
		if summon_outcome.summon_identity != StringName():
			return summon_outcome.summon_identity

	return &"mystery_reward"


func _resolve_display_name(fallback_id: StringName) -> String:
	if not name.is_empty():
		return name

	if outcome is LootboxOutcomeSpawnSummon:
		var summon_outcome: LootboxOutcomeSpawnSummon = outcome as LootboxOutcomeSpawnSummon
		if summon_outcome.summon_identity != StringName():
			return RewardDataScript.humanize_identifier(summon_outcome.summon_identity)

	return RewardDataScript.humanize_identifier(fallback_id)


func _resolve_icon() -> Texture2D:
	if outcome is LootboxOutcomeSpawnSummon:
		var summon_outcome: LootboxOutcomeSpawnSummon = outcome as LootboxOutcomeSpawnSummon
		return summon_outcome.summon_texture_override

	return null


func _resolve_rarity_from_weight(entry_weight: float) -> int:
	if rarity_override >= 0:
		return clampi(rarity_override, RewardDataScript.Rarity.COMMON, RewardDataScript.Rarity.LEGENDARY)

	if entry_weight <= 0.2:
		return RewardDataScript.Rarity.LEGENDARY
	if entry_weight <= 0.45:
		return RewardDataScript.Rarity.EPIC
	if entry_weight <= 0.75:
		return RewardDataScript.Rarity.RARE
	if entry_weight < 1.0:
		return RewardDataScript.Rarity.UNCOMMON
	return RewardDataScript.Rarity.COMMON
