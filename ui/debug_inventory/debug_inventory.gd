extends Control

@export var inventory_item_scene : PackedScene

@export var player_ref : Player

@export var item_container : VBoxContainer

func _ready() -> void:
	assert(player_ref != null, "Error: UI will not work without player ref")
	
	player_ref.inventory.inventory_changed.connect(_refresh_ui)
	
	
	_refresh_ui()

func _refresh_ui() -> void:
	for item in item_container.get_children():
		item.queue_free()
	
	for index in range(player_ref.inventory._lootboxes.size()):
		var newitem: DebugInventoryItem = inventory_item_scene.instantiate()
		item_container.add_child(newitem)
		
		var dataItem = player_ref.inventory.get_lootbox_in_slot(index)
		if dataItem == null:
			continue
		
		newitem.TextContext.text = str(index) + ": " + dataItem.name
