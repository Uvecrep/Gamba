extends CanvasLayer

@export var player_path: NodePath = ^"../player"
@export var interact_action: StringName = &"interact"
@export var summon_command_hold_action: StringName = &"summon_command_hold"
@export var summon_command_follow_action: StringName = &"summon_command_follow"
@export var summon_command_auto_action: StringName = &"summon_command_auto"
@export var sapling_debug_refresh_interval: float = 0.2
const INPUT_HINT_UTIL: GDScript = preload("res://scripts/input_hint.gd")

@onready var _lootbox_count_label: Label = get_node_or_null("LootboxCountLabel") as Label
@onready var _lootbox_prompt_label: Label = get_node_or_null("LootboxPromptLabel") as Label
@onready var _sapling_debug_label: Label = get_node_or_null("SaplingPlantDebugLabel") as Label
@onready var _summon_command_hint_label: Label = get_node_or_null("SummonCommandHintLabel") as Label


var _interact_hint_text: String = "E"
var _summon_hold_hint_text: String = "H"
var _summon_follow_hint_text: String = "F"
var _summon_auto_hint_text: String = "R"
var _player: Player = null
var _sapling_debug_time_to_refresh: float = 0.0

# TODO: I, Kyle, have borked most of this functionality. It still compiles though, so leaving for the time being

func _ready() -> void:
	_interact_hint_text = INPUT_HINT_UTIL.resolve_action_hint(interact_action)
	_summon_hold_hint_text = INPUT_HINT_UTIL.resolve_action_hint(summon_command_hold_action)
	_summon_follow_hint_text = INPUT_HINT_UTIL.resolve_action_hint(summon_command_follow_action)
	_summon_auto_hint_text = INPUT_HINT_UTIL.resolve_action_hint(summon_command_auto_action)
	_update_summon_hint_label()
	_update_label(0, 0)
	_update_prompt(0, 0)

	var player_node: Node = get_node_or_null(player_path)
	if player_node == null:
		_update_label(0, 0)
		_update_sapling_plant_debug_label()
		push_warning("LootboxCounterHUD: player node was not found at player_path")
		return
	if not (player_node is Player):
		_update_label(0, 0)
		_update_sapling_plant_debug_label()
		push_warning("LootboxCounterHUD: player is not a Player instance")
		return

	_player = player_node as Player

	if not _player.has_signal("lootbox_inventory_changed"):
		_update_label(0, 0)
		_update_sapling_plant_debug_label()
		push_warning("LootboxCounterHUD: player does not expose lootbox_inventory_changed")
		return

	var inventory_changed_callable: Callable = Callable(self, "_on_lootbox_inventory_changed")
	if not _player.is_connected("lootbox_inventory_changed", inventory_changed_callable):
		_player.connect("lootbox_inventory_changed", inventory_changed_callable)

	if _player.has_signal("sapling_carried_changed"):
		var sapling_changed_callable: Callable = Callable(self, "_on_sapling_carried_changed")
		if not _player.is_connected("sapling_carried_changed", sapling_changed_callable):
			_player.connect("sapling_carried_changed", sapling_changed_callable)

	_refresh_lootbox_state_from_player()
	_update_sapling_plant_debug_label()

func _process(_delta: float) -> void:
	_sapling_debug_time_to_refresh = maxf(_sapling_debug_time_to_refresh - _delta, 0.0)
	if _sapling_debug_time_to_refresh > 0.0:
		return

	_sapling_debug_time_to_refresh = maxf(sapling_debug_refresh_interval, 0.05)
	_update_sapling_plant_debug_label()

	#var initial_count_variant: Variant = player.call("get_lootbox_count")
	#_update_label(int(initial_count_variant))

func _on_lootbox_inventory_changed(chaos_count: int, forest_count: int, _selected_kind: int) -> void:
	_update_label(chaos_count, forest_count)
	_update_prompt(chaos_count, forest_count)

func _update_label(chaos_count: int, forest_count: int) -> void:
	if _lootbox_count_label == null:
		return
	var clamped_chaos_count := maxi(chaos_count, 0)
	var clamped_forest_count := maxi(forest_count, 0)
	_lootbox_count_label.text = "Chaos Boxes: %d   Forest Boxes: %d" % [clamped_chaos_count, clamped_forest_count]

func _update_prompt(chaos_count: int, forest_count: int) -> void:
	if _lootbox_prompt_label == null:
		return

	var total_count := maxi(chaos_count, 0) + maxi(forest_count, 0)
	var should_show := total_count > 0
	_lootbox_prompt_label.visible = should_show
	if not should_show:
		return

	_lootbox_prompt_label.text = "Press %s to use selected inventory item" % _interact_hint_text

func _refresh_lootbox_state_from_player() -> void:
	if _player == null:
		return

	var chaos_count: int = _player.get_chaos_lootbox_count()
	var forest_count: int = _player.get_forest_lootbox_count()

	_update_label(chaos_count, forest_count)
	_update_prompt(chaos_count, forest_count)

func _on_sapling_carried_changed(_is_carrying: bool) -> void:
	_update_sapling_plant_debug_label()

func _update_sapling_plant_debug_label() -> void:
	if _sapling_debug_label == null:
		return
	if _player == null:
		_sapling_debug_label.visible = false
		return

	var is_carrying: bool = _player.is_carrying_sapling()
	_sapling_debug_label.visible = is_carrying
	if not is_carrying:
		return

	var can_plant: bool = _player.can_plant_sapling_here()

	var status_text: String = "No"
	if can_plant:
		status_text = "Yes"

	_sapling_debug_label.text = "Sapling Can Plant: %s (Press %s)" % [status_text, _interact_hint_text]

func _update_summon_hint_label() -> void:
	if _summon_command_hint_label == null:
		return

	_summon_command_hint_label.text = "MMB: Select summons | %s: Hold | %s: Follow | %s: Auto" % [
		_summon_hold_hint_text,
		_summon_follow_hint_text,
		_summon_auto_hint_text,
	]
