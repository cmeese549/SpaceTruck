extends Control

@onready var station_panel = $StationPanel
@onready var journey_panel = $JourneyPanel
@onready var progress_bar = $JourneyPanel/MarginContainer/VBox/ProgressBar
@onready var progress_label = $JourneyPanel/MarginContainer/VBox/ProgressLabel
@onready var travel_button_a = $StationPanel/MarginContainer/VBox/TravelToA
@onready var travel_button_b = $StationPanel/MarginContainer/VBox/TravelToB
@onready var station_label = $StationPanel/MarginContainer/VBox/StationLabel

var main_scene: Node3D

func _ready():
	main_scene = get_node("../")
	
	# Connect travel buttons
	travel_button_a.pressed.connect(_on_travel_to_a)
	travel_button_b.pressed.connect(_on_travel_to_b)
	
	# Connect to autopilot signals
	var autopilot = get_node("../AutoPilot")
	if autopilot:
		autopilot.progress_updated.connect(_on_progress_updated)
		autopilot.journey_completed.connect(_on_journey_completed)
	
	# Start with station interface visible
	show_station_interface("Station_A")

func show_station_interface(station_name: String):
	station_panel.visible = true
	journey_panel.visible = false
	station_label.text = "Current Station: " + station_name
	
	# Update button states based on current station
	travel_button_a.disabled = (station_name == "Station_A")
	travel_button_b.disabled = (station_name == "Station_B")

func hide_station_interface():
	station_panel.visible = false
	journey_panel.visible = true
	progress_bar.value = 0
	progress_label.text = "Departing..."

func _on_travel_to_a():
	main_scene.start_journey_to("Station_A")

func _on_travel_to_b():
	main_scene.start_journey_to("Station_B")

func _on_progress_updated(progress: float):
	progress_bar.value = progress * 100
	var percentage = int(progress * 100)
	progress_label.text = "Journey Progress: " + str(percentage) + "%"

func _on_journey_completed():
	journey_panel.visible = false
