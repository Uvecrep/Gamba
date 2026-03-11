extends Node
# Autoload class for accessing lootboxes

var lootbox_paths: Array[String] = [
	"res://entities/lootbox/chaos_lootbox.tres",
	"res://entities/lootbox/forest_lootbox.tres",
]

var lootboxes: Dictionary[StringName, Lootbox] = {}


func _ready() -> void:
	reload_lootboxes()

func reload_lootboxes():
	for path in lootbox_paths:
		var resource: Lootbox = load(path)
		if resource:
			lootboxes[resource.id] = resource
		else:
			push_error("Failed to load lootbox: %s" % path)
	print("Loaded all lootboxes.")
