extends CanvasLayer

@export var player_path: NodePath = ^"../player"
@export var use_lootbox_action: StringName = &"use_lootbox"
@export var select_chaos_lootbox_action: StringName = &"select_chaos_lootbox"
@export var select_forest_lootbox_action: StringName = &"select_forest_lootbox"
@export var interact_action: StringName = &"interact"

@onready var _lootbox_count_label: Label = $LootboxCountLabel
@onready var _lootbox_prompt_label: Label = $LootboxPromptLabel
@onready var _sapling_debug_label: Label = get_node_or_null("SaplingPlantDebugLabel") as Label

var _use_lootbox_hint_text: String = "lootbox button"
var _select_chaos_hint_text: String = "1"
var _select_forest_hint_text: String = "2"
var _interact_hint_text: String = "E"
var _player: Node = null

func _ready() -> void:
	_use_lootbox_hint_text = _resolve_action_hint(use_lootbox_action)
	_select_chaos_hint_text = _resolve_action_hint(select_chaos_lootbox_action)
	_select_forest_hint_text = _resolve_action_hint(select_forest_lootbox_action)
	_interact_hint_text = _resolve_action_hint(interact_action)
	_update_label(0, 0)
	_update_prompt(0, 0, 0)

	var player: Node = get_node_or_null(player_path)
	if player == null:
		_update_label(0, 0)
		_update_sapling_plant_debug_label()
		push_warning("LootboxCounterHUD: player node was not found at player_path")
		return

	_player = player

	if not player.has_signal("lootbox_inventory_changed"):
		_update_label(0, 0)
		_update_sapling_plant_debug_label()
		push_warning("LootboxCounterHUD: player does not expose lootbox_inventory_changed")
		return

	var inventory_changed_callable: Callable = Callable(self, "_on_lootbox_inventory_changed")
	if not player.is_connected("lootbox_inventory_changed", inventory_changed_callable):
		player.connect("lootbox_inventory_changed", inventory_changed_callable)

	if player.has_signal("sapling_carried_changed"):
		var sapling_changed_callable: Callable = Callable(self, "_on_sapling_carried_changed")
		if not player.is_connected("sapling_carried_changed", sapling_changed_callable):
			player.connect("sapling_carried_changed", sapling_changed_callable)

	_refresh_lootbox_state_from_player()
	_update_sapling_plant_debug_label()

func _process(_delta: float) -> void:
	_update_sapling_plant_debug_label()

	#var initial_count_variant: Variant = player.call("get_lootbox_count")
	#_update_label(int(initial_count_variant))

func _on_lootbox_inventory_changed(chaos_count: int, forest_count: int, selected_kind: int) -> void:
	_update_label(chaos_count, forest_count)
	_update_prompt(chaos_count, forest_count, selected_kind)

func _update_label(chaos_count: int, forest_count: int) -> void:
	var clamped_chaos_count := maxi(chaos_count, 0)
	var clamped_forest_count := maxi(forest_count, 0)
	_lootbox_count_label.text = "Chaos Boxes: %d   Forest Boxes: %d" % [clamped_chaos_count, clamped_forest_count]

func _update_prompt(chaos_count: int, forest_count: int, selected_kind: int) -> void:
	if _lootbox_prompt_label == null:
		return

	var total_count := maxi(chaos_count, 0) + maxi(forest_count, 0)
	var should_show := total_count > 0
	_lootbox_prompt_label.visible = should_show
	if not should_show:
		return

	var selected_name: String = "Chaos"
	if selected_kind == 1:
		selected_name = "Forest"

	_lootbox_prompt_label.text = "Press %s to open selected (%s) | %s=Chaos %s=Forest" % [
		_use_lootbox_hint_text,
		selected_name,
		_select_chaos_hint_text,
		_select_forest_hint_text,
	]

func _refresh_lootbox_state_from_player() -> void:
	if _player == null:
		return

	var chaos_count: int = 0
	if _player.has_method("get_chaos_lootbox_count"):
		chaos_count = int(_player.call("get_chaos_lootbox_count"))

	var forest_count: int = 0
	if _player.has_method("get_forest_lootbox_count"):
		forest_count = int(_player.call("get_forest_lootbox_count"))

	var selected_kind: int = 0
	if _player.has_method("get_selected_lootbox_kind"):
		selected_kind = int(_player.call("get_selected_lootbox_kind"))

	_update_label(chaos_count, forest_count)
	_update_prompt(chaos_count, forest_count, selected_kind)

func _on_sapling_carried_changed(_is_carrying: bool) -> void:
	_update_sapling_plant_debug_label()

func _update_sapling_plant_debug_label() -> void:
	if _sapling_debug_label == null:
		return
	if _player == null:
		_sapling_debug_label.visible = false
		return
	if not _player.has_method("is_carrying_sapling"):
		_sapling_debug_label.visible = false
		return

	var is_carrying: bool = bool(_player.call("is_carrying_sapling"))
	_sapling_debug_label.visible = is_carrying
	if not is_carrying:
		return

	var can_plant: bool = false
	if _player.has_method("can_plant_sapling_here"):
		can_plant = bool(_player.call("can_plant_sapling_here"))

	var status_text: String = "No"
	if can_plant:
		status_text = "Yes"

	_sapling_debug_label.text = "Sapling Can Plant: %s (Press %s)" % [status_text, _interact_hint_text]

func _resolve_action_hint(action: StringName) -> String:
	if not InputMap.has_action(action):
		return String(action).to_upper()

	var events: Array[InputEvent] = InputMap.action_get_events(action)
	for event in events:
		if event == null:
			continue

		if event is InputEventKey:
			var key_event := event as InputEventKey
			if key_event.physical_keycode != 0:
				return OS.get_keycode_string(key_event.physical_keycode)
			if key_event.keycode != 0:
				return OS.get_keycode_string(key_event.keycode)

		var event_text := event.as_text()
		if not event_text.is_empty():
			return event_text

	return String(action).to_upper()
