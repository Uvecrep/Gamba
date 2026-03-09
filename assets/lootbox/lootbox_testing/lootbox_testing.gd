extends Node

@export var LoadResourceLineEdit : LineEdit

@export var LootboxPathLabel : Label
@export var LootboxNameLabel : Label
@export var LootboxColorLabel : Label
@export var LootboxDescriptionLabel : Label

@export var RollButton : Button

@export var LoadedLootbox : Lootbox

func _ready() -> void:
	LoadResourceLineEdit.text = "res://assets/Lootbox/Lootbox_testing/example_Lootbox.tres"
	reload_Lootbox_ui()

func load_loot_box_resource(path: String) -> void:
	var loaded_resource: Resource = ResourceLoader.load(path)
	
	if not loaded_resource:
		print("Failed to load resource at path: " + path)
		return
	
	if loaded_resource is not Lootbox:
		print("Resource at path is valid, but is not a Lootbox: " + path)
		return
	
	LoadedLootbox = loaded_resource

func reload_Lootbox_ui() -> void:
	LootboxPathLabel.text = LoadedLootbox.resource_path if LoadedLootbox != null else "none"
	LootboxNameLabel.text = LoadedLootbox.name if LoadedLootbox != null else "none"
	LootboxColorLabel.text = LoadedLootbox.color if LoadedLootbox != null else "none"
	LootboxDescriptionLabel.text = LoadedLootbox.description if LoadedLootbox != null else "none"
	RollButton.disabled = LoadedLootbox == null

func _on_load_button_pressed() -> void:
	load_loot_box_resource(LoadResourceLineEdit.text)
	reload_Lootbox_ui()

func _on_line_edit_text_submitted(new_text: String) -> void:
	load_loot_box_resource(new_text)
	reload_Lootbox_ui()

func _on_roll_button_pressed() -> void:
	LoadedLootbox.roll().outcome.execute()
