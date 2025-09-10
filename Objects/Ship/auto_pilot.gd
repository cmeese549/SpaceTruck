extends Node
class_name AutoPilot

signal journey_completed
signal progress_updated(progress: float)

# Journey settings
var journey_duration: float = 30.0  # 10 seconds for testing
var journey_progress: float = 0.0
var is_traveling: bool = false

# Ship stats (upgradeable)
var ship_speed: float = 1.0  # multiplier for journey speed
var fuel_capacity: float = 100.0
var cargo_capacity: int = 10

var origin_station: String = ""
var destination_station: String = ""

func _ready():
	set_process(false)

func start_journey(from_station: String, to_station: String):
	if is_traveling:
		return false
	
	origin_station = from_station
	destination_station = to_station
	journey_progress = 0.0
	is_traveling = true
	
	print("Starting journey from ", from_station, " to ", to_station)
	print("Estimated time: ", journey_duration / ship_speed, " seconds")
	
	set_process(true)
	return true

func _process(delta):
	if not is_traveling:
		return
	
	# Update progress based on ship speed
	var progress_rate = ship_speed / journey_duration
	var progress_increment = progress_rate * delta
	journey_progress += progress_increment
	
	# Clamp to 1.0 and check completion
	journey_progress = min(journey_progress, 1.0)
	progress_updated.emit(journey_progress)
	
	if journey_progress >= 1.0:
		complete_journey()

func complete_journey():
	is_traveling = false
	set_process(false)
	journey_completed.emit()
	print("Journey completed!")

func upgrade_speed(new_speed: float):
	ship_speed = new_speed
	print("Ship speed upgraded to: ", ship_speed)

func get_estimated_time() -> float:
	return journey_duration / ship_speed

func get_progress_percentage() -> int:
	return int(journey_progress * 100)
