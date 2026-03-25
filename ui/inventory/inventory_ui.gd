extends Control
class_name InventoryUi

# TODO: remove this and put in scene manager | Ian: I like this, but should be a part of a larger refactor I think, for now we leave it and just keep our stuff coupled tightly
@export var player_ref : Player

# Used in case of an invalid item ID so the slot isn't empty
@export var placeholder_item_texture : Texture2D

# Lol, I am hardcoding this. Whoops.
@export var slot_0 : InventorySlot
@export var slot_1 : InventorySlot
@export var slot_2 : InventorySlot
@export var slot_3 : InventorySlot
@export var slot_4 : InventorySlot
@export var gold_count_label: Label

var slots : Array[InventorySlot]

func _ready() -> void:
	_connect_slot_signals(slot_0)
	_connect_slot_signals(slot_1)
	_connect_slot_signals(slot_2)
	_connect_slot_signals(slot_3)
	_connect_slot_signals(slot_4)
	
	player_ref.player_inventory.selected_index_changed.connect(_on_selected_index_changed)
	player_ref.player_inventory.slot_contents_changed.connect(_on_slot_contents_changed)
	player_ref.player_inventory.gold_count_changed.connect(_on_gold_count_changed)
	
	# TODO Shouldn't need to do this, but UI is readying after the player for some reason | Ian: LMAO the tree readys things bottom up if you look at the scene tree, so since ui is further down the list it gets init'd first (idk why, its just how it works)
	# Proper fix imo is initing what we can through code instead so we have total control of the order here, remove the black box or whatever
	slots[player_ref.player_inventory.selected_index].set_is_selected(true)
	for i in range(slots.size()):
		slots[i].set_info(player_ref.player_inventory.get_slot_item_id(i), player_ref.player_inventory.get_slot_item_id(i), null, player_ref.player_inventory.get_slot_count(i))
	_refresh_gold_count()

func _on_selected_index_changed(slot_index : int) -> void:
	assert(slot_index >= 0 && slot_index < 5, "inventory_ui._on_selected_index_changed(): Slot index was not valid")
	
	for index : int in range(slots.size()):
		slots[index].set_is_selected(index == slot_index)

func _on_slot_contents_changed(slot_index : int, item_id : StringName, count : int) -> void:
	assert(slot_index >= 0 && slot_index < 5, "inventory_ui._on_selected_index_changed(): Slot index was not valid")
	
	if count == 0:
		slots[slot_index].set_info(&"",&"", null, 0)
		return

	if not ItemGlobals.items.has(item_id):
		slots[slot_index].set_info(item_id,"id: "+item_id, placeholder_item_texture, count)
		return
	
	var item_data : ItemData = ItemGlobals.items[item_id]
	slots[slot_index].set_info(item_id, item_data.name, item_data.texture, count)

func _on_gold_count_changed(_current: int, _previous: int) -> void:
	_refresh_gold_count()

func _refresh_gold_count() -> void:
	if gold_count_label == null:
		return

	gold_count_label.text = str(maxi(player_ref.player_inventory.get_gold_count(), 0))

func _connect_slot_signals(slot : InventorySlot):
	var indice = slots.size()
	slots.append(slot)
	# slot.slot_left_mouse_down.connect(player_ref._try_perform_item_action.bind(true))
	slot.slot_left_mouse_down.connect(player_ref.player_inventory.set_selected_index.bind(indice))
	slot.slot_left_mouse_down.connect(player_ref._try_perform_item_action.bind(true))
	slot.slot_right_mouse_down.connect(player_ref.player_inventory.set_selected_index.bind(indice))
	slot.slot_right_mouse_down.connect(player_ref._try_perform_item_action.bind(false))
	
	slot.slot_mouse_up.connect(player_ref._stop_tossing)
