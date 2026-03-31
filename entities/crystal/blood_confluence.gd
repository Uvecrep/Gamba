extends HarvestNode
class_name BloodConfluence

@export var player_ref: Player

@export var _lootbox_sprite: Sprite2D
@export var _blood_count_label: Label
@export var _box_cost_label: Label

@export var lootbox_cost_in_blood: int = 5

var blood: float: # UNUSED NOW
	get:
		return float(get_harvest_count())
	set(value):
		_set_blood(value)

func _get_harvest_capacity() -> int:
	return 1_000_000

func _get_growth_amount_per_tick() -> int:
	return 0

func _ready() -> void:
	produced_lootbox_id = &"lootbox_elemental"
	harvest_prompt_action = &"interact"
	super._ready()
	set_growth_paused(true)

	add_to_group("blood_confluence")
	add_to_group("interactable")
	_refresh_lootbox_sprite_texture()
	_update_visuals()

func try_purchase_lootbox(_player : Player) -> bool:
	if _player.player_inventory.blood_count < lootbox_cost_in_blood:
		return false

	_spawn_lootbox_pickups(1)
	
	var previous_blood = _player.player_inventory.blood_count
	_player.player_inventory.blood_count -= lootbox_cost_in_blood
	_player.player_inventory.blood_count_changed.emit(_player.player_inventory.blood_count, previous_blood)
	
	_update_visuals()
	return true

func can_interact_with_player(player: Node2D) -> bool:
	if player == null:
		return false

	var interact_range: float = default_harvest_range
	if player.has_method("get"):
		interact_range = maxf(interact_range, float(player.get("harvest_range")))

	return global_position.distance_squared_to(player.global_position) <= interact_range * interact_range

func harvest_fruit(_amount: int = 1) -> int:
	if not can_harvest():
		return 0

	_spawn_lootbox_pickups(1)
	_set_harvest_count(get_harvest_count() - lootbox_cost_in_blood)
	return 1

func _set_blood(_new_blood: float) -> void:
	_set_harvest_count(maxi(int(round(_new_blood)), 0))

func _on_harvest_count_changed(_previous_count: int, _current_count: int) -> void:
	_update_visuals()

func _update_visuals() -> void:
	
	if _lootbox_sprite != null:
		_lootbox_sprite.visible = player_ref.player_inventory.blood_count >= lootbox_cost_in_blood

	if _blood_count_label != null:
		_blood_count_label.text = "blood: " + str(get_harvest_count())
	if _box_cost_label != null:
		_box_cost_label.text = "box cost in blood: " + str(lootbox_cost_in_blood)

func _update_harvest_prompt() -> void:
	if _harvest_prompt_label == null:
		return

	var should_show: bool = player_ref.player_inventory.blood_count >= lootbox_cost_in_blood and _is_any_player_in_harvest_range()
	_harvest_prompt_label.visible = should_show
	if not should_show:
		return

	_harvest_prompt_label.text = "Press %s to convert" % _harvest_hint_text


func _refresh_lootbox_sprite_texture() -> void:
	if _lootbox_sprite == null:
		return
	if produced_lootbox_id == StringName():
		return
	if ItemGlobals == null:
		return

	var item: ItemData = ItemGlobals.items.get(produced_lootbox_id, null) as ItemData
	if item == null:
		return
	if item.texture == null:
		return

	_lootbox_sprite.texture = item.texture
