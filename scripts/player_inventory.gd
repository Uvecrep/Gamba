extends RefCounted
class_name LegacyLootboxInventory

signal lootboxes_changed(current: int, previous: int)

var selected_index : int = -1

var _lootboxes : Array[Lootbox] = []
var _lootbox_counts : Array[int] = []


func get_lootbox_in_slot(index : int) -> Lootbox:
	if index < 0 or index >= _lootboxes.size(): return null
	
	return _lootboxes[index]

func get_lootbox_count_in_slot(index : int) -> int:
	if index < 0 or index >= _lootboxes.size(): return -1
	
	return _lootbox_counts[index]

func get_lootbox_count(lootbox: Lootbox) -> int:
	if not _lootboxes.has(lootbox):
		return 0

	var lootbox_index := _lootboxes.find(lootbox)
	if lootbox_index < 0:
		return 0

	return _lootbox_counts[lootbox_index]

func set_lootbox_count(lootbox : Lootbox, value: int) -> void:
	var previous_total: int = _get_total_lootbox_count()
	var next_count: int = maxi(value, 0)
	
	if not _lootboxes.has(lootbox):
		# TODO: Maybe lootboxes with the same ID should be grouped together
		# Reason being you might have two lootboxes with the same ID, but different mods?
		# Ian: Not sure where we landed with this, I made upgrades apply to a whole box type rather than individual boxes
		# Maybe need to revisit this idea for mods if we have time
		_lootboxes.append(lootbox)
		_lootbox_counts.append(0)
	
	var lootbox_index = _lootboxes.find(lootbox)
	if next_count == _lootbox_counts[lootbox_index]:
		return

	_lootbox_counts[lootbox_index] = next_count
	
	# if we're going to zero, we should remove instead
	if next_count == 0:
		_lootboxes.remove_at(lootbox_index)
		_lootbox_counts.remove_at(lootbox_index)
		if lootbox_index >= selected_index: 
			selected_index = selected_index - 1
	
	# If we only have one element left, we should select it
	if _lootboxes.size() == 1:
		selected_index = 0

	var current_total: int = _get_total_lootbox_count()
	lootboxes_changed.emit(current_total, previous_total)

func _get_total_lootbox_count() -> int:
	var total: int = 0
	for count in _lootbox_counts:
		total += count

	return total

func add_lootboxes(lootbox: Lootbox, amount: int) -> int:
	if amount <= 0: return 0

	if not _lootboxes.has(lootbox):
		_lootboxes.append(lootbox)
		_lootbox_counts.append(0)

	var lootbox_index = _lootboxes.find(lootbox)

	set_lootbox_count(lootbox, _lootbox_counts[lootbox_index] + amount)
	return amount

func try_spend_lootboxes(lootbox : Lootbox, amount: int) -> bool:
	if amount <= 0:
		return true
	if not _lootboxes.has(lootbox):
		return false
	var lootbox_index = _lootboxes.find(lootbox)
	var lootbox_count = _lootbox_counts[lootbox_index]
	# TODO If we don't have enough lootboxes, should we still spend as many as we can? | Ian: We should not spend if we cannot afford. Great success. (borat reference btw)
	if lootbox_count < amount:
		return false

	set_lootbox_count(lootbox, lootbox_count - amount)
	return true
