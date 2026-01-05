extends Node
class_name AutoPilot

signal journey_completed
signal progress_updated(progress: float)

# Journey state
var journey_progress: float = 0.0
var is_traveling: bool = false
var journey_duration: float = 0.0  # Calculated per journey
var journey_distance: float = 0.0

# Ship stats (upgradeable)
var ship_speed: float = 5.0  # units per second
var fuel_capacity: float = 700.0
var current_fuel: float = 700.0
var fuel_consumption_rate: float = 1.0
var cargo_capacity: int = 10

var origin_station: String = ""
var destination_station: String = ""

func _ready():
	set_process(false)

func start_journey(from_station: String, to_station: String):
	if is_traveling:
		return false
	
	# Get distance from SpaceEnvironment
	var space_env = get_node("../SpaceEnvironment")
	if not space_env:
		print("AutoPilot: SpaceEnvironment not found!")
		return false
	
	# Calculate journey distance
	var from_pos = space_env.station_positions.get(from_station)
	var to_pos = space_env.station_positions.get(to_station)
	
	if not from_pos or not to_pos:
		print("AutoPilot: Invalid station positions for journey")
		return false
	
	journey_distance = from_pos.distance_to(to_pos)
	var fuel_needed = journey_distance * fuel_consumption_rate
	
	# Check if we have enough fuel
	if current_fuel < fuel_needed:
		print("AutoPilot: Insufficient fuel! Need %.1f, have %.1f" % [fuel_needed, current_fuel])
		return false
	
	journey_duration = journey_distance / ship_speed
	
	# Set up journey
	origin_station = from_station
	destination_station = to_station
	journey_progress = 0.0
	is_traveling = true
	
	print("Starting journey from ", from_station, " to ", to_station)
	print("Distance: ", "%.1f" % journey_distance, " units")
	print("Fuel needed: ", "%.1f" % fuel_needed, " (", "%.1f" % current_fuel, " available)")
	print("Speed: ", ship_speed, " units/sec")
	print("Estimated time: ", "%.1f" % journey_duration, " seconds")
	
	set_process(true)
	return true

func _process(delta):
	if not is_traveling:
		return
	
	# Update progress based on time and distance
	var progress_increment = delta / journey_duration
	journey_progress += progress_increment
	
	# Clamp to 1.0 and check completion
	journey_progress = min(journey_progress, 1.0)
	progress_updated.emit(journey_progress)
	
	if journey_progress >= 1.0:
		complete_journey()

func complete_journey():
	# Consume fuel for the journey
	var fuel_consumed = journey_distance * fuel_consumption_rate
	current_fuel -= fuel_consumed
	current_fuel = max(current_fuel, 0.0)  # Prevent negative fuel
	
	is_traveling = false
	set_process(false)
	journey_completed.emit()
	print("Journey completed! Fuel consumed: %.1f (%.1f remaining)" % [fuel_consumed, current_fuel])

func upgrade_speed(new_speed: float):
	ship_speed = new_speed
	print("Ship speed upgraded to: ", ship_speed, " units/sec")

func upgrade_fuel_capacity(new_capacity: float):
	var fuel_percentage = current_fuel / fuel_capacity
	fuel_capacity = new_capacity
	current_fuel = fuel_capacity * fuel_percentage  # Maintain fuel percentage
	print("Fuel capacity upgraded to: ", fuel_capacity, " units")

func get_estimated_time(from_station: String, to_station: String) -> float:
	"""Calculate estimated journey time between two stations"""
	var space_env = get_node("../SpaceEnvironment")
	if not space_env:
		return 0.0
	
	var from_pos = space_env.station_positions.get(from_station)
	var to_pos = space_env.station_positions.get(to_station)
	
	if not from_pos or not to_pos:
		return 0.0
	
	var distance = from_pos.distance_to(to_pos)
	return distance / ship_speed

func get_journey_info() -> Dictionary:
	"""Get current journey information"""
	return {
		"progress": journey_progress,
		"distance": journey_distance,
		"duration": journey_duration,
		"speed": ship_speed,
		"from": origin_station,
		"to": destination_station,
		"is_traveling": is_traveling,
		"fuel_consumed": journey_distance * fuel_consumption_rate if journey_distance > 0 else 0
	}

func get_fuel_info() -> Dictionary:
	"""Get current fuel status"""
	return {
		"current": current_fuel,
		"capacity": fuel_capacity,
		"percentage": (current_fuel / fuel_capacity) * 100.0,
		"consumption_rate": fuel_consumption_rate
	}

func can_make_journey(from_station: String, to_station: String) -> bool:
	"""Check if ship has enough fuel for journey"""
	var space_env = get_node("../SpaceEnvironment")
	if not space_env:
		return false
	
	var from_pos = space_env.station_positions.get(from_station)
	var to_pos = space_env.station_positions.get(to_station)
	
	if not from_pos or not to_pos:
		return false
	
	var distance = from_pos.distance_to(to_pos)
	var fuel_needed = distance * fuel_consumption_rate
	return current_fuel >= fuel_needed

func refuel(amount: float):
	"""Add fuel to tank (capped at capacity)"""
	current_fuel = min(current_fuel + amount, fuel_capacity)
	print("Refueled: %.1f/%.1f" % [current_fuel, fuel_capacity])

func get_progress_percentage() -> int:
	return int(journey_progress * 100)
