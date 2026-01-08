extends Node2D
class_name MapSystem

## 2D Map System for Space Truck
## Manages procedural station generation and visualization

signal station_clicked(station_name: String)

# Ring configuration
const RING_1_STATION_COUNT = 25
const RING_2_STATION_COUNT = 100
const RING_1_BASE_RADIUS = 800.0
const RING_2_BASE_RADIUS = 1600.0

# Visual settings
const STATION_RADIUS = 8.0
const STATION_COLOR = Color(0.3, 0.7, 1.0)  # Cyan - default
const STATION_BORDER_COLOR = Color(0.5, 0.9, 1.0)
const STATION_BORDER_WIDTH = 2.0
const DOCKED_STATION_COLOR = Color(0.2, 1.0, 0.3)  # Green - current station
const SELECTED_STATION_COLOR = Color(1.0, 0.8, 0.0)  # Yellow - selected destination
const HOVER_STATION_COLOR = Color(1.0, 0.5, 1.0)  # Magenta - mouse hover
const CONTRACT_HOVER_COLOR = Color(1.0, 0.6, 0.0)  # Orange - contract destination hover

# Camera settings
var camera_zoom := Vector2(1.0, 1.0)
var camera_pan_speed := 1.0
var zoom_speed := 0.1
var min_zoom := 0.3
var max_zoom := 3.0

# State
var stations := {}  # Dictionary: station_name -> {position: Vector2, ring: int}
var is_panning := false
var pan_start_position := Vector2.ZERO
var current_station := ""  # Station where ship is docked
var selected_destination := ""  # Selected destination station
var hovered_station := ""  # Station currently under mouse
var contract_hover_destination := ""  # Destination highlighted from contract hover

@onready var camera: Camera2D = $Camera2D
@onready var stations_container: Node2D = $StationsContainer


func _ready() -> void:
	# Don't generate stations here - main_level_2d will either:
	# 1. Load stations from save file, or
	# 2. Call generate_stations() for a new game
	pass


func _process(_delta: float) -> void:
	handle_camera_controls()
	update_hovered_station()


func _draw() -> void:
	# Draw sun/star at center
	draw_circle(Vector2.ZERO, 20.0, Color(1.0, 0.9, 0.3))
	draw_arc(Vector2.ZERO, 22.0, 0, TAU, 32, Color(1.0, 0.8, 0.0), 2.0)

	# Draw all stations
	for station_name in stations:
		var station_data = stations[station_name]
		var pos = station_data.position

		# Determine color based on state (priority order)
		var color = STATION_COLOR
		var radius = STATION_RADIUS

		if station_name == current_station:
			# Docked station - green and larger (highest priority)
			color = DOCKED_STATION_COLOR
			radius = STATION_RADIUS * 1.5
		elif station_name == selected_destination:
			# Selected destination - yellow and larger
			color = SELECTED_STATION_COLOR
			radius = STATION_RADIUS * 1.3
		elif station_name == contract_hover_destination:
			# Contract hover destination - orange
			color = CONTRACT_HOVER_COLOR
			radius = STATION_RADIUS * 1.2
		elif station_name == hovered_station:
			# Hovered station - magenta
			color = HOVER_STATION_COLOR
			radius = STATION_RADIUS * 1.2

		# Draw station circle
		draw_circle(pos, radius, color)
		draw_arc(pos, radius, 0, TAU, 16, STATION_BORDER_COLOR, STATION_BORDER_WIDTH)

		# Draw station name (only for Ring 1 stations to reduce clutter)
		if station_data.ring == 1:
			var font = ThemeDB.fallback_font
			var font_size = 14
			var text_size = font.get_string_size(station_name, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			var text_pos = pos + Vector2(-text_size.x / 2, -radius - 5)
			draw_string(font, text_pos, station_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


func generate_stations() -> void:
	"""Generate procedurally placed stations in rings"""
	stations.clear()

	# Generate Ring 1 (inner)
	var ring_1_stations = generate_ring(1, RING_1_STATION_COUNT, RING_1_BASE_RADIUS)
	for station in ring_1_stations:
		stations[station.name] = station

	# Generate Ring 2 (outer)
	var ring_2_stations = generate_ring(2, RING_2_STATION_COUNT, RING_2_BASE_RADIUS)
	for station in ring_2_stations:
		stations[station.name] = station

	print("Generated %d stations (%d in Ring 1, %d in Ring 2)" % [
		stations.size(),
		RING_1_STATION_COUNT,
		RING_2_STATION_COUNT
	])


func generate_ring(ring_number: int, station_count: int, base_radius: float) -> Array:
	"""Generate stations for a single ring with organic variance"""
	var ring_stations := []
	var angle_step := TAU / station_count

	# Minimum distance between stations (prevents clumping)
	var min_distance := 80.0

	for i in station_count:
		var position := Vector2.ZERO
		var attempts := 0
		var max_attempts := 100
		var valid_position := false

		# Try to find a valid position with minimum distance from other stations
		while attempts < max_attempts and not valid_position:
			# Add variance to angle (±10°)
			var angle_variance := randf_range(-0.174, 0.174)  # ±10° in radians
			var angle := i * angle_step + angle_variance

			# Add variance to radius (±15%)
			var radius_variance := randf_range(-base_radius * 0.15, base_radius * 0.15)
			var radius := base_radius + radius_variance

			# Calculate position
			position = Vector2(
				cos(angle) * radius,
				sin(angle) * radius
			)

			# Check distance to all existing stations in this ring
			valid_position = true
			for existing_station in ring_stations:
				if position.distance_to(existing_station.position) < min_distance:
					valid_position = false
					break

			attempts += 1

		# If we couldn't find a valid position after max attempts, use the last one anyway
		# (This prevents infinite loops on overcrowded rings)

		# Create station data
		var station_name := generate_station_name(ring_number, i)
		ring_stations.append({
			"name": station_name,
			"position": position,
			"ring": ring_number
		})

	return ring_stations


func generate_station_name(ring: int, index: int) -> String:
	"""Generate simple placeholder station names"""
	const PREFIXES = ["Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta",
					  "Eta", "Theta", "Iota", "Kappa", "Lambda", "Mu",
					  "Nu", "Xi", "Omicron", "Pi", "Rho", "Sigma",
					  "Tau", "Upsilon", "Phi", "Chi", "Psi", "Omega"]

	if ring == 1:
		# Ring 1: Use Greek letter prefixes
		if index < PREFIXES.size():
			return "Station %s" % PREFIXES[index]
		else:
			return "Station %s-%d" % [PREFIXES[index % PREFIXES.size()], index / PREFIXES.size()]
	else:
		# Ring 2+: Use ring number and index
		return "Station R%d-%03d" % [ring, index + 1]


func handle_camera_controls() -> void:
	"""Handle camera panning and zooming"""
	# Mouse wheel zoom
	if Input.is_action_just_released("ui_scroll_up"):
		zoom_camera(zoom_speed)
	elif Input.is_action_just_released("ui_scroll_down"):
		zoom_camera(-zoom_speed)

	# Click and drag panning
	if Input.is_action_just_pressed("ui_click"):
		is_panning = true
		pan_start_position = get_global_mouse_position()
	elif Input.is_action_just_released("ui_click"):
		is_panning = false

	if is_panning:
		var current_mouse_pos = get_global_mouse_position()
		var pan_delta = pan_start_position - current_mouse_pos
		camera.position += pan_delta * camera_pan_speed


func zoom_camera(delta: float) -> void:
	"""Zoom camera in/out"""
	var new_zoom = camera.zoom.x + delta
	new_zoom = clamp(new_zoom, min_zoom, max_zoom)
	camera.zoom = Vector2(new_zoom, new_zoom)


func get_station_position(station_name: String) -> Vector2:
	"""Get the 2D position of a station"""
	if station_name in stations:
		return stations[station_name].position
	return Vector2.ZERO


func get_station_at_position(world_position: Vector2, tolerance: float = STATION_RADIUS * 2) -> String:
	"""Get the station name at a given world position (for clicking)"""
	for station_name in stations:
		var station_pos = stations[station_name].position
		if world_position.distance_to(station_pos) <= tolerance:
			return station_name
	return ""


func get_random_ring1_station() -> String:
	"""Get a random station from Ring 1 for spawning"""
	var ring1_stations := []
	for station_name in stations:
		if stations[station_name].ring == 1:
			ring1_stations.append(station_name)

	if ring1_stations.size() > 0:
		return ring1_stations[randi() % ring1_stations.size()]
	return ""


func get_all_station_names() -> Array:
	"""Get array of all station names"""
	return stations.keys()


func get_station_ring(station_name: String) -> int:
	"""Get the ring number of a station (1 or 2)"""
	if station_name in stations:
		return stations[station_name].ring
	return 0


func update_hovered_station() -> void:
	"""Update which station is being hovered over"""
	var mouse_pos = get_global_mouse_position()
	var new_hovered = get_station_at_position(mouse_pos, STATION_RADIUS * 2)

	if new_hovered != hovered_station:
		hovered_station = new_hovered
		queue_redraw()


func set_current_station(station_name: String) -> void:
	"""Set the current docked station"""
	if current_station != station_name:
		current_station = station_name
		queue_redraw()


func set_selected_destination(station_name: String) -> void:
	"""Set the selected destination station"""
	if selected_destination != station_name:
		selected_destination = station_name
		queue_redraw()


func set_contract_hover_destination(station_name: String) -> void:
	"""Set the contract hover destination"""
	if contract_hover_destination != station_name:
		contract_hover_destination = station_name
		queue_redraw()


func _input(event: InputEvent) -> void:
	"""Handle station clicking"""
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not is_panning:
			var world_pos = get_global_mouse_position()
			var clicked_station = get_station_at_position(world_pos)
			if clicked_station != "":
				station_clicked.emit(clicked_station)


func get_save_data() -> Dictionary:
	"""Get save data for MapSystem"""
	var stations_data := {}

	# Convert Vector2 positions to serializable format
	for station_name in stations:
		var station = stations[station_name]
		stations_data[station_name] = {
			"position": {
				"x": station.position.x,
				"y": station.position.y
			},
			"ring": station.ring
		}

	return {
		"stations": stations_data
	}


func load_save_data(data: Dictionary) -> void:
	"""Load save data for MapSystem"""
	stations.clear()

	var stations_data = data.get("stations", {})
	for station_name in stations_data:
		var station_data = stations_data[station_name]
		var pos_data = station_data.position

		stations[station_name] = {
			"name": station_name,
			"position": Vector2(pos_data.x, pos_data.y),
			"ring": station_data.ring
		}

	# Redraw with loaded stations
	queue_redraw()
	print("Loaded %d stations from save" % stations.size())
