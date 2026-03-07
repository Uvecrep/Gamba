extends StaticBody2D

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

	_current_health = clampf(_current_health - amount, 0.0, max_health)
	_update_health_bar()

	if _current_health <= 0.0:
		queue_free()

func _update_health_bar() -> void:
	if _health_bar == null:
		return

	_health_bar.max_value = max_health
	_health_bar.value = _current_health
	_health_bar.visible = true
