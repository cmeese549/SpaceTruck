extends Node3D
class_name SpaceEnvironment

@onready var origin_station = $Destinations/Destination
@onready var destination_station = $Destinations/Destination2
@onready var starfield = $StarField

# Station positions relative to ship
@onready var station_positions = {
	"Station_A": $Destinations/Destination.global_position,
	"Station_B": $Destinations/Destination2.global_position
}

var journey_distance: float = 100.0  # Will be calculated from actual station positions
var current_progress: float = 0.0
var current_from: String = ""
var current_to: String = ""

# Obstacle avoidance
var station_influence_radius: float = 15.0  # How close to station triggers avoidance
var avoidance_height: float = 20.0  # How high to fly over stations
var current_vertical_offset: float = 0.0
var vertical_smoothing: float = 2.0

func _ready():
	# Connect to autopilot progress updates - wait for autopilot to be ready
	await get_tree().process_frame
	var autopilot = get_node("../AutoPilot")
	if autopilot:
		autopilot.progress_updated.connect(_on_progress_updated)
		print("SpaceEnvironment connected to AutoPilot")
	else:
		print("SpaceEnvironment: AutoPilot not found!")
	
	# Calculate actual journey distance from station positions
	if station_positions.has("Station_A") and station_positions.has("Station_B"):
		journey_distance = station_positions["Station_A"].distance_to(station_positions["Station_B"])

func _process(delta):
	# This ensures we have delta time available for smooth vertical offset changes
	pass

func setup_at_station(station_name: String):
	# Position stations when "docked" using the same logic as during flight
	current_vertical_offset = 0.0
	
	# Ship is virtually "at" the station position
	var ship_virtual_world_pos = station_positions[station_name]
	
	# Position stations relative to ship using same logic as update_environment_positions
	var station_a_world_pos = station_positions["Station_A"]
	var station_b_world_pos = station_positions["Station_B"]
	
	# Calculate where each station should appear relative to ship
	var station_a_relative = station_a_world_pos - ship_virtual_world_pos
	var station_b_relative = station_b_world_pos - ship_virtual_world_pos
	
	# Apply the positions - origin_station is always Station A, destination_station is always Station B
	origin_station.position = station_a_relative
	destination_station.position = station_b_relative

func begin_departure(from_station: String, to_station: String):
	# Set up initial positions for journey
	current_progress = 0.0
	current_from = from_station
	current_to = to_station
	current_vertical_offset = 0.0
	
	# Orient camera toward destination
	var ship_camera = get_node("../Ship/Camera3D")
	var from_pos = station_positions[from_station]
	var to_pos = station_positions[to_station]
	
	# Calculate direction vector (destination - origin)
	var direction = (to_pos - from_pos).normalized()
	
	# Set camera rotation to face direction of travel
	# Godot camera default faces -Z, so we need to adjust
	var target_rotation = Vector3()
	target_rotation.y = atan2(direction.x, direction.z) + PI  # Add PI to flip 180 degrees
	target_rotation.x = -asin(direction.y)  # Vertical rotation (pitch)
	
	ship_camera.rotation = target_rotation

func _on_progress_updated(progress: float):
	current_progress = progress
	update_environment_positions()

func update_environment_positions():
	# Calculate ship's virtual world position along journey path
	var from_pos = station_positions[current_from]
	var to_pos = station_positions[current_to]
	var ship_virtual_world_pos = from_pos.lerp(to_pos, current_progress)
	
	# Check for station obstacles and calculate avoidance
	var target_vertical_offset = 0.0
	
	# Check distance to all stations (except origin/destination during start/end phases)
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
	
	# Position stations relative to ship's virtual position
	# Ship stays at (0,0,0), world moves around it
	var station_a_world_pos = station_positions["Station_A"]
	var station_b_world_pos = station_positions["Station_B"]
	
	# Calculate where each station should appear relative to ship
	var station_a_relative = station_a_world_pos - ship_virtual_world_pos
	var station_b_relative = station_b_world_pos - ship_virtual_world_pos
	
	# Apply the positions (with vertical offset for obstacle avoidance)
	origin_station.position = station_a_relative + Vector3(0, -current_vertical_offset, 0)
	destination_station.position = station_b_relative + Vector3(0, -current_vertical_offset, 0)
	
	# Rotate starfield slowly for movement effect
	starfield.rotation.z += 0.001

func arrive_at_station(station_name: String):
	# Final positioning when arriving
	setup_at_station(station_name)
