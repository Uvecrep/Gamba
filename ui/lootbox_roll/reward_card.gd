extends Control
class_name LootboxRewardCard

const PLACEHOLDER_ICON: Texture2D = preload("res://icon.svg")
const RewardDataScript = preload("res://entities/lootbox/reward_data.gd")

@onready var _panel: Panel = $Panel
@onready var _icon_rect: TextureRect = $Panel/MarginContainer/VBoxContainer/Icon
@onready var _name_label: Label = $Panel/MarginContainer/VBoxContainer/NameLabel
@onready var _rarity_label: Label = $Panel/MarginContainer/VBoxContainer/RarityLabel
@onready var _flash_rect: ColorRect = $Flash

var _reward_data: Resource
var _base_scale: Vector2 = Vector2.ONE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.visible = false


func set_reward_data(data: Resource) -> void:
	_reward_data = data
	if _reward_data == null:
		return

	var reward_name: String = "Mystery Reward"
	if _reward_data.has_method("get_display_name_or_fallback"):
		reward_name = String(_reward_data.call("get_display_name_or_fallback"))
	else:
		reward_name = String(_reward_data.get("display_name"))

	var rarity_value: int = int(_reward_data.get("rarity"))
	var icon_texture: Texture2D = _reward_data.get("icon") as Texture2D

	_name_label.text = reward_name
	_rarity_label.text = RewardDataScript.rarity_label(rarity_value)
	_icon_rect.texture = icon_texture if icon_texture != null else PLACEHOLDER_ICON
	_apply_rarity_style(rarity_value)


func set_highlighted(value: bool) -> void:
	scale = Vector2(1.05, 1.05) if value else _base_scale
	modulate = Color(1.15, 1.15, 1.15, 1.0) if value else Color(1, 1, 1, 1)


func play_win_pop() -> void:
	set_highlighted(true)
	_flash_rect.visible = true
	_flash_rect.modulate = Color(1, 1, 1, 0.0)

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.18, 1.18), 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_flash_rect, "modulate:a", 0.62, 0.07)
	tween.chain().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.08, 1.08), 0.17).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_flash_rect, "modulate:a", 0.0, 0.2)
	tween.finished.connect(func() -> void:
		_flash_rect.visible = false
	)


func _apply_rarity_style(rarity_value: int) -> void:
	var border_color: Color = RewardDataScript.rarity_color(rarity_value)
	var backing_color: Color = RewardDataScript.rarity_backing_color(rarity_value)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = backing_color
	style.border_color = border_color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3

	_panel.add_theme_stylebox_override("panel", style)
	_name_label.modulate = border_color.lightened(0.25)
	_rarity_label.modulate = border_color
