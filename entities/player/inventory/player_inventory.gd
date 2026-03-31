extends RefCounted
class_name PlayerInventory

signal inventory_changed()
signal inventory_became_full()
signal selected_index_changed(new_index : int)
signal slot_contents_changed(index : int, item_id : StringName, count : int)
signal gold_count_changed(current: int, previous: int)
@warning_ignore("unused_signal")
signal blood_count_changed(current: int, previous: int)

const GOLD_ITEM_IDS: Array[StringName] = [&"gold_coin", &"gold"]

var selected_index : int = 2
var num_slots : int = 5 # TODO implement changing number of slots? Static rn | Ian: Static seems fine, honestly 5 is a really comfortable number with how many items we have, if we started adjusting more we'd probably need to add chests and stuff too
var gold_count: int
var blood_count: int

var inventory_items : Array[StringName] = []
var inventory_item_counts : Array[int] = [] # A slot where count is zero is treated as empty


func _init() -> void:
	for index in range(num_slots):
		inventory_items.append(&"")
		inventory_item_counts.append(0)

func _ready() -> void:
	selected_index_changed.emit(selected_index)

func set_selected_index(new_index : int) -> void:
	selected_index = new_index
	selected_index_changed.emit(new_index)

func get_slot_item_id(index : int) -> StringName:
	if index < 0 or index >= num_slots: return &""
	if inventory_item_counts[index] == 0: return &""
	
	return inventory_items[index]

func get_slot_count(index : int) -> int:
	if index < 0 or index >= num_slots: return -1
	
	return inventory_item_counts[index]

func set_slot_item_count(index : int, new_value: int) -> bool:
	if index < 0 or index >= num_slots: return false
	if new_value < 0: return false
	
	inventory_item_counts[index] = new_value
	
	if new_value == 0:
		inventory_items[index] = &""
	inventory_changed.emit()
	slot_contents_changed.emit(index, inventory_items[index], new_value)
	return true

func get_gold_count() -> int:
	return gold_count

func add_gold(amount: int) -> int:
	if amount <= 0:
		return 0

	var previous_gold: int = gold_count
	gold_count += amount
	gold_count_changed.emit(gold_count, previous_gold)
	inventory_changed.emit()
	return amount

func spend_gold(amount: int) -> bool:
	if amount <= 0:
		return true
	if gold_count < amount:
		return false

	var previous_gold: int = gold_count
	gold_count -= amount
	gold_count_changed.emit(gold_count, previous_gold)
	inventory_changed.emit()
	return true

func has_gold(amount: int) -> bool:
	if amount <= 0:
		return true
	return gold_count >= amount

func add_items(item_id: StringName, num_items: int) -> bool:
	if item_id == &"": return false;
	if num_items <= 0: return false
	if is_gold_item(item_id):
		add_gold(num_items)
		return true
	
	var target_slot_index = -1
	var filled_new_slot = false
	
	if inventory_items.has(item_id):
		target_slot_index = inventory_items.find(item_id)
	else:
		var empty_slots = _get_empty_slots()
		if empty_slots.size() == 0: 
			return false
		
		# Try to put item in selected slot, otherwise in leftmost slot
		if empty_slots.find(selected_index) != -1: 
			target_slot_index = selected_index
		else:
			target_slot_index = empty_slots[0] # TODO: Should maybe have a smarter way of determining this | Ian: Maybe, but this seems fine for now. 
		inventory_items[target_slot_index] = item_id
		filled_new_slot = true
	
	var new_count = inventory_item_counts[target_slot_index] + num_items
	inventory_item_counts[target_slot_index] = new_count
	inventory_changed.emit()
	slot_contents_changed.emit(target_slot_index, item_id, new_count)
	if filled_new_slot and _get_empty_slots().size() == 0: 
		inventory_became_full.emit()
	return true

# If allow_insufficient_funds is false, function will not do anything if you have fewer items than the number you want removed
func remove_items(index : int, num_to_remove : int, allow_insufficient_funds : bool = false) -> bool:
	if index < 0 or index >= num_slots: return false
	
	if num_to_remove > inventory_item_counts[index] and not allow_insufficient_funds:
		return false
	
	set_slot_item_count(index, inventory_item_counts[index] - num_to_remove)
	return true

func would_item_fit(item_id: StringName) -> bool:
	if is_gold_item(item_id): return true
	if _get_empty_slots().size() > 0: return true
	if inventory_items.has(item_id): return true
	return false

func is_gold_item(item_id: StringName) -> bool:
	return GOLD_ITEM_IDS.has(item_id)

func _get_empty_slots() -> Array[int]:
	var empty_slots : Array[int] = []
	for i in range(inventory_item_counts.size()):
			if inventory_item_counts[i] == 0:
				empty_slots.append(i)
	return empty_slots
