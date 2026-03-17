extends RefCounted
class_name HealthComponent

var max_health: float = 1.0
var current_health: float = 1.0
var is_dead: bool = false

func initialize(initial_max_health: float, start_full: bool = true, initial_health: float = -1.0) -> void:
	max_health = maxf(initial_max_health, 0.0)
	if start_full:
		current_health = max_health
	else:
		var resolved_health: float = initial_health
		if resolved_health < 0.0:
			resolved_health = max_health
		current_health = clampf(resolved_health, 0.0, max_health)
	is_dead = current_health <= 0.0

func set_max_health(value: float, preserve_ratio: bool = false) -> void:
	var next_max: float = maxf(value, 0.0)
	if is_equal_approx(next_max, max_health):
		return

	if preserve_ratio and max_health > 0.0:
		var ratio: float = clampf(current_health / max_health, 0.0, 1.0)
		max_health = next_max
		current_health = ratio * max_health
	else:
		max_health = next_max
		current_health = clampf(current_health, 0.0, max_health)

	is_dead = current_health <= 0.0

func set_current_health(value: float) -> void:
	current_health = clampf(value, 0.0, max_health)
	is_dead = current_health <= 0.0

func take_damage(amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	if is_dead:
		return 0.0

	var previous_health: float = current_health
	current_health = clampf(current_health - amount, 0.0, max_health)
	var applied_damage: float = previous_health - current_health
	if current_health <= 0.0:
		is_dead = true
	return applied_damage

func heal(amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	if is_dead:
		return 0.0

	var previous_health: float = current_health
	current_health = clampf(current_health + amount, 0.0, max_health)
	return current_health - previous_health

func revive(fill_to_max: bool = true, health_value: float = -1.0) -> void:
	is_dead = false
	if fill_to_max:
		current_health = max_health
		return

	var resolved_health: float = health_value
	if resolved_health < 0.0:
		resolved_health = max_health
	current_health = clampf(resolved_health, 0.0, max_health)
	is_dead = current_health <= 0.0
