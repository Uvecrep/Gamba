extends StaticBody2D
class_name House

const CombatText = preload("res://scripts/floating_combat_text.gd")
const HEALTH_COMPONENT_SCRIPT = preload("res://entities/shared/health_component.gd")

signal destroyed

@export var max_health: float = 500.0

var _current_health: float = 0.0
var _health_component: HealthComponent = HEALTH_COMPONENT_SCRIPT.new()

@onready var _health_bar: ProgressBar = get_node_or_null("HealthBar") as ProgressBar

func _ready() -> void:
	add_to_group("house")
	_health_component.initialize(max_health, true)
	_current_health = _health_component.current_health
	_update_health_bar()

func take_damage(amount: float) -> void:
	if amount <= 0.0:
		return
	if _health_component.is_dead:
		return

	_sync_health_max_from_export()
	var applied_damage: float = _health_component.take_damage(amount)
	_current_health = _health_component.current_health
	if applied_damage > 0.0:
		CombatText.spawn_damage(self, applied_damage)
	_update_health_bar()

	if _health_component.is_dead:
		destroyed.emit()
		queue_free()

func heal(amount: float) -> void:
	if amount <= 0.0:
		return
	if _health_component.is_dead:
		return

	_sync_health_max_from_export()
	var healed_amount: float = _health_component.heal(amount)
	_current_health = _health_component.current_health
	if healed_amount <= 0.0:
		return

	CombatText.spawn_heal(self, healed_amount)
	_update_health_bar()

func _update_health_bar() -> void:
	if _health_bar == null:
		return

	_health_bar.max_value = _health_component.max_health
	_health_bar.value = _health_component.current_health
	_health_bar.visible = true

func _sync_health_max_from_export() -> void:
	_health_component.set_max_health(max_health)
