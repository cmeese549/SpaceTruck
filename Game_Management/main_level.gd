extends Node3D

@onready var autopilot = $AutoPilot
@onready var space_env = $SpaceEnvironment
@onready var ui = $UI

var current_station = "Station_A"
var destination_station = "Station_B"

func _ready():
	print("Space Trucking Game Initialized")
	autopilot.journey_completed.connect(_on_journey_completed)
	# Wait one frame for UI to be ready
	await get_tree().process_frame
	setup_initial_state()

func setup_initial_state():
	# Start at Station A
	space_env.setup_at_station(current_station)
	ui.show_station_interface(current_station)

func start_journey_to(station_name: String):
	if autopilot.is_traveling:
		return
	
	destination_station = station_name
	ui.hide_station_interface()
	autopilot.start_journey(current_station, destination_station)
	space_env.begin_departure(current_station, destination_station)

func _on_journey_completed():
	current_station = destination_station
	space_env.arrive_at_station(current_station)
	ui.show_station_interface(current_station)
	print("Arrived at: ", current_station)
