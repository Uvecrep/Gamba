extends StaticBody2D
class_name ShopInteractable

const INPUT_HINT_UTIL: GDScript = preload("res://scripts/input_hint.gd")
const PROXIMITY_PROMPT_UTIL: GDScript = preload("res://scripts/proximity_prompt_util.gd")
const PLANTABLE_AREA_SCENE: PackedScene = preload("res://entities/plantable_area/plantable_area.tscn")

const CARD_COUNT: int = 3
const GREED_LOOTBOX_ITEM_ID: StringName = &"lootbox_greed"
const SAPLING_ITEM_ID: StringName = &"sapling"

@export var interact_action: StringName = &"interact"
@export var interact_range: float = 96.0
@export var prompt_refresh_interval: float = 0.2
@export var greed_lootbox_cost: int = 20
@export var planter_cost: int = 120
@export var sapling_bundle_cost: int = 48
@export var sapling_bundle_count: int = 1
@export var max_saplings_purchasable: int = 4
@export var card_base_cost: int = 25
@export var card_cost_growth_per_purchase: int = 12
@export var weight_upgrade_multiplier: float = 1.18
@export var summon_damage_bonus: float = 0.18
@export var summon_health_bonus: float = 0.22
@export var planter_adjacent_spacing: float = 192.0
@export var max_total_planters: int = 6

var _action_hint_text: String = "E"
var _is_open: bool = false
var _prompt_refresh_time_left: float = 0.0
var _spatial_index: SpatialIndex2D
var _current_player: Player
var _shop_purchase_count: int = 0
var _offers: Array[Dictionary] = []
var _sold_card_indices: Dictionary = {}
var _last_offer_day: int = -1
var _day_night_controller: DayNightController
var _saplings_purchased_count: int = 0

@onready var _prompt_label: Label = get_node_or_null("InteractPrompt") as Label
@onready var _shop_layer: CanvasLayer = get_node_or_null("ShopLayer") as CanvasLayer
@onready var _shop_panel: PanelContainer = get_node_or_null("ShopLayer/ShopWindow") as PanelContainer
@onready var _gold_label: Label = get_node_or_null("ShopLayer/ShopWindow/MarginContainer/VBoxContainer/GoldLabel") as Label
@onready var _status_label: Label = get_node_or_null("ShopLayer/ShopWindow/MarginContainer/VBoxContainer/StatusLabel") as Label
@onready var _close_hint_label: Label = get_node_or_null("ShopLayer/ShopWindow/MarginContainer/VBoxContainer/CloseHint") as Label
@onready var _close_button: Button = get_node_or_null("ShopLayer/ShopWindow/MarginContainer/VBoxContainer/CloseButton") as Button
@onready var _greed_button: Button = get_node_or_null("ShopLayer/ShopWindow/MarginContainer/VBoxContainer/GreedRow/BuyGreedButton") as Button
@onready var _greed_cost_label: Label = get_node_or_null("ShopLayer/ShopWindow/MarginContainer/VBoxContainer/GreedRow/GreedCostLabel") as Label
@onready var _planter_button: Button = get_node_or_null("ShopLayer/ShopWindow/MarginContainer/VBoxContainer/PlanterRow/BuyPlanterButton") as Button
@onready var _planter_sold_out_overlay: Control = get_node_or_null("ShopLayer/ShopWindow/MarginContainer/VBoxContainer/PlanterRow/BuyPlanterButton/SoldOutOverlay") as Control
@onready var _planter_cost_label: Label = get_node_or_null("ShopLayer/ShopWindow/MarginContainer/VBoxContainer/PlanterRow/PlanterCostLabel") as Label
@onready var _sapling_button: Button = get_node_or_null("ShopLayer/ShopWindow/MarginContainer/VBoxContainer/SaplingRow/BuySaplingsButton") as Button
@onready var _sapling_sold_out_overlay: Control = get_node_or_null("ShopLayer/ShopWindow/MarginContainer/VBoxContainer/SaplingRow/BuySaplingsButton/SoldOutOverlay") as Control
@onready var _sapling_cost_label: Label = get_node_or_null("ShopLayer/ShopWindow/MarginContainer/VBoxContainer/SaplingRow/SaplingCostLabel") as Label

@onready var _card_title_labels: Array[Label] = [
	get_node_or_null("ShopLayer/ShopWindow/MarginContainer/VBoxContainer/CardsRow/Card1/MarginContainer/VBoxContainer/Title") as Label,
	get_node_or_null("ShopLayer/ShopWindow/MarginContainer/VBoxContainer/CardsRow/Card2/MarginContainer/VBoxContainer/Title") as Label,
	get_node_or_null("ShopLayer/ShopWindow/MarginContainer/VBoxContainer/CardsRow/Card3/MarginContainer/VBoxContainer/Title") as Label,
]
@onready var _card_description_labels: Array[Label] = [
	get_node_or_null("ShopLayer/ShopWindow/MarginContainer/VBoxContainer/CardsRow/Card1/MarginContainer/VBoxContainer/Description") as Label,
	get_node_or_null("ShopLayer/ShopWindow/MarginContainer/VBoxContainer/CardsRow/Card2/MarginContainer/VBoxContainer/Description") as Label,
	get_node_or_null("ShopLayer/ShopWindow/MarginContainer/VBoxContainer/CardsRow/Card3/MarginContainer/VBoxContainer/Description") as Label,
]
@onready var _card_cost_labels: Array[Label] = [
	get_node_or_null("ShopLayer/ShopWindow/MarginContainer/VBoxContainer/CardsRow/Card1/MarginContainer/VBoxContainer/Cost") as Label,
	get_node_or_null("ShopLayer/ShopWindow/MarginContainer/VBoxContainer/CardsRow/Card2/MarginContainer/VBoxContainer/Cost") as Label,
	get_node_or_null("ShopLayer/ShopWindow/MarginContainer/VBoxContainer/CardsRow/Card3/MarginContainer/VBoxContainer/Cost") as Label,
]
@onready var _card_buy_buttons: Array[Button] = [
	get_node_or_null("ShopLayer/ShopWindow/MarginContainer/VBoxContainer/CardsRow/Card1/MarginContainer/VBoxContainer/BuyButton") as Button,
	get_node_or_null("ShopLayer/ShopWindow/MarginContainer/VBoxContainer/CardsRow/Card2/MarginContainer/VBoxContainer/BuyButton") as Button,
	get_node_or_null("ShopLayer/ShopWindow/MarginContainer/VBoxContainer/CardsRow/Card3/MarginContainer/VBoxContainer/BuyButton") as Button,
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("shops")
	_action_hint_text = INPUT_HINT_UTIL.resolve_action_hint(interact_action)
	_spatial_index = get_node_or_null("/root/SpatialIndex") as SpatialIndex2D

	for index: int in range(_card_buy_buttons.size()):
		var button: Button = _card_buy_buttons[index]
		if button != null:
			button.pressed.connect(_on_buy_card_pressed.bind(index))

	if _greed_button != null:
		_greed_button.pressed.connect(_on_buy_greed_pressed)
	if _planter_button != null:
		_planter_button.pressed.connect(_on_buy_planter_pressed)
	if _sapling_button != null:
		_sapling_button.pressed.connect(_on_buy_saplings_pressed)
	if _close_button != null:
		_close_button.pressed.connect(_on_close_pressed)

	_set_shop_open(false)
	_connect_day_night_controller()
	_ensure_daily_offers()
	_refresh_shop_ui()
	_update_prompt()
	_schedule_prompt_refresh(0.0)

func _process(delta: float) -> void:
	_prompt_refresh_time_left = PROXIMITY_PROMPT_UTIL.tick_refresh_time_left(_prompt_refresh_time_left, delta)
	if _prompt_refresh_time_left <= 0.0:
		_update_prompt()
		_schedule_prompt_refresh()

	if _is_open:
		_refresh_gold_label()

func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if not event.is_action_pressed(interact_action) and not event.is_action_pressed(&"ui_cancel"):
		return

	_set_shop_open(false)
	get_viewport().set_input_as_handled()

func can_interact_with_player(player: Node2D) -> bool:
	if player == null:
		return false

	return global_position.distance_squared_to(player.global_position) <= interact_range * interact_range

func interact(player: Player) -> void:
	if _is_open:
		_set_shop_open(false)
		return
	if player == null:
		return
	if not can_interact_with_player(player):
		return

	_current_player = player
	_ensure_daily_offers()
	_set_status("Choose an upgrade card or buy a resource.")
	_set_shop_open(true)
	_refresh_shop_ui()

func _set_shop_open(should_open: bool) -> void:
	_is_open = should_open
	if should_open:
		Audio.play_ui(&"ui_panel_open")
	else:
		Audio.play_ui(&"ui_panel_close")
	if _shop_layer != null:
		_shop_layer.visible = should_open
	if _shop_panel != null:
		_shop_panel.visible = should_open
	if _close_hint_label != null:
		_close_hint_label.text = "Press %s to close shop" % _action_hint_text
	if should_open and _card_buy_buttons.size() > 0 and _card_buy_buttons[0] != null:
		_card_buy_buttons[0].grab_focus()

func is_shop_open() -> bool:
	return _is_open

func _on_buy_card_pressed(card_index: int) -> void:
	if card_index < 0 or card_index >= _offers.size():
		Audio.play_ui(&"ui_inventory_invalid")
		return
	if _sold_card_indices.has(card_index):
		Audio.play_ui(&"ui_inventory_invalid")
		_set_status("That card is sold out for today.")
		_refresh_shop_ui()
		return
	if _current_player == null:
		_set_status("No player selected for this shop session.")
		return

	var offer: Dictionary = _offers[card_index]
	var card_cost: int = int(offer.get("cost", 0))
	if not _try_spend_gold(card_cost):
		Audio.play_ui(&"ui_inventory_invalid")
		_set_status("Not enough gold for that upgrade.")
		_refresh_shop_ui()
		return

	if not _apply_offer(offer):
		_refund_gold(card_cost)
		Audio.play_ui(&"ui_inventory_invalid")
		_set_status("Upgrade failed. Your gold was refunded.")
		_refresh_shop_ui()
		return

	_shop_purchase_count += 1
	_sold_card_indices[card_index] = true
	Audio.play_ui(&"ui_button_click")
	_set_status("Purchased: %s" % String(offer.get("title", "Upgrade")))
	_refresh_shop_ui()

func _on_buy_greed_pressed() -> void:
	if _current_player == null:
		_set_status("No player selected for this shop session.")
		return
	if not _try_spend_gold(greed_lootbox_cost):
		Audio.play_ui(&"ui_inventory_invalid")
		_set_status("Not enough gold for a Greed lootbox.")
		_refresh_shop_ui()
		return
	if not _current_player.player_inventory.add_items(GREED_LOOTBOX_ITEM_ID, 1):
		_refund_gold(greed_lootbox_cost)
		Audio.play_ui(&"ui_inventory_invalid")
		_set_status("Inventory full. Could not add a Greed lootbox.")
		_refresh_shop_ui()
		return

	Audio.play_ui(&"ui_button_click")
	_set_status("Purchased 1 Greed lootbox.")
	_refresh_shop_ui()

func _on_buy_planter_pressed() -> void:
	if _current_player == null:
		_set_status("No player selected for this shop session.")
		return
	if _has_reached_planter_limit():
		Audio.play_ui(&"ui_inventory_invalid")
		_set_status("Planter limit reached (max %d)." % max_total_planters)
		_refresh_shop_ui()
		return
	if not _try_spend_gold(planter_cost):
		Audio.play_ui(&"ui_inventory_invalid")
		_set_status("Not enough gold for a planter.")
		_refresh_shop_ui()
		return
	if not _spawn_purchased_planter():
		_refund_gold(planter_cost)
		Audio.play_ui(&"ui_inventory_invalid")
		_set_status("Could not place a new planter right now.")
		_refresh_shop_ui()
		return

	Audio.play_ui(&"ui_button_click")
	_set_status("Purchased 1 planter.")
	_refresh_shop_ui()

func _on_buy_saplings_pressed() -> void:
	if _current_player == null:
		_set_status("No player selected for this shop session.")
		return
	if _has_reached_sapling_purchase_limit():
		Audio.play_ui(&"ui_inventory_invalid")
		_set_status("Saplings are sold out (max %d)." % max_saplings_purchasable)
		_refresh_shop_ui()
		return
	if not _try_spend_gold(sapling_bundle_cost):
		Audio.play_ui(&"ui_inventory_invalid")
		_set_status("Not enough gold for saplings.")
		_refresh_shop_ui()
		return
	if not _current_player.player_inventory.add_items(SAPLING_ITEM_ID, sapling_bundle_count):
		_refund_gold(sapling_bundle_cost)
		Audio.play_ui(&"ui_inventory_invalid")
		_set_status("Inventory full. Could not add saplings.")
		_refresh_shop_ui()
		return

	_saplings_purchased_count += sapling_bundle_count
	Audio.play_ui(&"ui_button_click")
	_set_status("Purchased 1 sapling." if sapling_bundle_count == 1 else "Purchased %d saplings." % sapling_bundle_count)
	_refresh_shop_ui()

func _on_close_pressed() -> void:
	_set_shop_open(false)

func _try_spend_gold(amount: int) -> bool:
	if _current_player == null:
		return false
	if _current_player.player_inventory == null:
		return false
	return _current_player.player_inventory.spend_gold(maxi(amount, 0))

func _refund_gold(amount: int) -> void:
	if _current_player == null:
		return
	if _current_player.player_inventory == null:
		return
	_current_player.player_inventory.add_gold(maxi(amount, 0))

func _set_status(status_text: String) -> void:
	if _status_label != null:
		_status_label.text = status_text

func _refresh_shop_ui() -> void:
	_refresh_gold_label()
	if _greed_cost_label != null:
		_greed_cost_label.text = "Cost: %d gold" % greed_lootbox_cost
	var planter_limit_reached: bool = _has_reached_planter_limit()
	if _planter_cost_label != null:
		_planter_cost_label.text = "Sold Out" if planter_limit_reached else "Cost: %d gold" % planter_cost
	if _planter_sold_out_overlay != null:
		_planter_sold_out_overlay.visible = planter_limit_reached
	var sapling_limit_reached: bool = _has_reached_sapling_purchase_limit()
	if _sapling_cost_label != null:
		_sapling_cost_label.text = "Sold Out" if sapling_limit_reached else "Cost: %d gold" % sapling_bundle_cost
	if _sapling_sold_out_overlay != null:
		_sapling_sold_out_overlay.visible = sapling_limit_reached
	if _sapling_button != null:
		if sapling_limit_reached:
			_sapling_button.text = "Sold Out"
		else:
			_sapling_button.text = "Buy Sapling" if sapling_bundle_count == 1 else "Buy %d Saplings" % sapling_bundle_count

	for index: int in range(CARD_COUNT):
		var offer: Dictionary = {}
		if index < _offers.size():
			offer = _offers[index]
		var has_offer: bool = not offer.is_empty()

		if index < _card_title_labels.size() and _card_title_labels[index] != null:
			_card_title_labels[index].text = String(offer.get("title", "No Offer")) if has_offer else "No Offer"
		if index < _card_description_labels.size() and _card_description_labels[index] != null:
			_card_description_labels[index].text = String(offer.get("description", "")) if has_offer else ""
		if index < _card_cost_labels.size() and _card_cost_labels[index] != null:
			if has_offer:
				if _sold_card_indices.has(index):
					_card_cost_labels[index].text = "Sold Out"
				else:
					_card_cost_labels[index].text = "Cost: %d gold" % int(offer.get("cost", 0))
			else:
				_card_cost_labels[index].text = ""

		if index < _card_buy_buttons.size() and _card_buy_buttons[index] != null:
			if has_offer:
				if _sold_card_indices.has(index):
					_card_buy_buttons[index].disabled = true
					_card_buy_buttons[index].text = "Sold Out"
				else:
					var can_afford: bool = _can_afford(int(offer.get("cost", 0)))
					_card_buy_buttons[index].disabled = not can_afford
					_card_buy_buttons[index].text = "Buy"
			else:
				_card_buy_buttons[index].disabled = true
				_card_buy_buttons[index].text = "Unavailable"

	if _greed_button != null:
		_greed_button.disabled = not _can_afford(greed_lootbox_cost) or not _can_receive_item(GREED_LOOTBOX_ITEM_ID)
	if _planter_button != null:
		_planter_button.disabled = planter_limit_reached or not _can_afford(planter_cost) or not _has_available_planter_slot()
		_planter_button.text = "Sold Out" if planter_limit_reached else "Buy Planter"
	if _sapling_button != null:
		_sapling_button.disabled = sapling_limit_reached or not _can_afford(sapling_bundle_cost) or not _can_receive_item(SAPLING_ITEM_ID)

func _refresh_gold_label() -> void:
	if _gold_label == null:
		return
	if _current_player == null or _current_player.player_inventory == null:
		_gold_label.text = "Gold: --"
		return

	_gold_label.text = "Gold: %d" % _current_player.player_inventory.get_gold_count()

func _can_afford(cost: int) -> bool:
	if _current_player == null:
		return false
	if _current_player.player_inventory == null:
		return false
	return _current_player.player_inventory.has_gold(cost)

func _can_receive_item(item_id: StringName) -> bool:
	if _current_player == null:
		return false
	if _current_player.player_inventory == null:
		return false
	return _current_player.player_inventory.would_item_fit(item_id)

func _has_available_planter_slot() -> bool:
	if _has_reached_planter_limit():
		return false
	return _find_next_planter_position() != null

func _has_reached_planter_limit() -> bool:
	if max_total_planters <= 0:
		return false
	return _get_existing_planters().size() >= max_total_planters

func _has_reached_sapling_purchase_limit() -> bool:
	if max_saplings_purchasable <= 0:
		return false
	return _saplings_purchased_count >= max_saplings_purchasable

func _connect_day_night_controller() -> void:
	var controller: DayNightController = _find_day_night_controller()
	if controller == null:
		return

	_day_night_controller = controller
	if not controller.day_started.is_connected(_on_day_started):
		controller.day_started.connect(_on_day_started)

func _find_day_night_controller() -> DayNightController:
	if get_tree() == null:
		return null

	var controllers: Array = get_tree().get_nodes_in_group("day_night_cycle_controllers")
	for controller_node in controllers:
		if controller_node is DayNightController:
			return controller_node as DayNightController

	return null

func _spawn_purchased_planter() -> bool:
	if PLANTABLE_AREA_SCENE == null:
		return false

	var world_parent: Node = get_parent()
	if world_parent == null:
		return false

	if _has_reached_planter_limit():
		return false

	var next_planter_position_variant: Variant = _find_next_planter_position()
	if next_planter_position_variant == null:
		return false

	var planter: PlantableArea = PLANTABLE_AREA_SCENE.instantiate() as PlantableArea
	if planter == null:
		return false

	world_parent.add_child(planter)
	planter.global_position = next_planter_position_variant as Vector2
	planter.is_occupied = false
	_schedule_navigation_rebuild()
	return true

func _find_next_planter_position() -> Variant:
	if planter_adjacent_spacing <= 0.0:
		return null

	var planters: Array[PlantableArea] = _get_existing_planters()
	if planters.is_empty():
		return null

	planters.sort_custom(func(a: PlantableArea, b: PlantableArea) -> bool:
		return a.global_position.x < b.global_position.x
	)

	var leftmost: PlantableArea = planters[0]
	var rightmost: PlantableArea = planters[planters.size() - 1]
	var place_right_side: bool = (planters.size() % 2) == 0
	var base_planter: PlantableArea = rightmost if place_right_side else leftmost
	var direction: float = 1.0 if place_right_side else -1.0
	var candidate: Vector2 = base_planter.global_position + Vector2(direction * planter_adjacent_spacing, 0.0)

	for existing: PlantableArea in planters:
		if existing.global_position.distance_to(candidate) < planter_adjacent_spacing * 0.5:
			return null

	return candidate

func _get_existing_planters() -> Array[PlantableArea]:
	var planters: Array[PlantableArea] = []
	var world_parent: Node = get_parent()
	if world_parent == null:
		return planters

	for child: Node in world_parent.get_children():
		if child is PlantableArea:
			planters.append(child as PlantableArea)

	return planters

func _schedule_navigation_rebuild() -> void:
	if get_tree() == null:
		return

	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return

	var navigation_service: NavigationBuildService = scene_root.get_node_or_null("NavigationBuildService") as NavigationBuildService
	if navigation_service != null:
		navigation_service.schedule_rebuild()

func _ensure_daily_offers() -> void:
	var current_day: int = _get_current_day_number()
	if _offers.is_empty() or _last_offer_day != current_day:
		_reroll_offers(current_day)

func _get_current_day_number() -> int:
	if _day_night_controller != null and is_instance_valid(_day_night_controller):
		if _day_night_controller.is_night_time():
			return maxi(_day_night_controller._night_index + 1, 1)
		return maxi(_day_night_controller._night_index + 1, 1)

	return 1

func _on_day_started(day_number: int) -> void:
	_reroll_offers(maxi(day_number, 1))
	if _is_open:
		_set_status("New day, new upgrades.")
		_refresh_shop_ui()

func _reroll_offers(day_number: int = -1) -> void:
	_offers.clear()
	_sold_card_indices.clear()
	if day_number > 0:
		_last_offer_day = day_number
	else:
		_last_offer_day = _get_current_day_number()

	var effect_ids: Array[StringName] = [&"weight_all", &"summon_damage", &"summon_health"]
	effect_ids.shuffle()

	for index: int in range(CARD_COUNT):
		var lootbox_id: StringName = _pick_random_lootbox_id()
		if lootbox_id == StringName():
			continue

		_offers.append(_build_offer(effect_ids[index % effect_ids.size()], lootbox_id, index))

func _pick_random_lootbox_id() -> StringName:
	if LootboxGlobals == null:
		return StringName()
	if LootboxGlobals.lootboxes.is_empty():
		return StringName()

	var lootbox_ids: Array[StringName] = []
	for key in LootboxGlobals.lootboxes.keys():
		lootbox_ids.append(StringName(key))
	if lootbox_ids.is_empty():
		return StringName()

	return lootbox_ids[randi_range(0, lootbox_ids.size() - 1)]

func _build_offer(effect_id: StringName, target_lootbox_id: StringName, card_index: int) -> Dictionary:
	var scaled_cost: int = card_base_cost + (_shop_purchase_count * card_cost_growth_per_purchase) + (card_index * 8)
	var lootbox_name: String = _get_lootbox_display_name(target_lootbox_id)

	match effect_id:
		&"weight_all":
			return {
				"effect_id": effect_id,
				"target_lootbox_id": target_lootbox_id,
				"cost": scaled_cost,
				"title": "%s Odds Boost" % lootbox_name,
				"description": "Increase all %s drop weights by %d%%." % [lootbox_name, int((weight_upgrade_multiplier - 1.0) * 100.0)],
			}
		&"summon_damage":
			return {
				"effect_id": effect_id,
				"target_lootbox_id": target_lootbox_id,
				"cost": scaled_cost + 6,
				"title": "%s Damage Forge" % lootbox_name,
				"description": "Summons from %s deal +%d%% damage." % [lootbox_name, int(summon_damage_bonus * 100.0)],
			}
		&"summon_health":
			return {
				"effect_id": effect_id,
				"target_lootbox_id": target_lootbox_id,
				"cost": scaled_cost + 6,
				"title": "%s Vitality Seal" % lootbox_name,
				"description": "Summons from %s gain +%d%% max health." % [lootbox_name, int(summon_health_bonus * 100.0)],
			}
		_:
			return {
				"effect_id": effect_id,
				"target_lootbox_id": target_lootbox_id,
				"cost": scaled_cost,
				"title": "Unknown Upgrade",
				"description": "No description.",
			}

func _get_lootbox_display_name(lootbox_id: StringName) -> String:
	if LootboxGlobals != null and LootboxGlobals.lootboxes.has(lootbox_id):
		var lootbox: Lootbox = LootboxGlobals.lootboxes[lootbox_id] as Lootbox
		if lootbox != null and not lootbox.name.is_empty():
			return lootbox.name

	return String(lootbox_id).capitalize()

func _apply_offer(offer: Dictionary) -> bool:
	if LootboxGlobals == null:
		return false

	var effect_id: StringName = offer.get("effect_id", StringName()) as StringName
	var target_lootbox_id: StringName = offer.get("target_lootbox_id", StringName()) as StringName
	if target_lootbox_id == StringName():
		return false
	if not LootboxGlobals.lootboxes.has(target_lootbox_id):
		return false

	var target_lootbox: Lootbox = LootboxGlobals.lootboxes[target_lootbox_id] as Lootbox
	if target_lootbox == null:
		return false

	match effect_id:
		&"weight_all":
			var modified_weights: int = 0
			for entry in target_lootbox.lootTable:
				if entry == null:
					continue
				entry.weight = maxf(entry.weight * weight_upgrade_multiplier, 0.01)
				modified_weights += 1
			return modified_weights > 0
		&"summon_damage":
			var modified_damage_entries: int = 0
			for entry in target_lootbox.lootTable:
				if entry == null:
					continue
				if entry.outcome is LootboxOutcomeSpawnSummon:
					var summon_outcome: LootboxOutcomeSpawnSummon = entry.outcome as LootboxOutcomeSpawnSummon
					summon_outcome.damage_multiplier += summon_damage_bonus
					modified_damage_entries += 1
			return modified_damage_entries > 0
		&"summon_health":
			var modified_health_entries: int = 0
			for entry in target_lootbox.lootTable:
				if entry == null:
					continue
				if entry.outcome is LootboxOutcomeSpawnSummon:
					var summon_outcome: LootboxOutcomeSpawnSummon = entry.outcome as LootboxOutcomeSpawnSummon
					summon_outcome.max_health_multiplier += summon_health_bonus
					modified_health_entries += 1
			return modified_health_entries > 0

	return false

func _update_prompt() -> void:
	if _prompt_label == null:
		return

	var is_player_close: bool = PROXIMITY_PROMPT_UTIL.is_any_player_in_fixed_range(self, global_position, interact_range, _spatial_index)
	_prompt_label.visible = is_player_close and not _is_open
	if not _prompt_label.visible:
		return

	_prompt_label.text = "Press %s to browse upgrades" % _action_hint_text

func _schedule_prompt_refresh(initial_delay: float = -1.0) -> void:
	_prompt_refresh_time_left = PROXIMITY_PROMPT_UTIL.schedule_next_refresh(
		prompt_refresh_interval,
		0.05,
		0.3,
		initial_delay
	)
