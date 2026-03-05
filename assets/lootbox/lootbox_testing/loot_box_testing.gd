extends Node

@export var LoadResourceLineEdit : LineEdit

@export var LootBoxPathLabel : Label
@export var LootBoxNameLabel : Label
@export var LootBoxColorLabel : Label
@export var LootBoxDescriptionLabel : Label

@export var LoadedLootBox : LootBox

func _ready() -> void:
	LoadResourceLineEdit.text = "res://assets/lootbox/lootbox_testing/example_lootbox.tres"

func load_loot_box_resource(path: String):
	var loaded_resource = ResourceLoader.load(path)
	
	
	if not loaded_resource:
		print("Failed to load resource at path: " + path)
		return
	
	if loaded_resource is not LootBox:
		print("Resource at path is valid, but is not a LootBox: " + path)
		return
	
	LoadedLootBox = loaded_resource
	reload_lookbox_ui()

func reload_lookbox_ui():
	LootBoxPathLabel.text = LoadedLootBox.resource_path
	LootBoxNameLabel.text = LoadedLootBox.name
	LootBoxColorLabel.text = LoadedLootBox.color
	LootBoxDescriptionLabel.text = LoadedLootBox.description

func _on_load_button_pressed() -> void:
	load_loot_box_resource(LoadResourceLineEdit.text)

func _on_line_edit_text_submitted(new_text: String) -> void:
	load_loot_box_resource(new_text)
