extends Resource
class_name LootEntry

const RewardDataScript = preload("res://entities/lootbox/reward_data.gd")

const QUALITY_PLUS_CHANCE_BY_BASE_RARITY: Dictionary = {
	RewardDataScript.Rarity.COMMON: 0.10,
	RewardDataScript.Rarity.UNCOMMON: 0.12,
	RewardDataScript.Rarity.RARE: 0.14,
	RewardDataScript.Rarity.EPIC: 0.16,
	RewardDataScript.Rarity.LEGENDARY: 0.18,
}
const QUALITY_PLUS_PLUS_CHANCE_BY_BASE_RARITY: Dictionary = {
	RewardDataScript.Rarity.COMMON: 0.02,
	RewardDataScript.Rarity.UNCOMMON: 0.03,
	RewardDataScript.Rarity.RARE: 0.04,
	RewardDataScript.Rarity.EPIC: 0.05,
	RewardDataScript.Rarity.LEGENDARY: 0.06,
}
	
@export var outcome: LootboxOutcome
@export var weight: float = 1
@export var name: String
@export var reward_data: Resource
@export_range(-1, 4, 1) var rarity_override: int = -1


func get_reward_data() -> Resource:
	if reward_data != null:
		var configured_data: RewardData = reward_data as RewardData
		if configured_data != null:
			configured_data.base_rarity = configured_data.rarity
			configured_data.quality_tier = RewardDataScript.QualityTier.BASE
		return reward_data

	return _build_reward_data(false)


func get_reward_data_with_quality_roll() -> Resource:
	if reward_data != null:
		var configured_data: RewardData = reward_data.duplicate(true) as RewardData
		if configured_data == null:
			return reward_data
		configured_data.base_rarity = int(configured_data.rarity) as RewardDataScript.Rarity
		configured_data.quality_tier = _roll_quality_tier(configured_data.base_rarity)
		configured_data.rarity = RewardDataScript.promoted_rarity(int(configured_data.base_rarity), int(configured_data.quality_tier)) as RewardDataScript.Rarity
		return configured_data

	return _build_reward_data(true)


func _build_reward_data(with_quality_roll: bool) -> RewardData:
	if reward_data != null:
		return reward_data as RewardData

	var generated: RewardData = RewardDataScript.new()
	var base_rarity_value: RewardDataScript.Rarity = _resolve_rarity_from_weight(weight) as RewardDataScript.Rarity
	var quality_tier_value: RewardDataScript.QualityTier = RewardDataScript.QualityTier.BASE
	if with_quality_roll:
		quality_tier_value = _roll_quality_tier(base_rarity_value)

	generated.id = _resolve_reward_id()
	generated.display_name = _resolve_display_name(generated.id)
	generated.icon = _resolve_icon()
	generated.base_rarity = base_rarity_value
	generated.quality_tier = quality_tier_value
	generated.rarity = RewardDataScript.promoted_rarity(int(base_rarity_value), int(quality_tier_value)) as RewardDataScript.Rarity
	return generated


func _roll_quality_tier(base_rarity_value: RewardDataScript.Rarity) -> RewardDataScript.QualityTier:
	var plus_chance: float = QUALITY_PLUS_CHANCE_BY_BASE_RARITY.get(base_rarity_value, 0.10)
	var plus_plus_chance: float = QUALITY_PLUS_PLUS_CHANCE_BY_BASE_RARITY.get(base_rarity_value, 0.02)
	var roll: float = randf()

	if roll < plus_plus_chance:
		return RewardDataScript.QualityTier.PLUS_PLUS as RewardDataScript.QualityTier
	if roll < plus_plus_chance + plus_chance:
		return RewardDataScript.QualityTier.PLUS as RewardDataScript.QualityTier
	return RewardDataScript.QualityTier.BASE as RewardDataScript.QualityTier


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
