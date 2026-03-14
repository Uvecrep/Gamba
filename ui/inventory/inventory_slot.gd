extends Control

class_name InventorySlot

@export var item_image_texture_rect : TextureRect
@export var item_name_label : Label
@export var item_count_label : Label

var is_empty : bool = false
var is_selected : bool = false

func set_is_selected(new_is_selected : bool) -> void:
	is_selected = new_is_selected
	if is_selected:
		item_name_label.add_theme_color_override("font_color", Color.YELLOW)
	else:
		item_name_label.remove_theme_color_override("font_color")

func set_info(item_name : String, item_image : Texture2D, item_count : int) -> void:
	if (item_count == 0): item_name = ""
	item_name_label.text = item_name
	#item_image_texture_rect.texture = item_image
	item_count_label.text = str(item_count)
