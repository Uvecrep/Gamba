extends CanvasLayer

## HUD overlay shown when the house is taking damage.
## Displays a house health bar and nearby enemy count at the top of the screen.
## Also flashes a red vignette at screen edges on each hit.

@export var enemy_near_house_radius: float = 220.0
@export var panel_hide_delay: float = 3.5
@export var enemy_count_update_interval: float = 0.5
@export var house_shake_intensity: float = 3.5
@export var house_shake_duration: float = 0.18

var _house: House = null
var _health_bar: ProgressBar = null
var _enemy_label: Label = null
var _panel: PanelContainer = null
var _vignette_material: ShaderMaterial = null

var _hide_timer: float = 0.0
var _panel_shown: bool = false
var _enemy_count_timer: float = 0.0
var _vignette_intensity: float = 0.0


func _ready() -> void:
	_build_vignette()
	_build_panel()
	_find_and_connect_house()


func _build_vignette() -> void:
	var vignette_rect := ColorRect.new()
	vignette_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette_rect.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vignette_rect.grow_vertical = Control.GROW_DIRECTION_BOTH
	vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette_rect.z_index = 10

	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	float vx = UV.x * (1.0 - UV.x);
	float vy = UV.y * (1.0 - UV.y);
	float edge = pow(clamp(vx * vy * 16.0, 0.0, 1.0), 0.4);
	float vignette = 1.0 - edge;
	COLOR = vec4(0.85, 0.06, 0.06, intensity * vignette * 0.75);
}
"""
	_vignette_material = ShaderMaterial.new()
	_vignette_material.shader = shader
	_vignette_material.set_shader_parameter("intensity", 0.0)
	vignette_rect.material = _vignette_material
	add_child(vignette_rect)


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.set_anchor(SIDE_LEFT, 0.5)
	_panel.set_anchor(SIDE_RIGHT, 0.5)
	_panel.set_anchor(SIDE_TOP, 0.0)
	_panel.set_anchor(SIDE_BOTTOM, 0.0)
	_panel.offset_left = -140.0
	_panel.offset_top = 10.0
	_panel.offset_right = 140.0
	_panel.offset_bottom = 74.0
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 6)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	var title_label := Label.new()
	title_label.text = "House"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(title_label)

	_health_bar = ProgressBar.new()
	_health_bar.min_value = 0.0
	_health_bar.max_value = 1.0
	_health_bar.value = 1.0
	_health_bar.custom_minimum_size = Vector2(0.0, 14.0)
	vbox.add_child(_health_bar)

	_enemy_label = Label.new()
	_enemy_label.text = "Enemies nearby: 0"
	_enemy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enemy_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_enemy_label)


func _find_and_connect_house() -> void:
	var houses := get_tree().get_nodes_in_group("house")
	if houses.is_empty():
		return
	_house = houses[0] as House
	if _house == null:
		return
	_house.damaged.connect(_on_house_damaged)
	_update_health_bar_display()


func _process(delta: float) -> void:
	# Fade vignette back to zero
	if _vignette_intensity > 0.0:
		_vignette_intensity = maxf(_vignette_intensity - delta * 2.8, 0.0)
		_vignette_material.set_shader_parameter("intensity", _vignette_intensity)

	if not _panel_shown:
		return

	# Panel auto-hide countdown
	_hide_timer = maxf(_hide_timer - delta, 0.0)
	if _hide_timer <= 0.0:
		_panel_shown = false
		_panel.visible = false
		return

	# Periodic enemy count refresh
	_enemy_count_timer = maxf(_enemy_count_timer - delta, 0.0)
	if _enemy_count_timer <= 0.0:
		_enemy_count_timer = enemy_count_update_interval
		_update_enemy_count()


func _on_house_damaged(current_hp: float, max_hp: float) -> void:
	_update_health_bar_display(current_hp, max_hp)
	_flash_vignette()
	_show_panel()
	_trigger_player_shake()


func _show_panel() -> void:
	_panel_shown = true
	_hide_timer = panel_hide_delay
	_panel.visible = true
	_update_enemy_count()


func _flash_vignette() -> void:
	_vignette_intensity = 1.0
	_vignette_material.set_shader_parameter("intensity", 1.0)


func _trigger_player_shake() -> void:
	var players := get_tree().get_nodes_in_group("players")
	if players.is_empty():
		return
	var player := players[0] as Player
	if player == null:
		return
	player.trigger_screen_shake(house_shake_intensity, house_shake_duration)


func _update_health_bar_display(current_hp: float = -1.0, max_hp: float = -1.0) -> void:
	if _health_bar == null:
		return
	if current_hp < 0.0 and _house != null and is_instance_valid(_house):
		current_hp = _house._current_health
		max_hp = _house.max_health
	if max_hp > 0.0:
		_health_bar.max_value = max_hp
		_health_bar.value = current_hp


func _update_enemy_count() -> void:
	if _enemy_label == null:
		return
	_enemy_label.text = "Enemies nearby: %d" % _count_enemies_near_house()


func _count_enemies_near_house() -> int:
	if _house == null or not is_instance_valid(_house):
		return 0
	var radius_sq := enemy_near_house_radius * enemy_near_house_radius
	var count := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is Node2D:
			var enemy_node := node as Node2D
			if enemy_node.global_position.distance_squared_to(_house.global_position) <= radius_sq:
				count += 1
	return count
