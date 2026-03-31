extends Control


@export var lootbox_name_label : Label
@export var lootbox_description_label : Label
@export var lootbox_entries_count_label : Label
@export var loot_entry_container : Control

@export var loot_entry_ui_item_packed_scene : PackedScene

@onready var inventory_ui : InventoryUi = get_parent().get_node_or_null("Inventory") as InventoryUi

var loaded_item_id : StringName
var loaded_lootbox : Lootbox

func _ready() -> void:
	if inventory_ui != null:
		inventory_ui.hovered_slot_changed.connect(_update_for_hovered_slot)

	_update_for_hovered_slot()


func _update_for_hovered_slot() -> void:
	if inventory_ui == null or inventory_ui.hovered_slot == null:
		loaded_item_id = StringName()
		loaded_lootbox = null
		visible = false
		return

	var mouseover_slot : InventorySlot = inventory_ui.hovered_slot
	var lootbox : Lootbox
	if mouseover_slot.item_id.begins_with("lootbox_"):
		var box_id: StringName = StringName(mouseover_slot.item_id.trim_prefix("lootbox_"))
		if LootboxGlobals.lootboxes.has(box_id):
			lootbox = LootboxGlobals.lootboxes[box_id]
			loaded_item_id = StringName(mouseover_slot.item_id)

	if lootbox == null:
		loaded_item_id = StringName()
		loaded_lootbox = null
		visible = false
		return

	visible = true
	load_lootbox(lootbox)
	position = mouseover_slot.global_position + Vector2(0,-200)


func load_lootbox(new_lootbox : Lootbox) -> void:
	loaded_lootbox = new_lootbox
	update_visuals()

func update_visuals() -> void:
	lootbox_name_label.text = loaded_lootbox.name
	lootbox_description_label.text = _description_for_loaded_lootbox()
	#lootbox_entries_count_label.text = str(loaded_lootbox.lootTable.size())

	#for child in loot_entry_container.get_children():
	#	child.queue_free()
	
	#var roll_percents : Array[float] = []
	#var total_weight : float = 0.0
	#for e in loaded_lootbox.lootTable:
	#	total_weight += e.weight

	#if total_weight <= 0.0:
	#	return
	
	#for i in range(loaded_lootbox.lootTable.size()):
	#	roll_percents.append(loaded_lootbox.lootTable[i].weight / total_weight)

	#for i in range(loaded_lootbox.lootTable.size()):
	#	var new_item : LootEntryUiItem = loot_entry_ui_item_packed_scene.instantiate()
	#	var weight_percent_string : String = "%.1f%%" % (roll_percents[i] * 100.0)
	#	var weight_string : String = "Weight: " + str(loaded_lootbox.lootTable[i].weight) + "(" + weight_percent_string + ")"
	#	new_item.set_info(i,loaded_lootbox.lootTable[i].name,str(weight_string))
	#	loot_entry_container.add_child(new_item)

func _description_for_loaded_lootbox() -> String:
	if loaded_item_id == StringName():
		return "Open this lootbox to discover summons."

	var item_id_text: String = String(loaded_item_id)
	if not item_id_text.begins_with("lootbox_"):
		return "Open this lootbox to discover summons."

	var box_id: StringName = StringName(item_id_text.trim_prefix("lootbox_"))
	match box_id:
		&"chaos":
			return "A volatile cache with aggressive summon rolls and unpredictable outcomes. Base odds shown below; each pull can also roll + or ++ quality."
		&"forest":
			return "A nature-aligned lootbox with grounded summon outcomes from forest progression. Base odds shown below; each pull can also roll + or ++ quality."
		&"elemental":
			return "An arcane lootbox tuned toward elemental-themed summon outcomes. Base odds shown below; each pull can also roll + or ++ quality."
		&"greed":
			return "A high-value lootbox focused on economy-leaning summon rewards. Base odds shown below; each pull can also roll + or ++ quality."
		&"soul":
			return "A mystical lootbox linked to soul-focused progression paths. Base odds shown below; each pull can also roll + or ++ quality."
		_:
			return "Open this lootbox to discover summons. Base odds shown below; each pull can also roll + or ++ quality."
