extends Node
# Autoload singleton class for item resource management

const ITEM_RESOURCE_DIR := "res://resources/items"

var items: Dictionary[StringName, ItemData] = {}


func _ready() -> void:
	reload_items()

func reload_items():
	items.clear()

	var dir := DirAccess.open(ITEM_RESOURCE_DIR)
	if dir == null:
		push_error("Failed to open items directory: %s" % ITEM_RESOURCE_DIR)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if not dir.current_is_dir():
			if file_name.ends_with(".tres") or file_name.ends_with(".res"):
				var path := ITEM_RESOURCE_DIR.path_join(file_name)
				var resource: ItemData = load(path)

				if resource:
					items[resource.id] = resource
				else:
					push_error("Failed to load item: %s" % path)

		file_name = dir.get_next()

	dir.list_dir_end()

	print("Loaded %d items." % items.size())
