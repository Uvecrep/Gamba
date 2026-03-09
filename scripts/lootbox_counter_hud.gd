extends CanvasLayer

@export var player_path: NodePath = ^"../player"
@export var use_lootbox_action: StringName = &"use_lootbox"

@onready var _lootbox_count_label: Label = $LootboxCountLabel
@onready var _lootbox_prompt_label: Label = $LootboxPromptLabel

var _use_lootbox_hint_text: String = "lootbox button"

func _ready() -> void:
	_use_lootbox_hint_text = _resolve_action_hint(use_lootbox_action)
	_update_prompt(0)

	var player: Node = get_node_or_null(player_path)
	if player == null:
		_update_label(0)
		push_warning("LootboxCounterHUD: player node was not found at player_path")
		return

	if not player.has_signal("lootbox_inventory_changed"):
		_update_label(0)
		push_warning("LootboxCounterHUD: player does not expose lootbox_inventory_changed")
		return

	var inventory_changed_callable: Callable = Callable(self, "_on_lootbox_inventory_changed")
	if not player.is_connected("lootbox_inventory_changed", inventory_changed_callable):
		player.connect("lootbox_inventory_changed", inventory_changed_callable)

	var initial_count_variant: Variant = player.call("get_lootbox_count")
	_update_label(int(initial_count_variant))

func _on_lootbox_inventory_changed(current: int, _previous: int) -> void:
	_update_label(current)

func _update_label(current_count: int) -> void:
	var clamped_count := maxi(current_count, 0)
	_lootbox_count_label.text = "Lootboxes: %d" % clamped_count
	_update_prompt(clamped_count)

func _update_prompt(current_count: int) -> void:
	if _lootbox_prompt_label == null:
		return

	var should_show := current_count > 0
	_lootbox_prompt_label.visible = should_show
	if not should_show:
		return

	_lootbox_prompt_label.text = "Press %s to open a lootbox" % _use_lootbox_hint_text

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
