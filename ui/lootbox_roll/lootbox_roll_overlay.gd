extends CanvasLayer
class_name LootboxRollOverlay

@export var roll_visual_scene: PackedScene = preload("res://ui/lootbox_roll/lootbox_roll_visual.tscn")

@onready var _visual_root: Control = $VisualRoot


func spawn_roll_visual(anchor_node: Node2D, source_lootbox: Lootbox, winning_entry: LootEntry, winning_reward_data: Resource = null, screen_offset: Vector2 = Vector2(0.0, -82.0)) -> Control:
	if anchor_node == null or not is_instance_valid(anchor_node):
		return null
	if winning_entry == null:
		return null
	if roll_visual_scene == null:
		push_warning("LootboxRollOverlay: roll_visual_scene is not configured.")
		return null

	var visual: Control = roll_visual_scene.instantiate() as Control
	if visual == null:
		push_warning("LootboxRollOverlay: roll_visual_scene root must inherit Control.")
		return null

	_visual_root.add_child(visual)
	if visual.has_method("begin"):
		visual.call("begin", anchor_node, source_lootbox, winning_entry, winning_reward_data, screen_offset)
	return visual


func active_roll_count() -> int:
	return _visual_root.get_child_count()
