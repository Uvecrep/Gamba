extends Resource
class_name RewardData

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY,
}

@export var id: StringName
@export var display_name: String = ""
@export var icon: Texture2D
@export var rarity: Rarity = Rarity.COMMON


func get_display_name_or_fallback() -> String:
	if not display_name.is_empty():
		return display_name
	if id != StringName():
		return humanize_identifier(id)
	return "Mystery Reward"


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
