extends Control
class_name BestiaryPanel

@export var toggle_action: StringName = &"open_bestiary"

const ENTRIES_PER_PAGE: int = 5
const PROMPT_SHOW_DURATION: float = 3.0
const PROMPT_FADE_DURATION: float = 0.45
const BADGE_BOUNCE_AMPLITUDE: float = 1.5
const BADGE_BOUNCE_SPEED: float = 0.004

@onready var _backdrop: ColorRect = $Backdrop
@onready var _panel_root: PanelContainer = $PanelRoot
@onready var _tab_bar: TabBar = $PanelRoot/MarginContainer/RootVBox/TabBar
@onready var _prev_page_button: Button = $PanelRoot/MarginContainer/RootVBox/PageRow/PrevPageButton
@onready var _page_label: Label = $PanelRoot/MarginContainer/RootVBox/PageRow/PageLabel
@onready var _next_page_button: Button = $PanelRoot/MarginContainer/RootVBox/PageRow/NextPageButton
@onready var _card_grid: GridContainer = $PanelRoot/MarginContainer/RootVBox/CardGrid
@onready var _hint_label: Label = $PanelRoot/MarginContainer/RootVBox/HeaderRow/HintLabel
@onready var _prompt_panel: PanelContainer = $PromptPanel
@onready var _prompt_label: Label = $PromptPanel/MarginContainer/PromptVBox/PromptLabel

var _tab_ids: Array[StringName] = []
var _tab_display_name_by_id: Dictionary = {}
var _selected_tab_id: StringName = StringName()
var _selected_entry_id: StringName = StringName()
var _entry_page_index: int = 0
var _entry_ids_for_selected_tab: Array[StringName] = []

var _entry_button_by_id: Dictionary = {}
var _entry_panel_by_id: Dictionary = {}
var _entry_badge_by_id: Dictionary = {}

var _prompt_queue: Array[Dictionary] = []
var _tab_new_icon: Texture2D
var _entry_badge_background_icon: Texture2D
var _is_panel_open: bool = false
var _prompt_fade_tween: Tween


func _ready() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.visible = false
	_panel_root.visible = false
	_prompt_panel.visible = false
	_prompt_panel.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_hint_label.text = "B: Open/Close Bestiary"
	_prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_tab_bar.tab_changed.connect(_on_tab_changed)
	_prev_page_button.pressed.connect(_on_prev_page_pressed)
	_next_page_button.pressed.connect(_on_next_page_pressed)

	var bestiary = _bestiary()
	if bestiary != null:
		bestiary.catalog_rebuilt.connect(_refresh_tabs_and_entries)
		bestiary.bestiary_entry_unlocked.connect(_on_bestiary_entry_unlocked)
		if bestiary.has_signal("bestiary_entry_new_state_changed"):
			bestiary.bestiary_entry_new_state_changed.connect(_on_bestiary_entry_new_state_changed)

	_tab_new_icon = _create_tab_new_icon()
	_entry_badge_background_icon = _create_entry_badge_background_icon()
	_refresh_tabs_and_entries()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(toggle_action):
		set_panel_open(not _is_panel_open)
		get_viewport().set_input_as_handled()
		return

	if _is_panel_open and event.is_action_pressed(&"ui_cancel"):
		set_panel_open(false)
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	_update_badge_animation()


func set_panel_open(open: bool) -> void:
	_is_panel_open = open
	_backdrop.visible = open
	_panel_root.visible = open
	if open:
		_clear_prompt_notifications()
		_refresh_cards()


func open_to_entry(tab_id: StringName, entry_id: StringName) -> void:
	set_panel_open(true)
	_select_tab(tab_id)
	_select_entry(entry_id)


func _refresh_tabs_and_entries() -> void:
	_tab_bar.clear_tabs()
	_tab_ids.clear()
	_tab_display_name_by_id.clear()

	var bestiary = _bestiary()
	if bestiary == null:
		return

	var tabs: Array[Dictionary] = bestiary.get_tab_definitions()
	for tab in tabs:
		var tab_id: StringName = tab.get("id", StringName()) as StringName
		var tab_name: String = String(tab.get("display_name", "Unknown"))
		if tab_id == StringName():
			continue
		_tab_ids.append(tab_id)
		_tab_display_name_by_id[tab_id] = tab_name
		_tab_bar.add_tab(tab_name)

	if _tab_ids.is_empty():
		_clear_cards()
		return

	if _selected_tab_id == StringName() or _tab_ids.find(_selected_tab_id) == -1:
		_selected_tab_id = _tab_ids[0]

	var selected_index: int = _tab_ids.find(_selected_tab_id)
	if selected_index < 0:
		selected_index = 0
		_selected_tab_id = _tab_ids[0]

	_tab_bar.current_tab = selected_index
	_entry_page_index = 0
	_refresh_tab_indicators()
	_refresh_cards()


func _refresh_cards() -> void:
	_clear_cards()

	var bestiary = _bestiary()
	if bestiary == null:
		return
	if _selected_tab_id == StringName():
		return

	_entry_ids_for_selected_tab = bestiary.get_entry_ids_for_tab(_selected_tab_id)
	var total_pages: int = _get_total_pages()
	_entry_page_index = clampi(_entry_page_index, 0, maxi(total_pages - 1, 0))
	_refresh_page_controls()

	_add_intro_card()

	var start_index: int = _entry_page_index * ENTRIES_PER_PAGE
	for local_index in range(ENTRIES_PER_PAGE):
		var entry_index: int = start_index + local_index
		if entry_index >= _entry_ids_for_selected_tab.size():
			_add_empty_card()
			continue

		var entry_id: StringName = _entry_ids_for_selected_tab[entry_index]
		_add_entry_card(entry_id)

	if _selected_entry_id != StringName():
		_apply_selected_highlight(_selected_entry_id)


func _clear_cards() -> void:
	for child in _card_grid.get_children():
		child.queue_free()

	_entry_button_by_id.clear()
	_entry_panel_by_id.clear()
	_entry_badge_by_id.clear()


func _add_intro_card() -> void:
	var card: PanelContainer = _create_card_root()
	_card_grid.add_child(card)

	var content: VBoxContainer = _create_card_content(card)
	var title: Label = _create_card_title("About")
	content.add_child(title)

	var body: Label = Label.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.text = _build_tab_intro_text(_selected_tab_id)
	content.add_child(body)


func _add_empty_card() -> void:
	var card: PanelContainer = _create_card_root()
	card.modulate = Color(1.0, 1.0, 1.0, 0.6)
	_card_grid.add_child(card)

	var content: VBoxContainer = _create_card_content(card)
	var title: Label = _create_card_title("-")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)


func _add_entry_card(entry_id: StringName) -> void:
	var bestiary = _bestiary()
	if bestiary == null:
		return

	var card: PanelContainer = _create_card_root()
	_card_grid.add_child(card)

	var content: VBoxContainer = _create_card_content(card)
	var title: Label = _create_card_title("???")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	content.add_child(title)

	var top_row := HBoxContainer.new()
	top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_theme_constant_override("separation", 8)
	content.add_child(top_row)

	var portrait_frame: PanelContainer = PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(88.0, 88.0)
	portrait_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_row.add_child(portrait_frame)

	var portrait: TextureRect = TextureRect.new()
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.anchors_preset = Control.PRESET_FULL_RECT
	portrait.offset_left = 6.0
	portrait.offset_top = 6.0
	portrait.offset_right = -6.0
	portrait.offset_bottom = -6.0
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_frame.add_child(portrait)

	var locked_mark: Label = Label.new()
	locked_mark.text = "?"
	locked_mark.add_theme_font_size_override("font_size", 44)
	locked_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	locked_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	locked_mark.anchors_preset = Control.PRESET_FULL_RECT
	portrait_frame.add_child(locked_mark)

	var stats_label := Label.new()
	stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 13)
	stats_label.text = "Stats:\n???"
	top_row.add_child(stats_label)

	var subtitle: Label = Label.new()
	subtitle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.modulate = Color(0.86, 0.86, 0.86, 1.0)
	subtitle.text = "Open the matching lootbox to discover."
	content.add_child(subtitle)

	var button: Button = Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.anchors_preset = Control.PRESET_FULL_RECT
	button.offset_left = 0.0
	button.offset_top = 0.0
	button.offset_right = 0.0
	button.offset_bottom = 0.0
	button.pressed.connect(_on_entry_pressed.bind(entry_id))
	card.add_child(button)

	var badge := Control.new()
	badge.custom_minimum_size = Vector2(26.0, 26.0)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.anchor_left = 0.0
	badge.anchor_right = 0.0
	badge.anchor_top = 0.0
	badge.anchor_bottom = 0.0
	badge.offset_left = 0.0
	badge.offset_top = 0.0
	badge.offset_right = 26.0
	badge.offset_bottom = 26.0
	badge.visible = false
	badge.set_meta("base_y", -4.0)
	badge.set_meta("right_padding", 4.0)
	badge.set_meta("badge_width", 26.0)
	badge.set_meta("badge_height", 26.0)
	card.add_child(badge)

	var badge_background := TextureRect.new()
	badge_background.texture = _entry_badge_background_icon
	badge_background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	badge_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge_background.anchors_preset = Control.PRESET_FULL_RECT
	badge.add_child(badge_background)

	var badge_label := Label.new()
	badge_label.text = "!"
	badge_label.add_theme_font_size_override("font_size", 20)
	badge_label.modulate = Color(1.0, 0.84, 0.08, 1.0)
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_label.anchors_preset = Control.PRESET_FULL_RECT
	badge.add_child(badge_label)

	_entry_panel_by_id[entry_id] = card
	_entry_button_by_id[entry_id] = button
	_entry_badge_by_id[entry_id] = badge

	var unlocked: bool = bestiary.is_entry_unlocked(entry_id)
	if unlocked:
		var entry: Dictionary = bestiary.get_entry(entry_id)
		title.text = String(entry.get("display_name", "Unknown"))
		portrait.texture = entry.get("portrait", null) as Texture2D
		locked_mark.visible = false
		var stats_lines: PackedStringArray = entry.get("stats_lines", PackedStringArray(["Base stats unavailable"]))
		stats_label.text = "\n".join(stats_lines)
		subtitle.text = String(entry.get("blurb", ""))
	else:
		title.text = "???"
		portrait.texture = null
		locked_mark.visible = true
		stats_label.text = "Stats:\n???"
		subtitle.text = "Open the matching lootbox to discover."

	if bestiary.has_method("is_entry_new"):
		badge.visible = bool(bestiary.call("is_entry_new", entry_id)) and unlocked


func _create_card_root() -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0.0, 170.0)
	return card


func _create_card_content(card: PanelContainer) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.anchors_preset = Control.PRESET_FULL_RECT
	margin.offset_left = 16.0
	margin.offset_top = 10.0
	margin.offset_right = -16.0
	margin.offset_bottom = -10.0
	card.add_child(margin)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	margin.add_child(content)
	return content


func _create_card_title(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	return label


func _build_tab_intro_text(tab_id: StringName) -> String:
	var tab_name: String = String(_tab_display_name_by_id.get(tab_id, "Unknown"))
	if tab_id == &"enemies":
		return "%s\n\nHow to unlock:\nDefeat enemy types in combat to reveal their entries." % tab_name

	var box_id: String = String(tab_id)
	if box_id.begins_with("lootbox_"):
		box_id = box_id.trim_prefix("lootbox_")

	var description: String = "Open this lootbox to discover summons."
	var lootbox_globals: Node = get_node_or_null("/root/LootboxGlobals")
	if lootbox_globals != null:
		var lootboxes: Dictionary = lootbox_globals.get("lootboxes")
		var lootbox: Lootbox = lootboxes.get(StringName(box_id), null) as Lootbox
		if lootbox != null and not String(lootbox.description).is_empty():
			description = lootbox.description

	var source_hint: String = _box_source_hint(StringName(box_id))
	return "%s\n\n%s\n\nHow to get it:\n%s" % [tab_name, description, source_hint]


func _box_source_hint(box_id: StringName) -> String:
	match box_id:
		&"chaos":
			return "Harvest crystal resources around the map."
		&"forest":
			return "Harvest trees for forest lootboxes."
		&"elemental":
			return "Buy or earn from blood-based progression sources."
		&"greed":
			return "Earn through economy-focused progression and rewards."
		&"soul":
			return "Collect from soul-related objectives and rewards."
		_:
			return "Acquire this lootbox from gameplay rewards."


func _select_tab(tab_id: StringName) -> void:
	if _tab_ids.is_empty():
		return

	var tab_index: int = _tab_ids.find(tab_id)
	if tab_index < 0:
		tab_index = 0
		_selected_tab_id = _tab_ids[0]
	else:
		_selected_tab_id = tab_id

	_entry_page_index = 0
	_tab_bar.current_tab = tab_index
	_refresh_tab_indicators()
	_refresh_cards()


func _select_entry(entry_id: StringName) -> void:
	if entry_id == StringName():
		return

	if _entry_ids_for_selected_tab.find(entry_id) == -1:
		return

	_ensure_entry_page_visible(entry_id)
	_selected_entry_id = entry_id

	var bestiary = _bestiary()
	if bestiary != null and bestiary.has_method("mark_entry_viewed"):
		var was_new: bool = bool(bestiary.call("mark_entry_viewed", entry_id))
		if was_new:
			_refresh_tab_indicators()

	_refresh_cards()
	_apply_selected_highlight(entry_id)


func _apply_selected_highlight(entry_id: StringName) -> void:
	for mapped_entry_id in _entry_panel_by_id.keys():
		var panel: PanelContainer = _entry_panel_by_id[mapped_entry_id] as PanelContainer
		if panel == null:
			continue
		panel.self_modulate = Color(1.0, 1.0, 1.0, 1.0)

	var selected_panel: PanelContainer = _entry_panel_by_id.get(entry_id, null) as PanelContainer
	if selected_panel != null:
		selected_panel.self_modulate = Color(0.9, 1.0, 0.9, 1.0)


func _ensure_entry_page_visible(entry_id: StringName) -> void:
	var index: int = _entry_ids_for_selected_tab.find(entry_id)
	if index < 0:
		return

	var desired_page: int = int(floor(float(index) / float(ENTRIES_PER_PAGE)))
	if desired_page == _entry_page_index:
		return

	_entry_page_index = desired_page
	_refresh_page_controls()


func _refresh_page_controls() -> void:
	var total_pages: int = _get_total_pages()
	var current_page_display: int = _entry_page_index + 1
	_page_label.text = "Page %d/%d" % [maxi(current_page_display, 1), max(total_pages, 1)]

	_prev_page_button.disabled = _entry_page_index <= 0
	_next_page_button.disabled = _entry_page_index >= total_pages - 1

	var should_show: bool = total_pages > 1
	_prev_page_button.visible = should_show
	_next_page_button.visible = should_show
	_page_label.visible = should_show


func _get_total_pages() -> int:
	if _entry_ids_for_selected_tab.is_empty():
		return 1
	return int(ceil(float(_entry_ids_for_selected_tab.size()) / float(ENTRIES_PER_PAGE)))


func _on_prev_page_pressed() -> void:
	if _entry_page_index <= 0:
		return
	_entry_page_index -= 1
	_refresh_cards()


func _on_next_page_pressed() -> void:
	if _entry_page_index >= _get_total_pages() - 1:
		return
	_entry_page_index += 1
	_refresh_cards()


func _on_tab_changed(tab_index: int) -> void:
	if tab_index < 0 or tab_index >= _tab_ids.size():
		return

	_selected_tab_id = _tab_ids[tab_index]
	_entry_page_index = 0
	_refresh_tab_indicators()
	_refresh_cards()


func _on_entry_pressed(entry_id: StringName) -> void:
	_select_entry(entry_id)


func _on_bestiary_entry_unlocked(entry_id: StringName, _entry_type: StringName, _source_tab_id: StringName, prompt_player: bool) -> void:
	_refresh_tab_indicators()
	if not _is_panel_open: 
		_select_tab(_source_tab_id)
	
	if _selected_entry_id == entry_id:
		_select_entry(entry_id)
	else:
		_refresh_cards()

	if not prompt_player or _is_panel_open:
		return

	var payload: Dictionary = {
		"entry_id": entry_id,
	}
	if _is_prompt_duplicate(payload):
		return

	_prompt_queue.append(payload)
	_refresh_prompt_notification()


func _is_prompt_duplicate(payload: Dictionary) -> bool:
	var payload_entry: StringName = payload.get("entry_id", StringName()) as StringName
	for queued in _prompt_queue:
		if (queued.get("entry_id", StringName()) as StringName) == payload_entry:
			return true
	return false


func _refresh_prompt_notification() -> void:
	if _is_panel_open or _prompt_queue.is_empty():
		_stop_prompt_fade_tween()
		_prompt_panel.visible = false
		return

	var entry_id: StringName = (_prompt_queue[_prompt_queue.size() - 1] as Dictionary).get("entry_id", StringName()) as StringName
	var bestiary = _bestiary()
	var entry: Dictionary = bestiary.get_entry(entry_id) if bestiary != null else {}
	var display_name: String = String(entry.get("display_name", "Unknown"))
	_prompt_label.text = "New bestiary entry unlocked: %s. Press B to check the bestiary." % display_name
	_prompt_panel.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_prompt_panel.visible = true
	_start_prompt_fade()


func _clear_prompt_notifications() -> void:
	_stop_prompt_fade_tween()
	_prompt_queue.clear()
	_prompt_panel.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_prompt_panel.visible = false


func _on_bestiary_entry_new_state_changed(_entry_id: StringName, _is_new: bool) -> void:
	_refresh_tab_indicators()
	refresh_cards_if_visible()
	if not _is_panel_open:
		_refresh_prompt_notification()


func refresh_cards_if_visible() -> void:
	if _is_panel_open:
		_refresh_cards()


func _update_badge_animation() -> void:
	var time_msec: int = Time.get_ticks_msec()
	for entry_id_value in _entry_badge_by_id.keys():
		var entry_id: StringName = entry_id_value as StringName
		var badge: Control = _entry_badge_by_id.get(entry_id, null) as Control
		if badge == null:
			continue

		var right_padding: float = float(badge.get_meta("right_padding", 4.0))
		var badge_width: float = float(badge.get_meta("badge_width", 26.0))
		var badge_height: float = float(badge.get_meta("badge_height", 26.0))
		var base_y: float = float(badge.get_meta("base_y", -4.0))

		var card: Control = _entry_panel_by_id.get(entry_id, null) as Control
		if card != null:
			var right_x: float = card.size.x - badge_width - right_padding
			badge.offset_left = right_x
			badge.offset_right = right_x + badge_width

		if not badge.visible:
			badge.offset_top = base_y
			badge.offset_bottom = base_y + badge_height
			continue

		var phase: float = float(int(badge.get_instance_id()) % 17)
		var bounce: float = sin((float(time_msec) * BADGE_BOUNCE_SPEED) + phase) * BADGE_BOUNCE_AMPLITUDE
		var y: float = base_y + bounce
		badge.offset_top = y
		badge.offset_bottom = y + badge_height


func _start_prompt_fade() -> void:
	_stop_prompt_fade_tween()
	_prompt_fade_tween = create_tween()
	_prompt_fade_tween.tween_interval(PROMPT_SHOW_DURATION)
	_prompt_fade_tween.tween_property(_prompt_panel, "modulate:a", 0.0, PROMPT_FADE_DURATION)
	_prompt_fade_tween.tween_callback(Callable(self, "_on_prompt_fade_finished"))


func _stop_prompt_fade_tween() -> void:
	if is_instance_valid(_prompt_fade_tween):
		_prompt_fade_tween.kill()
	_prompt_fade_tween = null


func _on_prompt_fade_finished() -> void:
	_prompt_queue.clear()
	_prompt_panel.visible = false
	_prompt_panel.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_prompt_fade_tween = null


func _refresh_tab_indicators() -> void:
	var bestiary = _bestiary()
	if bestiary == null:
		return

	for index in range(_tab_ids.size()):
		var tab_id: StringName = _tab_ids[index]
		var base_name: String = String(_tab_display_name_by_id.get(tab_id, "Unknown"))
		_tab_bar.set_tab_title(index, base_name)

		var has_new: bool = bestiary.has_method("tab_has_new_entries") and bool(bestiary.call("tab_has_new_entries", tab_id))
		if has_new:
			_tab_bar.set_tab_icon(index, _tab_new_icon)
		else:
			_tab_bar.set_tab_icon(index, null)


func _create_tab_new_icon() -> Texture2D:
	var image := Image.create(11, 11, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var yellow := Color(1.0, 0.9, 0.15, 1.0)

	for y in range(1, 8):
		for x in range(4, 7):
			image.set_pixel(x, y, yellow)

	for y in range(9, 11):
		for x in range(4, 7):
			image.set_pixel(x, y - 1, yellow)

	var texture := ImageTexture.create_from_image(image)
	return texture


func _create_entry_badge_background_icon() -> Texture2D:
	var badge_size: int = 26
	var image := Image.create(badge_size, badge_size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))

	var center: Vector2 = Vector2(12.5, 12.5)
	var radius: float = 11.0
	var outline_radius: float = 12.0
	var white := Color(1.0, 1.0, 1.0, 1.0)
	var outline := Color(0.84, 0.84, 0.84, 1.0)

	for y in range(badge_size):
		for x in range(badge_size):
			var pixel_center: Vector2 = Vector2(float(x) + 0.5, float(y) + 0.5)
			var distance: float = pixel_center.distance_to(center)
			if distance <= radius:
				image.set_pixel(x, y, white)
			elif distance <= outline_radius:
				image.set_pixel(x, y, outline)

	return ImageTexture.create_from_image(image)


func _bestiary() -> Node:
	return get_node_or_null("/root/BestiaryGlobals")
