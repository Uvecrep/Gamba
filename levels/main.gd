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
@export var use_balance_day_night_defaults: bool = true
@export var enable_day_night_cycle: bool = true
@export var day_duration_seconds: float = 60.0
@export var night_duration_seconds: float = 36.0
@export var first_night_starts_immediately: bool = false
@export var night_waves_per_cycle: int = 3
@export var night_wave_base_size: int = 6
@export var night_wave_size_growth_per_night: int = 2
@export var night_wave_spawn_scale: float = 0.9
@export var night_wave_spacing_seconds: float = 10.0
@export_group("Day/Night Visuals")
@export var day_night_transition_seconds: float = 1.8
@export var day_overlay_color: Color = Color(0.06, 0.09, 0.15, 0.0)
@export var night_overlay_color: Color = Color(0.06, 0.09, 0.15, 0.48)
@export var day_label_color: Color = Color(0.94, 0.96, 1.0, 1.0)
@export var night_label_color: Color = Color(0.65, 0.78, 1.0, 1.0)
@export_group("Ground Tile Variation")
@export var randomize_ground_tile_variations_on_ready: bool = true

@onready var _house: Node = get_node_or_null("house")
@onready var _enemy_spawner: EnemySpawner = get_node_or_null("EnemySpawner") as EnemySpawner
@onready var _game_over_layer: CanvasLayer = get_node_or_null("GameOverLayer") as CanvasLayer
@onready var _restart_button: Button = get_node_or_null("GameOverLayer/GameOverPanel/MarginContainer/VBoxContainer/RestartButton") as Button
@onready var _quit_to_menu_button: Button = get_node_or_null("GameOverLayer/GameOverPanel/MarginContainer/VBoxContainer/QuitToMenuButton") as Button
@onready var _quit_button: Button = get_node_or_null("GameOverLayer/GameOverPanel/MarginContainer/VBoxContainer/QuitButton") as Button
@onready var _day_night_label: Label = get_node_or_null("UI/DayNightLabel") as Label
@onready var _day_night_overlay: ColorRect = get_node_or_null("UI/DayNightOverlay") as ColorRect

var _day_night_controller: DayNightController
var _nav_build_service: NavigationBuildService
var _game_over_controller: GameOverController


func _ready() -> void:
	add_to_group("day_night_cycle_controllers")
	if randomize_ground_tile_variations_on_ready:
		_randomize_ground_tile_variations()

	var resolved_enable_day_night_cycle: bool = enable_day_night_cycle
	var resolved_day_duration_seconds: float = day_duration_seconds
	var resolved_night_duration_seconds: float = night_duration_seconds
	var resolved_first_night_starts_immediately: bool = first_night_starts_immediately
	var resolved_night_waves_per_cycle: int = night_waves_per_cycle
	var resolved_night_wave_base_size: int = night_wave_base_size
	var resolved_night_wave_size_growth_per_night: int = night_wave_size_growth_per_night
	var resolved_night_wave_spawn_scale: float = night_wave_spawn_scale
	var resolved_night_wave_spacing_seconds: float = night_wave_spacing_seconds

	if use_balance_day_night_defaults:
		resolved_enable_day_night_cycle = bool(Balance.get_day_night_setting(&"enable_day_night_cycle", resolved_enable_day_night_cycle))
		resolved_day_duration_seconds = float(Balance.get_day_night_setting(&"day_duration_seconds", resolved_day_duration_seconds))
		resolved_night_duration_seconds = float(Balance.get_day_night_setting(&"night_duration_seconds", resolved_night_duration_seconds))
		resolved_first_night_starts_immediately = bool(Balance.get_day_night_setting(&"first_night_starts_immediately", resolved_first_night_starts_immediately))
		resolved_night_waves_per_cycle = int(Balance.get_day_night_setting(&"night_waves_per_cycle", resolved_night_waves_per_cycle))
		resolved_night_wave_base_size = int(Balance.get_day_night_setting(&"night_wave_base_size", resolved_night_wave_base_size))
		resolved_night_wave_size_growth_per_night = int(Balance.get_day_night_setting(&"night_wave_size_growth_per_night", resolved_night_wave_size_growth_per_night))
		resolved_night_wave_spawn_scale = float(Balance.get_day_night_setting(&"night_wave_spawn_scale", resolved_night_wave_spawn_scale))
		resolved_night_wave_spacing_seconds = float(Balance.get_day_night_setting(&"night_wave_spacing_seconds", resolved_night_wave_spacing_seconds))

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
	_day_night_controller.enable_day_night_cycle = resolved_enable_day_night_cycle
	_day_night_controller.day_duration_seconds = resolved_day_duration_seconds
	_day_night_controller.night_duration_seconds = resolved_night_duration_seconds
	_day_night_controller.first_night_starts_immediately = resolved_first_night_starts_immediately
	_day_night_controller.night_waves_per_cycle = resolved_night_waves_per_cycle
	_day_night_controller.night_wave_base_size = resolved_night_wave_base_size
	_day_night_controller.night_wave_size_growth_per_night = resolved_night_wave_size_growth_per_night
	_day_night_controller.night_wave_spawn_scale = resolved_night_wave_spawn_scale
	_day_night_controller.night_wave_spacing_seconds = resolved_night_wave_spacing_seconds
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
	_game_over_controller.setup(_enemy_spawner, _game_over_layer, _restart_button, _quit_to_menu_button, _quit_button)
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


func _randomize_ground_tile_variations() -> void:
	var tile_map_ground: TileMapLayer = get_node_or_null("World/TileMapGround") as TileMapLayer
	if tile_map_ground == null:
		push_warning("MainScene: TileMapGround was not found; skipping tile variation randomization.")
		return

	var grass_primary: Vector2i = Vector2i(1, 1)
	var grass_candidates: Array[Vector2i] = [
		Vector2i(1, 1),
		Vector2i(3, 4),
		Vector2i(4, 4),
		Vector2i(5, 4),
	]
	var dirt_primary: Vector2i = Vector2i(4, 1)
	var dirt_candidates: Array[Vector2i] = [
		Vector2i(4, 1),
		Vector2i(3, 3),
		Vector2i(4, 3),
		Vector2i(5, 3),
	]

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()

	for cell_coords in tile_map_ground.get_used_cells():
		var source_id: int = tile_map_ground.get_cell_source_id(cell_coords)
		if source_id == -1:
			continue

		var atlas_coords: Vector2i = tile_map_ground.get_cell_atlas_coords(cell_coords)
		var candidates: Array[Vector2i] = []
		if atlas_coords == grass_primary:
			candidates = grass_candidates
		elif atlas_coords == dirt_primary:
			candidates = dirt_candidates

		if candidates.is_empty():
			continue

		var new_atlas_coords: Vector2i = candidates[rng.randi_range(0, candidates.size() - 1)]
		tile_map_ground.set_cell(cell_coords, source_id, new_atlas_coords, 0)
