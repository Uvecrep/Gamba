extends RefCounted

const HealthComponent = preload("res://entities/shared/health_component.gd")

var unit
var _health_component: HealthComponent = HealthComponent.new()
var _is_initialized: bool = false

func _init(owner) -> void:
	unit = owner

func initialize_health(start_full: bool = true) -> void:
	_health_component.initialize(unit.max_health, start_full)
	_is_initialized = true
	_sync_health_to_unit()

func take_hit(amount: float, source: Node2D = null, options: Dictionary = {}) -> void:
	_ensure_health_initialized()
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
	_ensure_health_initialized()
	if amount <= 0.0:
		return

	_sync_health_max_from_unit_export()
	var applied_damage: float = _health_component.take_damage(amount)
	_sync_health_to_unit()
	if applied_damage > 0.0:
		unit.CombatText.spawn_damage(unit, applied_damage)
		request_health_bar_visibility()
	update_health_bar()

	if _health_component.is_dead:
		die()

func heal(amount: float) -> void:
	_ensure_health_initialized()
	if amount <= 0.0:
		return
	if _health_component.is_dead:
		return

	_sync_health_max_from_unit_export()
	var healed_amount: float = _health_component.heal(amount)
	_sync_health_to_unit()
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

		if split_summon is SummonUnit:
			(split_summon as SummonUnit).set_summon_identity(unit.ID_SLIME)
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
		if split_summon is SummonUnit:
			(split_summon as SummonUnit).set_hold_position(true)

func update_health_bar() -> void:
	_ensure_health_initialized()
	if unit._health_bar == null:
		return

	unit._health_bar.max_value = _health_component.max_health
	unit._health_bar.value = _health_component.current_health
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
	_ensure_health_initialized()
	if unit._health_bar == null:
		return

	var should_show: bool = unit.always_show_health_bar or unit._is_command_selected or unit._health_bar_visible_time_left > 0.0
	if _health_component.is_dead:
		should_show = false
	unit._health_bar.visible = should_show

func _ensure_health_initialized() -> void:
	if _is_initialized:
		return

	var initial_health: float = unit._current_health
	if initial_health <= 0.0:
		initial_health = unit.max_health
	_health_component.initialize(unit.max_health, false, initial_health)
	_is_initialized = true
	_sync_health_to_unit()

func _sync_health_max_from_unit_export() -> void:
	_health_component.set_max_health(unit.max_health)

func _sync_health_to_unit() -> void:
	unit._current_health = _health_component.current_health
