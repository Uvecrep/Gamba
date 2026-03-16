extends CanvasLayer

@export var player: Player
@export var _lootbox_prompt_label: Label
@export var _sapling_debug_label: Label
@export var _summon_command_hint_label: Label

var interact_action: StringName = &"interact"
var summon_command_hold_action: StringName = &"summon_command_hold"
var summon_command_follow_action: StringName = &"summon_command_follow"
var summon_command_auto_action: StringName = &"summon_command_auto"

var _interact_hint_text: String = "E"
var _summon_hold_hint_text: String = "H"
var _summon_follow_hint_text: String = "F"
var _summon_auto_hint_text: String = "R"


func _ready() -> void:
	_interact_hint_text = _resolve_action_hint(interact_action)
	_summon_hold_hint_text = _resolve_action_hint(summon_command_hold_action)
	_summon_follow_hint_text = _resolve_action_hint(summon_command_follow_action)
	_summon_auto_hint_text = _resolve_action_hint(summon_command_auto_action)
	
	_update_summon_hint_label()
	_update_sapling_plant_debug_label()
	
	if player == null:
		_update_sapling_plant_debug_label()
		push_warning("LootboxCounterHUD: player node reference was null")
		return

func _process(_delta: float) -> void:
	_update_sapling_plant_debug_label()
	_update_lootbox_prompt_label()

func _update_lootbox_prompt_label() -> void:
	if player == null:
		_lootbox_prompt_label.visible = false
		return
	
	var selected_id = player.player_inventory.inventory_items[player.player_inventory.selected_index]
	var is_holding_lootbox = selected_id.begins_with("lootbox_")
	
	_lootbox_prompt_label.visible = is_holding_lootbox
	_lootbox_prompt_label.text = "Press %s to open a lootbox" % [_interact_hint_text]

func _update_sapling_plant_debug_label() -> void:
	if _sapling_debug_label == null: return
	if player == null:
		_sapling_debug_label.visible = false
		return

	var selected_id = player.player_inventory.inventory_items[player.player_inventory.selected_index]
	var is_holding_sapling: bool = selected_id == &"sapling"
	_sapling_debug_label.visible = is_holding_sapling
	if not is_holding_sapling: return

	var status_text: String = "Yes" if player.can_plant_sapling_here() else "No"
	_sapling_debug_label.text = "Sapling Can Plant: %s (Press %s)" % [status_text, _interact_hint_text]

func _update_summon_hint_label() -> void:
	if _summon_command_hint_label == null: return

	_summon_command_hint_label.text = "MMB: Select summons | %s: Hold | %s: Follow | %s: Auto" % [
		_summon_hold_hint_text,
		_summon_follow_hint_text,
		_summon_auto_hint_text,
	]

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
