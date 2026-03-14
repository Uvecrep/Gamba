extends Control
class_name InventoryUi

# TODO: remove this and put in scene manager
@export var player_ref : Player

# Lol, I am hardcoding this. Whoops.
@export var slot_0 : InventorySlot
@export var slot_1 : InventorySlot
@export var slot_2 : InventorySlot
@export var slot_3 : InventorySlot
@export var slot_4 : InventorySlot

var slots : Array[InventorySlot]

func _ready() -> void:
	slots.append(slot_0)
	slots.append(slot_1)
	slots.append(slot_2)
	slots.append(slot_3)
	slots.append(slot_4)
	
	player_ref.player_inventory.selection_index_changed.connect(_on_selected_index_changed)
	player_ref.player_inventory.slot_contents_changed.connect(_on_slot_contents_changed)

func _on_selected_index_changed(slot_index : int) -> void:
	assert(slot_index >= 0 && slot_index < 5, "inventory_ui._on_selected_index_changed(): Slot index was not valid")
	
	for index : int in range(slots.size()):
		slots[index].set_is_selected(index == slot_index)

func _on_slot_contents_changed(slot_index : int, item_id : StringName, count : int) -> void:
	assert(slot_index >= 0 && slot_index < 5, "inventory_ui._on_selected_index_changed(): Slot index was not valid")
	
	slots[slot_index].set_info(item_id, null, count)
	pass
