extends HBoxContainer
class_name LootEntryUiItem

@export var index_label : Label
@export var name_label : Label
@export var weight_label : Label

func set_info(new_index : int, new_name : String, new_weight : String) -> void:
	index_label.text = str(new_index).pad_zeros(2)
	name_label.text = new_name
	weight_label.text = new_weight

