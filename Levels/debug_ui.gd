extends Control

## Simple debug UI for Phase 1 testing
## Shows ship status and basic controls

@onready var status_label: Label = $Panel/VBoxContainer/StatusLabel
@onready var fuel_label: Label = $Panel/VBoxContainer/FuelLabel
@onready var money_label: Label = $Panel/VBoxContainer/MoneyLabel
@onready var journey_label: Label = $Panel/VBoxContainer/JourneyLabel

var main_level: MainLevel2D


func _ready() -> void:
	main_level = get_parent()


func _process(_delta: float) -> void:
	if main_level:
		update_display()


func update_display() -> void:
	# Status
	var current = main_level.get_current_station()
	var dest = main_level.get_destination_station()
	status_label.text = "Station: %s" % current

	# Fuel
	var fuel_info = main_level.auto_pilot.get_fuel_info()
	fuel_label.text = "Fuel: %.0f / %.0f (%.0f%%)" % [
		fuel_info.current,
		fuel_info.capacity,
		fuel_info.percentage
	]

	# Money and cargo
	var cargo_used = main_level.contract_system.get_used_cargo_space()
	var cargo_max = main_level.auto_pilot.cargo_capacity
	money_label.text = "Money: $%d | Cargo: %d/%d" % [
		main_level.money.current_money,
		cargo_used,
		cargo_max
	]

	# Journey
	if dest != "":
		var journey_info = main_level.auto_pilot.get_journey_info()
		var active_contracts = main_level.contract_system.get_active_contracts().size()
		journey_label.text = "Traveling to %s... (%.0f%%) | Active Contracts: %d" % [
			dest,
			journey_info.progress * 100,
			active_contracts
		]
	else:
		var active_contracts = main_level.contract_system.get_active_contracts().size()
		var available_contracts = main_level.contract_system.get_station_contracts(current).size()
		journey_label.text = "Docked | Active: %d | Available: %d (Click station to travel)" % [
			active_contracts,
			available_contracts
		]
