class_name GameOverController
extends Node

var _is_game_over: bool = false
var _enemy_spawner: Node = null
var _game_over_layer: CanvasLayer = null
var _restart_button: Button = null
var _quit_button: Button = null
var _day_night_controller: Node = null


func setup(
	enemy_spawner: Node,
	game_over_layer: CanvasLayer,
	restart_button: Button,
	quit_button: Button,
) -> void:
	_enemy_spawner = enemy_spawner
	_game_over_layer = game_over_layer
	_restart_button = restart_button
	_quit_button = quit_button

	if is_instance_valid(_restart_button):
		_restart_button.pressed.connect(_on_restart_pressed)
	if is_instance_valid(_quit_button):
		_quit_button.pressed.connect(_on_quit_pressed)

	_set_visible(false)


func set_day_night_controller(dnc: Node) -> void:
	_day_night_controller = dnc


func on_house_destroyed() -> void:
	if _is_game_over:
		return

	_is_game_over = true

	if is_instance_valid(_enemy_spawner) and _enemy_spawner.has_method("stop_spawning"):
		_enemy_spawner.call("stop_spawning")

	if is_instance_valid(_day_night_controller) and _day_night_controller.has_method("stop"):
		_day_night_controller.stop()

	_set_visible(true)
	get_tree().paused = true


func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().quit()


func _set_visible(should_show: bool) -> void:
	if _game_over_layer == null:
		return

	_game_over_layer.visible = should_show
	if should_show and is_instance_valid(_restart_button):
		_restart_button.grab_focus()
