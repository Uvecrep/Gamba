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
	_connect_slot_signals(slot_0)
	_connect_slot_signals(slot_1)
	_connect_slot_signals(slot_2)
	_connect_slot_signals(slot_3)
	_connect_slot_signals(slot_4)
	
	player_ref.player_inventory.selected_index_changed.connect(_on_selected_index_changed)
	player_ref.player_inventory.slot_contents_changed.connect(_on_slot_contents_changed)
	
	# TODO Shouldn't need to do this, but UI is readying after the player for some reason
	slots[player_ref.player_inventory.selected_index].set_is_selected(true)
	for i in range(slots.size()):
		slots[i].set_info(player_ref.player_inventory.get_slot_item_id(i), null, player_ref.player_inventory.get_slot_count(i))

func _on_selected_index_changed(slot_index : int) -> void:
	assert(slot_index >= 0 && slot_index < 5, "inventory_ui._on_selected_index_changed(): Slot index was not valid")
	
	for index : int in range(slots.size()):
		slots[index].set_is_selected(index == slot_index)

func _on_slot_contents_changed(slot_index : int, item_id : StringName, count : int) -> void:
	assert(slot_index >= 0 && slot_index < 5, "inventory_ui._on_selected_index_changed(): Slot index was not valid")
	
	slots[slot_index].set_info(item_id, null, count)
	pass

func _connect_slot_signals(slot : InventorySlot):
	var indice = slots.size()
	slots.append(slot)
	# slot.slot_left_mouse_down.connect(player_ref._try_perform_item_action.bind(true))
	slot.slot_left_mouse_down.connect(player_ref.player_inventory.set_selected_index.bind(indice))
	slot.slot_right_mouse_down.connect(player_ref.player_inventory.set_selected_index.bind(indice))
	slot.slot_right_mouse_down.connect(player_ref._try_perform_item_action.bind(false))
	
	slot.slot_mouse_up.connect(player_ref._stop_tossing)
