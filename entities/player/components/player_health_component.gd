extends RefCounted
class_name PlayerHealthComponent

const CombatText = preload("res://scripts/floating_combat_text.gd")
const HEALTH_COMPONENT_SCRIPT = preload("res://entities/shared/health_component.gd")
const DEATH_INDICATOR_COLOR: Color = Color(1.0, 0.42, 0.42, 1.0)

var _spawn_position: Vector2 = Vector2.ZERO
var _is_dead: bool = false
var _invulnerability_time_left: float = 0.0
var _house_regen_time_left: float = 0.0
var _hit_shield_stacks: int = 0
var _death_indicator_layer: CanvasLayer
var _death_indicator_label: Label
var _health_state: HealthComponent = HEALTH_COMPONENT_SCRIPT.new()
const MAX_HIT_SHIELD_STACKS: int = 1

func initialize(player: Player) -> void:
	_spawn_position = player.global_position
	_health_state.initialize(player.max_health, true)
	_sync_player_health(player)
	setup_death_indicator(player)
	update_health_bar(player)

func process(player: Player, delta: float) -> void:
	_sync_with_player_max_health(player)
	if _invulnerability_time_left > 0.0:
		_invulnerability_time_left = maxf(_invulnerability_time_left - delta, 0.0)
	update_house_regen(player, delta)
	update_health_bar(player)

func is_dead() -> bool:
	return _is_dead

func get_invulnerability_time_left() -> float:
	return _invulnerability_time_left

func take_hit(player: Player, amount: float, _source: Node2D = null, _options: Dictionary = {}) -> void:
	take_damage(player, amount)

func take_damage(player: Player, amount: float) -> void:
	if amount <= 0.0:
		return
	if _is_dead:
		return
	if _invulnerability_time_left > 0.0:
		return
	if _hit_shield_stacks > 0:
		_hit_shield_stacks -= 1
		update_health_bar(player)
		return

	_sync_with_player_max_health(player)
	var applied_damage: float = _health_state.take_damage(amount)
	_sync_player_health(player)
	if applied_damage <= 0.0:
		return

	CombatText.spawn_damage(player, applied_damage)
	update_health_bar(player)

	if _health_state.is_dead:
		begin_respawn_flow(player)

func heal(player: Player, amount: float) -> void:
	if amount <= 0.0:
		return
	if _is_dead:
		return

	_sync_with_player_max_health(player)
	var healed_amount: float = _health_state.heal(amount)
	_sync_player_health(player)
	if healed_amount <= 0.0:
		return

	CombatText.spawn_heal(player, healed_amount)
	update_health_bar(player)

func update_house_regen(player: Player, delta: float) -> void:
	if _is_dead:
		_house_regen_time_left = 0.0
		return
	if player.house_regen_per_second <= 0.0 or player.house_regen_radius <= 0.0:
		_house_regen_time_left = 0.0
		return
	if _health_state.current_health >= _health_state.max_health:
		_house_regen_time_left = 0.0
		return

	var nearest_house: Node2D = find_nearest_house_anywhere(player)
	if nearest_house == null:
		_house_regen_time_left = 0.0
		return

	var regen_radius_sq: float = player.house_regen_radius * player.house_regen_radius
	if player.global_position.distance_squared_to(nearest_house.global_position) > regen_radius_sq:
		_house_regen_time_left = 0.0
		return

	_house_regen_time_left = maxf(_house_regen_time_left - delta, 0.0)
	if _house_regen_time_left > 0.0:
		return

	var tick_interval: float = maxf(player.house_regen_tick_interval, 0.1)
	_house_regen_time_left = tick_interval
	heal(player, player.house_regen_per_second * tick_interval)

func begin_respawn_flow(player: Player) -> void:
	if _is_dead:
		return

	_is_dead = true
	player.velocity = Vector2.ZERO
	player._reset_middle_mouse_selection_state()
	show_death_indicator(player)
	run_respawn_timer(player)

func run_respawn_timer(player: Player) -> void:
	var wait_time: float = maxf(player.respawn_delay_seconds, 0.25)
	await player.get_tree().create_timer(wait_time).timeout
	if not player.is_inside_tree():
		return

	respawn_player(player)

func respawn_player(player: Player) -> void:
	player.global_position = get_respawn_position(player)
	#player._clamp_player_to_world_bounds()
	_sync_with_player_max_health(player)
	_health_state.revive(true)
	_sync_player_health(player)
	_is_dead = false
	_hit_shield_stacks = 0
	_invulnerability_time_left = maxf(player.respawn_invulnerability_seconds, 0.0)
	hide_death_indicator()
	update_health_bar(player)

func grant_hit_shield(player: Player) -> bool:
	if _is_dead:
		return false
	if _hit_shield_stacks >= MAX_HIT_SHIELD_STACKS:
		return false

	_hit_shield_stacks += 1
	update_health_bar(player)
	return true

func has_hit_shield() -> bool:
	return _hit_shield_stacks > 0

func get_respawn_position(player: Player) -> Vector2:
	var nearest_house: Node2D = find_nearest_house_anywhere(player)
	if nearest_house == null:
		return _spawn_position

	var from_house: Vector2 = player.global_position - nearest_house.global_position
	if from_house == Vector2.ZERO:
		from_house = Vector2.DOWN

	return nearest_house.global_position + (from_house.normalized() * maxf(player.respawn_distance_from_house, 48.0))

func find_nearest_house_anywhere(player: Player) -> Node2D:
	var nearest_house: Node2D
	var nearest_distance_sq: float = INF

	for house in player.get_tree().get_nodes_in_group("house"):
		if not (house is Node2D):
			continue

		var house_node: Node2D = house as Node2D
		var distance_sq: float = player.global_position.distance_squared_to(house_node.global_position)
		if distance_sq >= nearest_distance_sq:
			continue

		nearest_distance_sq = distance_sq
		nearest_house = house_node

	return nearest_house

func setup_death_indicator(player: Player) -> void:
	_death_indicator_layer = CanvasLayer.new()
	_death_indicator_layer.name = "DeathIndicatorLayer"
	_death_indicator_layer.layer = 24
	_death_indicator_layer.visible = false
	player.add_child(_death_indicator_layer)

	_death_indicator_label = Label.new()
	_death_indicator_label.name = "DeathIndicatorLabel"
	_death_indicator_label.anchors_preset = Control.PRESET_CENTER
	_death_indicator_label.anchor_left = 0.5
	_death_indicator_label.anchor_top = 0.5
	_death_indicator_label.anchor_right = 0.5
	_death_indicator_label.anchor_bottom = 0.5
	_death_indicator_label.offset_left = -240.0
	_death_indicator_label.offset_top = -80.0
	_death_indicator_label.offset_right = 240.0
	_death_indicator_label.offset_bottom = 80.0
	_death_indicator_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death_indicator_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_death_indicator_label.text = "YOU DIED"
	_death_indicator_label.add_theme_font_size_override("font_size", 58)
	_death_indicator_label.add_theme_color_override("font_color", DEATH_INDICATOR_COLOR)
	_death_indicator_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_death_indicator_layer.add_child(_death_indicator_label)

func show_death_indicator(player: Player) -> void:
	if _death_indicator_layer == null or _death_indicator_label == null:
		return

	_death_indicator_layer.visible = true
	_death_indicator_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var fade_tween: Tween = player.create_tween()
	fade_tween.tween_property(_death_indicator_label, "modulate:a", 1.0, 0.12)
	fade_tween.tween_interval(maxf(player.respawn_delay_seconds - 0.32, 0.05))
	fade_tween.tween_property(_death_indicator_label, "modulate:a", 0.0, 0.18)

func hide_death_indicator() -> void:
	if _death_indicator_layer == null or _death_indicator_label == null:
		return

	_death_indicator_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_death_indicator_layer.visible = false

func update_health_bar(player: Player) -> void:
	if player.health_bar == null:
		return

	player.health_bar.max_value = _health_state.max_health
	player.health_bar.value = _health_state.current_health
	player.health_bar.visible = true

	if _invulnerability_time_left > 0.0 and not _is_dead:
		var pulse: float = 0.65 + (0.35 * sin(Time.get_ticks_msec() / 90.0))
		player.health_bar.modulate = Color(1.0, 1.0, 1.0, pulse)
	elif _hit_shield_stacks > 0 and not _is_dead:
		var shield_pulse: float = 0.78 + (0.22 * sin(Time.get_ticks_msec() / 110.0))
		player.health_bar.modulate = Color(0.72, 0.92, 1.1, shield_pulse)
	else:
		player.health_bar.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _sync_with_player_max_health(player: Player) -> void:
	_health_state.set_max_health(player.max_health)
	_sync_player_health(player)

func _sync_player_health(player: Player) -> void:
	player.current_health = _health_state.current_health
