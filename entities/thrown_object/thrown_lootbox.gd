extends ThrownObject
class_name ThrownLootbox

signal roll_visual_spawned(winning_entry: LootEntry)
signal lootbox_roll_finished(winning_entry: LootEntry, outcome_applied: bool)

const LOOTBOX_ROLL_OVERLAY_SCENE: PackedScene = preload("res://ui/lootbox_roll/lootbox_roll_overlay.tscn")

@export var roll_visual_screen_offset: Vector2 = Vector2(0.0, -84.0)

var lootbox : Lootbox
var player : Player
var _winning_entry: LootEntry
var _winning_reward_data: Resource
var _roll_started: bool = false

func _ready() -> void:
	if lootbox == null:
		return
	var item_id := StringName("lootbox_" + lootbox.id)
	if ItemGlobals.items.has(item_id):
		var rect := get_node_or_null("TextureRect") as TextureRect
		if rect != null:
			rect.texture = ItemGlobals.items[item_id].texture

func on_landed() -> void:
	if _roll_started:
		return
	_roll_started = true

	_winning_entry = _preselect_winning_entry()
	if _winning_entry == null:
		queue_free()
		return
	_winning_reward_data = _winning_entry.get_reward_data_with_quality_roll()

	var overlay: Node = _get_or_create_roll_overlay()
	if overlay == null:
		var fallback_applied: bool = _apply_winning_entry(_winning_entry)
		lootbox_roll_finished.emit(_winning_entry, fallback_applied)
		queue_free()
		return

	var visual: Control = overlay.call("spawn_roll_visual", self, lootbox, _winning_entry, _winning_reward_data, roll_visual_screen_offset) as Control
	if visual == null:
		var no_visual_applied: bool = _apply_winning_entry(_winning_entry)
		lootbox_roll_finished.emit(_winning_entry, no_visual_applied)
		queue_free()
		return

	roll_visual_spawned.emit(_winning_entry)
	var finished_callable: Callable = Callable(self, "_on_roll_visual_finished")
	if not visual.is_connected("roll_finished", finished_callable):
		visual.connect("roll_finished", finished_callable, CONNECT_ONE_SHOT)


func _preselect_winning_entry() -> LootEntry:
	if lootbox == null:
		push_warning("ThrownLootbox: lootbox resource was null on land.")
		return null

	return lootbox.roll()


func _on_roll_visual_finished(_entry: LootEntry, reward_data: Resource) -> void:
	if reward_data != null:
		_winning_reward_data = reward_data
	var applied: bool = _apply_winning_entry(_winning_entry)
	lootbox_roll_finished.emit(_winning_entry, applied)
	queue_free()


func _apply_winning_entry(entry: LootEntry) -> bool:
	if entry == null:
		push_warning("ThrownLootbox: lootbox returned no LootEntry.")
		return false
	if entry.outcome == null:
		push_warning("ThrownLootbox: rolled LootEntry has no outcome.")
		return false

	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		current_scene = get_parent()

	var context: Dictionary = {
		"opener": self,
		"player": player if is_instance_valid(player) else null,
		"current_scene": current_scene,
		"lootbox_id": lootbox.id if lootbox != null else StringName(),
		"reward_data": _winning_reward_data,
	}

	return bool(entry.outcome.execute(context))


func _get_or_create_roll_overlay() -> Node:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		scene_root = get_tree().root
	if scene_root == null:
		return null

	var existing_overlay: Node = scene_root.get_node_or_null("LootboxRollOverlay")
	if existing_overlay != null:
		return existing_overlay

	if LOOTBOX_ROLL_OVERLAY_SCENE == null:
		return null

	var overlay_instance: Node = LOOTBOX_ROLL_OVERLAY_SCENE.instantiate()
	if overlay_instance == null:
		push_warning("ThrownLootbox: Failed to instantiate LootboxRollOverlay scene.")
		return null

	overlay_instance.name = "LootboxRollOverlay"
	scene_root.add_child(overlay_instance)
	return overlay_instance
