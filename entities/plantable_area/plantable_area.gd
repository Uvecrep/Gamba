extends Area2D
class_name PlantableArea

@onready var _plant_hint_label: Label = get_node_or_null("PlantHintLabel") as Label

var is_occupied: bool = false:
	set(value):
		is_occupied = value
		_update_plant_hint_visibility()

var _player: Player = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_player = _find_player()
	if _player != null and _player.player_inventory != null:
		_player.player_inventory.selected_index_changed.connect(_on_player_inventory_changed)
		_player.player_inventory.inventory_changed.connect(_on_player_inventory_changed)
	_update_plant_hint_visibility()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_player_inventory_changed(_arg: Variant = null) -> void:
	_update_plant_hint_visibility()


func _update_plant_hint_visibility() -> void:
	if _plant_hint_label == null:
		return

	_plant_hint_label.visible = not is_occupied and _has_equipped_sapling()


func _has_equipped_sapling() -> bool:
	if _player == null or _player.player_inventory == null:
		return false

	return _player.player_inventory.get_slot_item_id(_player.player_inventory.selected_index) == &"sapling"


func _find_player() -> Player:
	var players: Array = get_tree().get_nodes_in_group("players")
	for candidate in players:
		if candidate is Player:
			return candidate as Player

	return null
