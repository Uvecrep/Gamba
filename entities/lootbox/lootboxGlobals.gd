extends Node
# Autoload class for accessing lootboxes

var lootbox_paths: Dictionary = {
	&"main" : "res://entities/lootbox/main_starting_lootbox.tres",
	&"example" : "res://entities/lootbox/lootbox_testing/example_lootbox.tres"
}
var lootboxes: Dictionary[StringName, Lootbox] = {}


func _ready() -> void:
	reload_lootboxes()

func reload_lootboxes():
	for id in lootbox_paths:
		var path = lootbox_paths[id]
		var resource = load(path)
		if resource:
			lootboxes[id] = resource
		else:
			push_error("Failed to load lootbox: %s" % path)
	print("Loaded all lootboxes.")
