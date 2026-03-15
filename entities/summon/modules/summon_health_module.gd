extends RefCounted

var unit

func _init(owner) -> void:
	unit = owner

func take_hit(amount: float, source: Node2D = null, options: Dictionary = {}) -> void:
	var final_damage: float = amount
	if unit.summon_identity == unit.ID_BUSH_BOY and unit._command_mode == unit.CommandMode.HOLD:
		final_damage *= 0.6

	if options.has("damage_multiplier"):
		final_damage *= float(options.get("damage_multiplier", 1.0))

	take_damage(final_damage)

	var knockback_force: float = float(options.get("knockback_force", 0.0))
	if knockback_force > 0.0 and is_instance_valid(source):
		var push_direction: Vector2 = source.global_position.direction_to(unit.global_position)
		if push_direction != Vector2.ZERO:
			unit._external_push_velocity += push_direction * knockback_force

func take_damage(amount: float) -> void:
	if amount <= 0.0:
		return

	var previous_health: float = unit._current_health
	unit._current_health = clampf(unit._current_health - amount, 0.0, unit.max_health)
	var applied_damage: float = previous_health - unit._current_health
	if applied_damage > 0.0:
		unit.CombatText.spawn_damage(unit, applied_damage)
		request_health_bar_visibility()
	update_health_bar()

	if unit._current_health <= 0.0:
		die()

func heal(amount: float) -> void:
	if amount <= 0.0:
		return
	if unit._current_health <= 0.0:
		return

	var previous_health: float = unit._current_health
	unit._current_health = clampf(unit._current_health + amount, 0.0, unit.max_health)
	var healed_amount: float = unit._current_health - previous_health
	if healed_amount <= 0.0:
		return

	unit.CombatText.spawn_heal(unit, healed_amount)
	request_health_bar_visibility(0.75)
	update_health_bar()

func die() -> void:
	if should_split_on_death():
		spawn_split_children()
	unit.queue_free()

func should_split_on_death() -> bool:
	if unit.summon_identity != unit.ID_SLIME:
		return false
	if not unit.split_enabled:
		return false
	if unit.is_mini_slime:
		return false
	if unit._has_split_once:
		return false
	return true

func spawn_split_children() -> void:
	if unit.summon_scene_for_split == null:
		return

	unit._has_split_once = true
	var parent_node: Node = unit.get_tree().current_scene
	if parent_node == null:
		parent_node = unit.get_parent()
	if parent_node == null:
		return

	var split_count: int = maxi(unit.split_child_count, 1)
	for split_index in range(split_count):
		var split_summon := unit.summon_scene_for_split.instantiate() as Node2D
		if split_summon == null:
			continue

		if split_summon.has_method("set_summon_identity"):
			split_summon.call("set_summon_identity", unit.ID_SLIME)
		else:
			split_summon.set("summon_identity", unit.ID_SLIME)

		split_summon.set("is_mini_slime", true)
		split_summon.set("split_enabled", false)
		split_summon.set("max_health", maxf(unit.max_health * unit.split_child_health_scale, 12.0))
		split_summon.set("attack_damage", maxf(unit.attack_damage * unit.split_child_damage_scale, 4.0))
		split_summon.set("move_speed", unit.move_speed * 1.25)
		split_summon.set("sprite_texture_override", unit.sprite_texture_override)

		parent_node.add_child(split_summon)
		split_summon.scale = unit.scale * unit.split_child_scale
		var angle: float = TAU * float(split_index) / float(split_count)
		split_summon.global_position = unit.global_position + Vector2.RIGHT.rotated(angle) * 20.0
		if split_summon.has_method("set_hold_position"):
			split_summon.call("set_hold_position", true)

func update_health_bar() -> void:
	if unit._health_bar == null:
		return

	unit._health_bar.max_value = unit.max_health
	unit._health_bar.value = unit._current_health
	refresh_health_bar_visibility()

func request_health_bar_visibility(duration: float = -1.0) -> void:
	if unit._health_bar == null:
		return

	var resolved_duration: float = duration
	if resolved_duration < 0.0:
		resolved_duration = unit.health_bar_show_duration
	unit._health_bar_visible_time_left = maxf(unit._health_bar_visible_time_left, maxf(resolved_duration, 0.0))
	refresh_health_bar_visibility()

func refresh_health_bar_visibility() -> void:
	if unit._health_bar == null:
		return

	var should_show: bool = unit.always_show_health_bar or unit._is_command_selected or unit._health_bar_visible_time_left > 0.0
	if unit._current_health <= 0.0:
		should_show = false
	unit._health_bar.visible = should_show
