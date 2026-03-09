extends RefCounted
class_name PlayerInventory

signal lootboxes_changed(current: int, previous: int)

var _lootbox_count: int = 0

func get_lootbox_count() -> int:
	return _lootbox_count

func set_lootbox_count(value: int) -> void:
	var next_count: int = maxi(value, 0)
	if next_count == _lootbox_count:
		return

	var previous_count: int = _lootbox_count
	_lootbox_count = next_count
	lootboxes_changed.emit(_lootbox_count, previous_count)

func add_lootboxes(amount: int) -> int:
	if amount <= 0:
		return 0

	set_lootbox_count(_lootbox_count + amount)
	return amount

func try_spend_lootboxes(amount: int) -> bool:
	if amount <= 0:
		return true
	if _lootbox_count < amount:
		return false

	set_lootbox_count(_lootbox_count - amount)
	return true
