extends RefCounted
class_name PlayerMovementComponent

var camera_mouse_offset : Vector2

func get_input(player: Player) -> void:
	var input_direction: Vector2 = Input.get_vector("left", "right", "up", "down")
	player.velocity = input_direction * player.speed

func handle_scroll_and_camera(player: Player) -> void:
	var mouse_scroll_delta: int = 0
	if Input.is_action_just_released(player.scroll_up_action):
		mouse_scroll_delta += 1
	if Input.is_action_just_released(player.scroll_down_action):
		mouse_scroll_delta -= 1

	if mouse_scroll_delta != 0:
		var next_index: int = posmod(player.player_inventory.selected_index + mouse_scroll_delta, player.player_inventory.num_slots)
		player.player_inventory.set_selected_index(next_index)

	if player.camera == null:
		return

	var viewport := player.get_viewport()
	if viewport == null:
		return

	var mouse_pos: Vector2 = viewport.get_mouse_position() - (viewport.get_visible_rect().size * 0.5)
	# Keep current camera behavior while movement/camera code lives outside Player.
	player.camera.position = mouse_pos * 0.1
	#player._clamp_player_to_world_bounds()
