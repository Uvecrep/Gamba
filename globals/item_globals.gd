extends Node
# Autoload singleton class for item resource management


var item_paths: Array[String] = [
	"res://resources/items/item_lootbox_chaos.tres",
	"res://resources/items/item_sapling.tres",
	"res://resources/items/item_gold_coin.tres",
]

var items: Dictionary[StringName, ItemData] = {}


func _ready() -> void:
	reload_items()

func reload_items():
	for path in item_paths:
		var resource: ItemData = load(path)
		if resource:
			items[resource.id] = resource
		else:
			push_error("Failed to load item: %s" % path)
	print("Loaded all items.")
