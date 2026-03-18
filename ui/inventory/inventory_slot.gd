extends Control

class_name InventorySlot

signal slot_left_mouse_down()
signal slot_right_mouse_down()
signal slot_mouse_up()

@export var item_image_texture_rect : TextureRect
@export var item_name_label : Label
@export var item_count_label : Label
@export var click_detection_box : Control
@export var item_portrait_border : Panel

var is_selected : bool = false

func set_is_selected(new_is_selected : bool) -> void:
	is_selected = new_is_selected
	if is_selected:
		var style: StyleBox = item_portrait_border.get_theme_stylebox("panel").duplicate()
		if style is StyleBoxFlat:
			var flat_style := style as StyleBoxFlat
			flat_style.border_color = Color.YELLOW
			flat_style.set_border_width_all(3)
		else:
			# Fallback in case a non-flat stylebox is used by the theme.
			var outline_style := StyleBoxFlat.new()
			outline_style.bg_color = Color.TRANSPARENT
			outline_style.border_color = Color.YELLOW
			outline_style.set_border_width_all(3)
			style = outline_style
		item_portrait_border.add_theme_stylebox_override("panel", style)
	else:
		item_portrait_border.remove_theme_stylebox_override("panel")

# TODO: Image implementation
func set_info(item_name : String, _item_image : Texture2D, item_count : int) -> void:
	if (item_count == 0): item_name = ""
	item_count_label.visible = item_count != 0
	item_name_label.text = item_name
	item_image_texture_rect.texture = _item_image
	item_count_label.text = str(item_count)

func _on_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			slot_left_mouse_down.emit()
		if event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			slot_right_mouse_down.emit()
		if not event.pressed:
			slot_mouse_up.emit()
