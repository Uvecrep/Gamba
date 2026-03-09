extends Node2D

var _is_game_over: bool = false

@onready var _house: Node = get_node_or_null("house")
@onready var _enemy_spawner: Node = get_node_or_null("EnemySpawner")
@onready var _game_over_layer: CanvasLayer = get_node_or_null("GameOverLayer") as CanvasLayer
@onready var _restart_button: Button = get_node_or_null("GameOverLayer/GameOverPanel/MarginContainer/VBoxContainer/RestartButton") as Button
@onready var _quit_button: Button = get_node_or_null("GameOverLayer/GameOverPanel/MarginContainer/VBoxContainer/QuitButton") as Button

func _ready() -> void:
	if is_instance_valid(_house) and _house.has_signal("destroyed"):
		_house.connect("destroyed", _on_house_destroyed)

	if is_instance_valid(_restart_button):
		_restart_button.pressed.connect(_on_restart_pressed)
	if is_instance_valid(_quit_button):
		_quit_button.pressed.connect(_on_quit_pressed)

	_set_game_over_visible(false)

func _on_house_destroyed() -> void:
	if _is_game_over:
		return

	_is_game_over = true
	if is_instance_valid(_enemy_spawner) and _enemy_spawner.has_method("stop_spawning"):
		_enemy_spawner.call("stop_spawning")
	_set_game_over_visible(true)
	get_tree().paused = true

func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().quit()

func _set_game_over_visible(should_show: bool) -> void:
	if _game_over_layer == null:
		return

	_game_over_layer.visible = should_show
	if should_show and is_instance_valid(_restart_button):
		_restart_button.grab_focus()
