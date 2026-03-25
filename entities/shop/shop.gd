extends StaticBody2D
class_name ShopInteractable

const INPUT_HINT_UTIL: GDScript = preload("res://scripts/input_hint.gd")
const PROXIMITY_PROMPT_UTIL: GDScript = preload("res://scripts/proximity_prompt_util.gd")

const CARD_COUNT: int = 3
const GREED_LOOTBOX_ITEM_ID: StringName = &"lootbox_greed"

@export var interact_action: StringName = &"interact"
@export var interact_range: float = 96.0
@export var prompt_refresh_interval: float = 0.2
@export var greed_lootbox_cost: int = 20
@export var card_base_cost: int = 25
@export var card_cost_growth_per_purchase: int = 12
@export var weight_upgrade_multiplier: float = 1.18
@export var summon_damage_bonus: float = 0.18
@export var summon_health_bonus: float = 0.22

var _action_hint_text: String = "E"
var _is_open: bool = false
var _prompt_refresh_time_left: float = 0.0
var _spatial_index: SpatialIndex2D
var _current_player: Player
var _shop_purchase_count: int = 0
var _offers: Array[Dictionary] = []
var _last_offer_day: int = -1
var _day_night_controller: DayNightController

@onready var _prompt_label: Label = get_node_or_null("InteractPrompt") as Label
@onready var _shop_layer: CanvasLayer = get_node_or_null("ShopLayer") as CanvasLayer
@onready var _shop_panel: PanelContainer = get_node_or_null("ShopLayer/ShopWindow") as PanelContainer
@onready var _gold_label: Label = get_node_or_null("ShopLayer/ShopWindow/MarginContainer/VBoxContainer/GoldLabel") as Label
@onready var _status_label: Label = get_node_or_null("ShopLayer/ShopWindow/MarginContainer/VBoxContainer/StatusLabel") as Label
@onready var _close_hint_label: Label = get_node_or_null("ShopLayer/ShopWindow/MarginContainer/VBoxContainer/CloseHint") as Label
@onready var _close_button: Button = get_node_or_null("ShopLayer/ShopWindow/MarginContainer/VBoxContainer/CloseButton") as Button
@onready var _greed_button: Button = get_node_or_null("ShopLayer/ShopWindow/MarginContainer/VBoxContainer/GreedRow/BuyGreedButton") as Button
@onready var _greed_cost_label: Label = get_node_or_null("ShopLayer/ShopWindow/MarginContainer/VBoxContainer/GreedRow/GreedCostLabel") as Label

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
	add_to_group("shops")
	_action_hint_text = INPUT_HINT_UTIL.resolve_action_hint(interact_action)
	_spatial_index = get_node_or_null("/root/SpatialIndex") as SpatialIndex2D

	for index: int in range(_card_buy_buttons.size()):
		var button: Button = _card_buy_buttons[index]
		if button != null:
			button.pressed.connect(_on_buy_card_pressed.bind(index))

	if _greed_button != null:
		_greed_button.pressed.connect(_on_buy_greed_pressed)
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
	_set_status("Choose an upgrade card or buy a Greed lootbox.")
	_set_shop_open(true)
	_refresh_shop_ui()

func _set_shop_open(should_open: bool) -> void:
	_is_open = should_open
	if _shop_layer != null:
		_shop_layer.visible = should_open
	if _shop_panel != null:
		_shop_panel.visible = should_open
	if _close_hint_label != null:
		_close_hint_label.text = "Press %s to close shop" % _action_hint_text
	if should_open and _card_buy_buttons.size() > 0 and _card_buy_buttons[0] != null:
		_card_buy_buttons[0].grab_focus()

func _on_buy_card_pressed(card_index: int) -> void:
	if card_index < 0 or card_index >= _offers.size():
		return
	if _current_player == null:
		_set_status("No player selected for this shop session.")
		return

	var offer: Dictionary = _offers[card_index]
	var card_cost: int = int(offer.get("cost", 0))
	if not _try_spend_gold(card_cost):
		_set_status("Not enough gold for that upgrade.")
		_refresh_shop_ui()
		return

	if not _apply_offer(offer):
		_refund_gold(card_cost)
		_set_status("Upgrade failed. Your gold was refunded.")
		_refresh_shop_ui()
		return

	_shop_purchase_count += 1
	_set_status("Purchased: %s" % String(offer.get("title", "Upgrade")))
	_refresh_shop_ui()

func _on_buy_greed_pressed() -> void:
	if _current_player == null:
		_set_status("No player selected for this shop session.")
		return
	if not _try_spend_gold(greed_lootbox_cost):
		_set_status("Not enough gold for a Greed lootbox.")
		_refresh_shop_ui()
		return
	if not _current_player.player_inventory.add_items(GREED_LOOTBOX_ITEM_ID, 1):
		_refund_gold(greed_lootbox_cost)
		_set_status("Inventory full. Could not add a Greed lootbox.")
		_refresh_shop_ui()
		return

	_set_status("Purchased 1 Greed lootbox.")
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
				_card_cost_labels[index].text = "Cost: %d gold" % int(offer.get("cost", 0))
			else:
				_card_cost_labels[index].text = ""

		if index < _card_buy_buttons.size() and _card_buy_buttons[index] != null:
			if has_offer:
				var can_afford: bool = _can_afford(int(offer.get("cost", 0)))
				_card_buy_buttons[index].disabled = not can_afford
				_card_buy_buttons[index].text = "Buy"
			else:
				_card_buy_buttons[index].disabled = true
				_card_buy_buttons[index].text = "Unavailable"

	if _greed_button != null:
		_greed_button.disabled = not _can_afford(greed_lootbox_cost)

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
