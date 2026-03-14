extends StaticBody2D

const CombatText = preload("res://scripts/floating_combat_text.gd")

signal destroyed

@export var max_health: float = 500.0

var _current_health: float = 0.0

@onready var _health_bar: ProgressBar = get_node_or_null("HealthBar") as ProgressBar

func _ready() -> void:
	add_to_group("house")
	_current_health = max_health
	_update_health_bar()

func take_damage(amount: float) -> void:
	if amount <= 0.0:
		return
	if _current_health <= 0.0:
		return

	var previous_health: float = _current_health
	_current_health = clampf(_current_health - amount, 0.0, max_health)
	var applied_damage: float = previous_health - _current_health
	if applied_damage > 0.0:
		CombatText.spawn_damage(self, applied_damage)
	_update_health_bar()

	if _current_health <= 0.0:
		destroyed.emit()
		queue_free()

func heal(amount: float) -> void:
	if amount <= 0.0:
		return
	if _current_health <= 0.0:
		return

	var previous_health: float = _current_health
	_current_health = clampf(_current_health + amount, 0.0, max_health)
	var healed_amount: float = _current_health - previous_health
	if healed_amount <= 0.0:
		return

	CombatText.spawn_heal(self, healed_amount)
	_update_health_bar()

func _update_health_bar() -> void:
	if _health_bar == null:
		return

	_health_bar.max_value = max_health
	_health_bar.value = _current_health
	_health_bar.visible = true
