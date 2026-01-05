extends Node3D
class_name SpaceEnvironment

@onready var destinations_parent = $Destinations
@onready var starfield = $StarField

# Dynamic station system
var station_positions = {}  # Will be populated dynamically
var destination_nodes = {}  # Maps station names to their nodes

var journey_distance: float = 100.0
var current_progress: float = 0.0
var current_from: String = ""
var current_to: String = ""

# Obstacle avoidance
var station_influence_radius: float = 15.0
var avoidance_height: float = 20.0
var current_vertical_offset: float = 0.0
var vertical_smoothing: float = 2.0

func _ready():
	# Discover all stations dynamically
	discover_stations()
	
	# Connect to autopilot progress updates - wait for autopilot to be ready
	await get_tree().process_frame
	var autopilot = get_node("../AutoPilot")
	if autopilot:
		autopilot.progress_updated.connect(_on_progress_updated)
		print("SpaceEnvironment connected to AutoPilot")
	else:
		print("SpaceEnvironment: AutoPilot not found!")

func discover_stations():
	"""Scan all Destination nodes and build station system dynamically"""
	station_positions.clear()
	destination_nodes.clear()
	
	if not destinations_parent:
		print("SpaceEnvironment: No Destinations parent found!")
		return
	
	# Find all Destination nodes
	for child in destinations_parent.get_children():
		if child is Destination:
			var station_name = child._name
			station_positions[station_name] = child.global_position
			destination_nodes[station_name] = child
			print("Discovered station: ", station_name, " at ", child.global_position)
	
	print("Total stations discovered: ", station_positions.size())
	
	# Calculate journey distance (use distance between first two stations as default)
	var station_names = station_positions.keys()
	if station_names.size() >= 2:
		journey_distance = station_positions[station_names[0]].distance_to(station_positions[station_names[1]])

func get_station_names() -> Array:
	"""Get list of all discovered station names"""
	return station_positions.keys()

func get_station_count() -> int:
	"""Get total number of discovered stations"""
	return station_positions.size()

func _process(delta):
	pass

func setup_at_station(station_name: String):
	"""Position all stations when docked at a specific station"""
	if not station_positions.has(station_name):
		print("SpaceEnvironment: Unknown station: ", station_name)
		return
	
	current_vertical_offset = 0.0
	var ship_virtual_world_pos = station_positions[station_name]
	
	# Position all destination nodes relative to ship
	for dest_name in station_positions.keys():
		var dest_world_pos = station_positions[dest_name]
		var dest_relative = dest_world_pos - ship_virtual_world_pos
		destination_nodes[dest_name].position = dest_relative

func begin_departure(from_station: String, to_station: String):
	"""Set up initial positions for journey between any two stations"""
	if not station_positions.has(from_station) or not station_positions.has(to_station):
		print("SpaceEnvironment: Invalid station names for journey")
		return
	
	current_progress = 0.0
	current_from = from_station
	current_to = to_station
	current_vertical_offset = 0.0
	
	# Orient camera toward destination
	var ship_camera = get_node("../Ship/Camera3D")
	var from_pos = station_positions[from_station]
	var to_pos = station_positions[to_station]
	
	# Calculate direction vector
	var direction = (to_pos - from_pos).normalized()
	
	# Set camera rotation to face direction of travel
	var target_rotation = Vector3()
	target_rotation.y = atan2(direction.x, direction.z) + PI
	target_rotation.x = -asin(direction.y)
	
	ship_camera.rotation = target_rotation

func _on_progress_updated(progress: float):
	current_progress = progress
	update_environment_positions()

func update_environment_positions():
	"""Update positions of all stations during journey"""
	if current_from == "" or current_to == "":
		return
	
	# Calculate ship's virtual world position along journey path
	var from_pos = station_positions[current_from]
	var to_pos = station_positions[current_to]
	var ship_virtual_world_pos = from_pos.lerp(to_pos, current_progress)
	
	# Check for station obstacles and calculate avoidance
	var target_vertical_offset = 0.0
	
	for station_name in station_positions.keys():
		# Skip avoidance for origin station in first 10% of journey
		if station_name == current_from and current_progress < 0.1:
			continue
		# Skip avoidance for destination station in last 10% of journey  
		if station_name == current_to and current_progress > 0.9:
			continue
			
		var station_pos = station_positions[station_name]
		var distance_to_station = ship_virtual_world_pos.distance_to(station_pos)
		
		if distance_to_station < station_influence_radius:
			target_vertical_offset = avoidance_height
			break
	
	# Smooth vertical offset changes
	current_vertical_offset = lerp(current_vertical_offset, target_vertical_offset, vertical_smoothing * get_process_delta_time())
	
	# Position all destination nodes relative to ship's virtual position
	for dest_name in station_positions.keys():
		var dest_world_pos = station_positions[dest_name]
		var dest_relative = dest_world_pos - ship_virtual_world_pos
		destination_nodes[dest_name].position = dest_relative + Vector3(0, -current_vertical_offset, 0)
	
	# Rotate starfield slowly for movement effect
	starfield.rotation.z += 0.001

func arrive_at_station(station_name: String):
	"""Final positioning when arriving at any station"""
	setup_at_station(station_name)
