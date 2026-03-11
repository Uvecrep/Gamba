extends Control

@export var inventory_item_scene : PackedScene

@export var player_ref : Player

@export var item_container : VBoxContainer

func _ready() -> void:
	assert(player_ref != null, "Error: UI will not work without player ref")
	
	player_ref.player_inventory.inventory_changed.connect(_refresh_ui)
	
	
	_refresh_ui()

func _refresh_ui() -> void:
	for item in item_container.get_children():
		item.queue_free()
	
	for index in range(player_ref.player_inventory.num_slots):
		var newitem: DebugInventoryItem = inventory_item_scene.instantiate()
		item_container.add_child(newitem)
		
		var item_id = player_ref.player_inventory.get_slot_item_id(index)
		var item_count = player_ref.player_inventory.get_slot_count(index)
		
		if player_ref.player_inventory.selected_index == index:
			newitem.TextContext.add_theme_color_override("font_color", Color.YELLOW)
		
		if item_id == &"":
			newitem.TextContext.text = str(index) + ": Empty"
		else:
			newitem.TextContext.text = str(index) + ": " + str(item_count)+"x " + item_id
