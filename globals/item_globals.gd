extends Node
# Autoload singleton class for item resource management

const ITEM_RESOURCE_DIR := "res://resources/items"

var items: Dictionary[StringName, ItemData] = {}

var item_paths: Array[String]

var item0 = preload("res://resources/items/item_gold_coin.tres")
var item1 = preload("res://resources/items/item_lootbox_chaos.tres")
var item2 = preload("res://resources/items/item_lootbox_elemental.tres")
var item3 = preload("res://resources/items/item_lootbox_forest.tres")
var item4 = preload("res://resources/items/item_lootbox_greed.tres")
var item5 = preload("res://resources/items/item_lootbox_soul.tres")
var item6 = preload("res://resources/items/item_sapling.tres")



func _ready() -> void:
	reload_items()

func reload_items():
	items.clear()

	items[item0.id] = item0
	items[item1.id] = item1
	items[item2.id] = item2
	items[item3.id] = item3
	items[item4.id] = item4
	items[item5.id] = item5
	items[item6.id] = item6


	# var dir := DirAccess.open(ITEM_RESOURCE_DIR)
	# if dir == null:
	# 	push_error("Failed to open items directory: %s" % ITEM_RESOURCE_DIR)
	# 	return

	# dir.list_dir_begin()
	# var file_name := dir.get_next()

	# while file_name != "":
	# 	if not dir.current_is_dir():
	# 		if file_name.ends_with(".tres") or file_name.ends_with(".res"):
	# 			var path := ITEM_RESOURCE_DIR.path_join(file_name)
	# 			var resource: ItemData = load(path)

	# 			if resource:
	# 				items[resource.id] = resource
	# 			else:
	# 				push_error("Failed to load item: %s" % path)

	# 	file_name = dir.get_next()

	# dir.list_dir_end()

	print("Loaded %d items." % items.size())
