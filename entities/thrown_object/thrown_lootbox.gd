extends ThrownObject
class_name ThrownLootbox

@export var rolled_item_label_debug : Label

@export var hightlight_label_settings : LabelSettings

var lootbox : Lootbox
var player : Player

# Meant to be overridden with whatever should happen when the object hits the ground
func on_landed():
	var rolled_entry: LootEntry = lootbox.roll()
	var rolled_entry_index : int = lootbox.lootTable.find(rolled_entry)
	print("rolled entry index: " + str(rolled_entry_index))

	var cheat_ticks = cheat(2)
	print("cheat ticks: " + str(cheat_ticks))
	var starting_index = posmod(rolled_entry_index - cheat(2),lootbox.lootTable.size())

	print("starting index: " + str(starting_index))
	var chosen_index = await spin_the_wheel(starting_index, 2)
	print("chosen index:" + str(chosen_index))
	open_lootbox_at_index(chosen_index)
	queue_free()

# Given input parameters, gives the number of ticks the wheel will cycle through.
# This allows me to predetermine the outcome of the roll (since it need to be weighted) Teehee!
func cheat(spin_duration : float) -> int:
	var num_ticks : int = 0
	var elapsed : float = 0

	while elapsed < spin_duration:
		var delay = lerp(0.05, 0.3, elapsed/spin_duration)
		elapsed += delay
		num_ticks += 1
	
	return num_ticks	

func spin_the_wheel(starting_index : int, spin_duration : float) -> int:
	rolled_item_label_debug.visible = true
	var elapsed := 0.0
	var index = starting_index

	while elapsed < spin_duration:
		rolled_item_label_debug.text = lootbox.lootTable[index].name

		var delay = lerp(0.05, 0.3, elapsed/spin_duration)

		await get_tree().create_timer(delay).timeout

		elapsed += delay

		index = (index + 1) % lootbox.lootTable.size()
	
	rolled_item_label_debug.text = lootbox.lootTable[index].name
	rolled_item_label_debug.label_settings = hightlight_label_settings
	await get_tree().create_timer(.3).timeout

	return index

func open_lootbox_at_index(index : int) -> bool:
	var rolled_entry: LootEntry = lootbox.lootTable[index]
	print("rolled entry name: " + rolled_entry.name)
	if rolled_entry == null:
		push_warning("Player: lootbox returned no LootEntry.")
		return false
	if rolled_entry.outcome == null:
		push_warning("Player: rolled LootEntry has no outcome.")
		return false

	var context: Dictionary = {
		"opener": self,
		"player": player,
		"current_scene": player.get_tree().current_scene,
	}

	return bool(rolled_entry.outcome.execute(context))
