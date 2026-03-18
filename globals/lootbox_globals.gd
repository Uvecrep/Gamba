extends Node
# Autoload class for lootbox resource management

const LOOTBOX_RESOURCE_DIR := "res://resources/lootboxes"

var lootboxes: Dictionary[StringName, Lootbox] = {}


func _ready() -> void:
	reload_lootboxes()

func reload_lootboxes():
	lootboxes.clear()

	var dir := DirAccess.open(LOOTBOX_RESOURCE_DIR)
	if dir == null:
		push_error("Failed to open lootboxes directory: %s" % LOOTBOX_RESOURCE_DIR)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if not dir.current_is_dir():
			if file_name.ends_with(".tres") or file_name.ends_with(".res"):
				var path := LOOTBOX_RESOURCE_DIR.path_join(file_name)
				var resource: Lootbox = load(path)

				if resource:
					lootboxes[resource.id] = resource
				else:
					push_error("Failed to load lootbox: %s" % path)

		file_name = dir.get_next()

	dir.list_dir_end()

	print("Loaded %d lootboxes." % lootboxes.size())
