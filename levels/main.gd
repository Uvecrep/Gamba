extends Node2D
class_name MainScene

# Navigation config — serialized here for scene backwards-compat; passed to NavigationBuildService.
@export var navigation_obstacle_padding: float = 10.0
@export var navigation_rebuild_delay_seconds: float = 0.15
@export var navigation_block_full_collision_cells: bool = true
@export var navigation_grid_clearance_pixels: float = 18.0
@export var navigation_use_tile_grid_builder: bool = true
@export var navigation_grid_merge_walkable_rectangles: bool = false
@export var navigation_rebuild_on_tree_changes: bool = false
@export_group("Day/Night Cycle")
@export var enable_day_night_cycle: bool = true
@export var day_duration_seconds: float = 60.0
@export var night_duration_seconds: float = 36.0
@export var first_night_starts_immediately: bool = false
@export var night_waves_per_cycle: int = 3
@export var night_wave_base_size: int = 6
@export var night_wave_size_growth_per_night: int = 2
@export var night_wave_spacing_seconds: float = 10.0
@export_group("Day/Night Visuals")
@export var day_night_transition_seconds: float = 1.8
@export var day_overlay_color: Color = Color(0.06, 0.09, 0.15, 0.0)
@export var night_overlay_color: Color = Color(0.06, 0.09, 0.15, 0.48)
@export var day_label_color: Color = Color(0.94, 0.96, 1.0, 1.0)
@export var night_label_color: Color = Color(0.65, 0.78, 1.0, 1.0)

@onready var _house: Node = get_node_or_null("house")
@onready var _enemy_spawner: EnemySpawner = get_node_or_null("EnemySpawner") as EnemySpawner
@onready var _game_over_layer: CanvasLayer = get_node_or_null("GameOverLayer") as CanvasLayer
@onready var _restart_button: Button = get_node_or_null("GameOverLayer/GameOverPanel/MarginContainer/VBoxContainer/RestartButton") as Button
@onready var _quit_button: Button = get_node_or_null("GameOverLayer/GameOverPanel/MarginContainer/VBoxContainer/QuitButton") as Button
@onready var _day_night_label: Label = get_node_or_null("UI/DayNightLabel") as Label
@onready var _day_night_overlay: ColorRect = get_node_or_null("UI/DayNightOverlay") as ColorRect

var _day_night_controller: DayNightController
var _nav_build_service: NavigationBuildService
var _game_over_controller: GameOverController


func _ready() -> void:
	add_to_group("day_night_cycle_controllers")

	_nav_build_service = NavigationBuildService.new()
	_nav_build_service.name = "NavigationBuildService"
	_nav_build_service.obstacle_padding = navigation_obstacle_padding
	_nav_build_service.rebuild_delay_seconds = navigation_rebuild_delay_seconds
	_nav_build_service.block_full_collision_cells = navigation_block_full_collision_cells
	_nav_build_service.grid_clearance_pixels = navigation_grid_clearance_pixels
	_nav_build_service.use_tile_grid_builder = navigation_use_tile_grid_builder
	_nav_build_service.grid_merge_walkable_rectangles = navigation_grid_merge_walkable_rectangles
	_nav_build_service.rebuild_on_tree_changes = navigation_rebuild_on_tree_changes
	add_child(_nav_build_service)

	_day_night_controller = DayNightController.new()
	_day_night_controller.name = "DayNightController"
	_day_night_controller.enable_day_night_cycle = enable_day_night_cycle
	_day_night_controller.day_duration_seconds = day_duration_seconds
	_day_night_controller.night_duration_seconds = night_duration_seconds
	_day_night_controller.first_night_starts_immediately = first_night_starts_immediately
	_day_night_controller.night_waves_per_cycle = night_waves_per_cycle
	_day_night_controller.night_wave_base_size = night_wave_base_size
	_day_night_controller.night_wave_size_growth_per_night = night_wave_size_growth_per_night
	_day_night_controller.night_wave_spacing_seconds = night_wave_spacing_seconds
	_day_night_controller.day_night_transition_seconds = day_night_transition_seconds
	_day_night_controller.day_overlay_color = day_overlay_color
	_day_night_controller.night_overlay_color = night_overlay_color
	_day_night_controller.day_label_color = day_label_color
	_day_night_controller.night_label_color = night_label_color
	_day_night_controller.setup(_enemy_spawner, _day_night_label, _day_night_overlay)
	add_child(_day_night_controller)
	_day_night_controller.initialize()

	_game_over_controller = GameOverController.new()
	_game_over_controller.name = "GameOverController"
	_game_over_controller.setup(_enemy_spawner, _game_over_layer, _restart_button, _quit_button)
	_game_over_controller.set_day_night_controller(_day_night_controller)
	add_child(_game_over_controller)

	if is_instance_valid(_house) and _house.has_signal("destroyed"):
		_house.connect("destroyed", _game_over_controller.on_house_destroyed)


func _exit_tree() -> void:
	pass


func is_night_time() -> bool:
	if _day_night_controller == null:
		return false
	return _day_night_controller.is_night_time()
