extends Resource
class_name RewardData

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY,
}

enum QualityTier {
	BASE,
	PLUS,
	PLUS_PLUS,
}

@export var id: StringName
@export var display_name: String = ""
@export var icon: Texture2D
@export var rarity: Rarity = Rarity.COMMON
@export var base_rarity: Rarity = Rarity.COMMON
@export var quality_tier: QualityTier = QualityTier.BASE


func get_display_name_or_fallback() -> String:
	var base_name: String = ""
	if not display_name.is_empty():
		base_name = display_name
	elif id != StringName():
		base_name = humanize_identifier(id)
	else:
		base_name = "Mystery Reward"

	return "%s%s" % [base_name, quality_suffix(int(quality_tier))]


static func promoted_rarity(base_rarity_value: int, quality_tier_value: int) -> int:
	var tier_increase: int = 0
	match quality_tier_value:
		QualityTier.PLUS:
			tier_increase = 1
		QualityTier.PLUS_PLUS:
			tier_increase = 2
		_:
			tier_increase = 0

	return clampi(base_rarity_value + tier_increase, Rarity.COMMON, Rarity.LEGENDARY)


static func quality_suffix(quality_tier_value: int) -> String:
	match quality_tier_value:
		QualityTier.PLUS:
			return "+"
		QualityTier.PLUS_PLUS:
			return "++"
		_:
			return ""


static func rarity_color(rarity_value: int) -> Color:
	match rarity_value:
		Rarity.UNCOMMON:
			return Color("71d17d")
		Rarity.RARE:
			return Color("53b6ff")
		Rarity.EPIC:
			return Color("cc71ff")
		Rarity.LEGENDARY:
			return Color("ffb347")
		_:
			return Color("cfd3da")


static func rarity_backing_color(rarity_value: int) -> Color:
	match rarity_value:
		Rarity.UNCOMMON:
			return Color("182d1f")
		Rarity.RARE:
			return Color("122638")
		Rarity.EPIC:
			return Color("2a1c33")
		Rarity.LEGENDARY:
			return Color("36260f")
		_:
			return Color("1e1f25")


static func rarity_label(rarity_value: int) -> String:
	match rarity_value:
		Rarity.UNCOMMON:
			return "Uncommon"
		Rarity.RARE:
			return "Rare"
		Rarity.EPIC:
			return "Epic"
		Rarity.LEGENDARY:
			return "Legendary"
		_:
			return "Common"


static func humanize_identifier(identifier: StringName) -> String:
	var source: String = String(identifier).replace("-", " ").replace("_", " ").strip_edges()
	if source.is_empty():
		return "Reward"

	var words: PackedStringArray = source.split(" ", false)
	for i in range(words.size()):
		var word: String = words[i]
		if word.is_empty():
			continue
		words[i] = word.substr(0, 1).to_upper() + word.substr(1)

	return " ".join(words)
