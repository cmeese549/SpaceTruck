extends Node3D

@onready var autopilot = $AutoPilot
@onready var space_env = $SpaceEnvironment
@onready var ui = $UI
@onready var contracts : Contracts = $Contracts
@onready var money : Money = $Money

var current_station = ""
var destination_station = ""

func _ready():
	print("Space Trucking Game Initialized")
	autopilot.journey_completed.connect(_on_journey_completed)
	
	# Wait for space environment to discover stations
	await get_tree().process_frame
	setup_initial_state()

func setup_initial_state():
	"""Initialize at the first discovered station"""
	var station_names = space_env.get_station_names()
	
	if station_names.size() == 0:
		print("ERROR: No stations discovered!")
		return
	
	# Start at first station found
	current_station = station_names[0]
	print("Starting at station: ", current_station)
	
	space_env.setup_at_station(current_station)
	ui.show_station_interface(current_station)

func start_journey_to(station_name: String):
	"""Start journey to any discovered station"""
	if autopilot.is_traveling:
		print("Already traveling, cannot start new journey")
		return
	
	if station_name == current_station:
		print("Already at destination: ", station_name)
		return
	
	destination_station = station_name
	print("Starting journey from ", current_station, " to ", destination_station)
	
	ui.hide_station_interface()
	autopilot.start_journey(current_station, destination_station)
	space_env.begin_departure(current_station, destination_station)

func _on_journey_completed():
	"""Handle arrival at destination"""
	current_station = destination_station
	
	# Process payment through contracts system
	var journey_info = autopilot.get_journey_info()
	contracts.process_journey_payment(journey_info.from, journey_info.to, journey_info.distance, money)
	
	space_env.arrive_at_station(current_station)
	ui.show_station_interface(current_station)

func get_current_station() -> String:
	"""Get name of current station"""
	return current_station

func get_available_destinations() -> Array:
	"""Get list of all stations except current one"""
	var all_stations = space_env.get_station_names()
	var destinations = []
	
	for station in all_stations:
		if station != current_station:
			destinations.append(station)
	
	return destinations
