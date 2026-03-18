extends Control


@export var lootbox_name_label : Label
@export var lootbox_description_label : Label
@export var lootbox_entries_count_label : Label

var loaded_item_id : StringName
var loaded_lootbox : Lootbox

func _process(_delta: float) -> void:
	var mouseover_slot : InventorySlot = get_first_inventoryslot()
	if not mouseover_slot: 
		self.visible = false
		return
	

	var lootbox : Lootbox
	if mouseover_slot.item_id.begins_with("lootbox_"):
		var box_id: StringName = StringName(mouseover_slot.item_id.split("_")[1])
		if not LootboxGlobals.lootboxes.has(box_id):
			return
		lootbox = LootboxGlobals.lootboxes[box_id]
	
	if lootbox == null: return

	self.visible = true

	load_lootbox(lootbox)

	position = mouseover_slot.global_position + Vector2(0,-200)


func load_lootbox(new_lootbox : Lootbox) -> void:
	loaded_lootbox = new_lootbox
	update_visuals()

func update_visuals() -> void:
	lootbox_name_label.text = loaded_lootbox.name
	lootbox_description_label.text = loaded_lootbox.description
	lootbox_entries_count_label.text = str(loaded_lootbox.lootTable.size())

# TODO: Terribly suboptimal code for searching through ALL controls to find the first inventoryslot you hover over
func get_first_inventoryslot() -> InventorySlot:
	var results = get_all_controls_under_mouse()
	for c in results:
		if c.is_in_group("InventorySlot"):
			return c.get_parent() as InventorySlot
	return null

func get_all_controls_under_mouse() -> Array[Control]:
	var results: Array[Control] = []
	var mouse_pos = get_viewport().get_mouse_position()
	
	_collect_controls(get_tree().root, mouse_pos, results)
	return results


func _collect_controls(node: Node, mouse_pos: Vector2, results: Array):
	if node is Control:
		var control := node as Control
		
		if not control.visible:
			return
		
		# Check if mouse is inside this control
		if control.get_global_rect().has_point(mouse_pos):
			results.append(control)
	
	for child in node.get_children():
		_collect_controls(child, mouse_pos, results)
