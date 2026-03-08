extends CanvasLayer

@export var player_path: NodePath = ^"../player"

@onready var _lootbox_count_label: Label = $LootboxCountLabel

func _ready() -> void:
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
	_lootbox_count_label.text = "Lootboxes: %d" % maxi(current_count, 0)
