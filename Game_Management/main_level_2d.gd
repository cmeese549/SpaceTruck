extends Node2D
class_name MainLevel2D

## Main game controller for 2D Space Truck
## Manages game state, coordinates between systems

# Game state
var current_station := ""
var destination_station := ""
var journey_start_position := Vector2.ZERO  # Track actual journey start position (for mid-flight course changes)

# References
@onready var map_system: MapSystem = $MapSystem
@onready var ship: Ship2D = $MapSystem/Ship
@onready var auto_pilot: AutoPilot = $AutoPilot
@onready var money: Money = $Money
@onready var contract_system: ContractSystem = $ContractSystem
@onready var game_ui: GameUI = $GameUI


func _ready() -> void:
	setup_connections()
	setup_initial_state()


func _notification(what: int) -> void:
	"""Handle application quit notification"""
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# Save game before quitting
		save_game()
		get_tree().quit()


func _input(event: InputEvent) -> void:
	"""Handle test input for Phase 2"""
	if event is InputEventKey and event.pressed:
		# Press 'C' to accept a random contract at current station
		if event.keycode == KEY_C and not event.echo:
			test_accept_contract()


func test_accept_contract() -> void:
	"""Test function: Accept a random available contract"""
	if destination_station != "":
		print("Cannot accept contracts while traveling!")
		return

	var available = contract_system.get_station_contracts(current_station)
	if available.size() == 0:
		print("No contracts available at %s" % current_station)
		return

	# Accept first available contract
	var contract = available[0]
	if contract_system.accept_contract(contract):
		print("✓ Accepted: %s -> %s (%d cargo, $%d, %.0f fuel)" % [
			contract.origin_station,
			contract.destination_station,
			contract.cargo_units,
			contract.payment,
			contract.fuel_required
		])


func setup_connections() -> void:
	"""Connect signals between systems"""
	auto_pilot.journey_completed.connect(_on_journey_completed)
	auto_pilot.progress_updated.connect(_on_progress_updated)
	map_system.station_clicked.connect(_on_station_clicked)

	# Connect UI signals
	game_ui.refuel_requested.connect(_on_ui_refuel_requested)
	game_ui.upgrade_speed_requested.connect(_on_ui_upgrade_speed)
	game_ui.upgrade_fuel_capacity_requested.connect(_on_ui_upgrade_fuel)
	game_ui.upgrade_cargo_capacity_requested.connect(_on_ui_upgrade_cargo)
	game_ui.contract_accepted.connect(_on_ui_contract_accepted)
	game_ui.contract_dumped.connect(_on_ui_contract_dumped)
	game_ui.set_destination_requested.connect(_on_ui_set_destination)
	game_ui.start_flight_requested.connect(_on_ui_start_flight)
	game_ui.stop_flight_requested.connect(_on_ui_stop_flight)
	game_ui.new_game_requested.connect(_on_ui_new_game)


func setup_initial_state() -> void:
	"""Initialize game - load save or start new game"""
	# Set contract system references (needed for both new and loaded games)
	contract_system.map_system = map_system
	contract_system.auto_pilot = auto_pilot

	# Try to load save file
	var loaded = load_game()

	if not loaded:
		# Start new game - generate fresh map and contracts
		map_system.generate_stations()
		contract_system.generate_all_station_contracts()

		# Start at random Ring 1 station
		current_station = map_system.get_random_ring1_station()

		if current_station == "":
			push_error("Failed to find starting station!")
			return

		# Position ship at starting station
		var start_pos = map_system.get_station_position(current_station)
		ship.set_ship_position(start_pos)

		# Initialize AutoPilot
		auto_pilot.current_fuel = auto_pilot.fuel_capacity  # Full tank

		print("New game started at: %s" % current_station)
		print("Ship position: %s" % start_pos)
		print("Fuel: %d/%d" % [auto_pilot.current_fuel, auto_pilot.fuel_capacity])
		print("Cargo: 0/%d" % auto_pilot.cargo_capacity)

	# Update map highlighting for current station and destination
	map_system.set_current_station(current_station)
	if destination_station != "":
		map_system.set_selected_destination(destination_station)

	# Initialize UI (for both new and loaded games)
	game_ui.initialize(self)
	print("Money: $%d" % money.current_money)


func start_journey_to(station_name: String) -> bool:
	"""Start a journey to a destination station"""
	if station_name == current_station:
		push_warning("Already at %s!" % station_name)
		return false

	# Get positions
	var from_pos = map_system.get_station_position(current_station)
	var to_pos = map_system.get_station_position(station_name)

	# Calculate distance
	var distance = from_pos.distance_to(to_pos)

	# Check if we have enough fuel
	if not auto_pilot.can_make_journey(current_station, station_name, distance):
		push_warning("Insufficient fuel for journey to %s" % station_name)
		return false

	# Start the journey
	destination_station = station_name
	ship.set_destination(to_pos)
	auto_pilot.start_journey(current_station, station_name, distance)

	# Update map highlighting
	map_system.set_selected_destination(destination_station)

	print("Journey started: %s -> %s (%.1f units)" % [current_station, destination_station, distance])
	return true


func _on_journey_completed() -> void:
	"""Handle journey completion"""
	print("Arrived at %s!" % destination_station)

	# Update position
	current_station = destination_station
	destination_station = ""
	journey_start_position = Vector2.ZERO  # Clear for next journey

	# Update ship visual
	var arrival_pos = map_system.get_station_position(current_station)
	ship.set_ship_position(arrival_pos)
	ship.clear_destination()

	# Update map highlighting
	map_system.set_current_station(current_station)
	map_system.set_selected_destination("")  # Clear destination

	# Complete any contracts for this destination
	var completed_contracts = contract_system.complete_contracts_at_station(current_station, money)

	if completed_contracts.size() > 0:
		var total_payment = 0
		for contract in completed_contracts:
			total_payment += contract.payment
		print("Contracts completed: %d contracts, $%d total payment" % [completed_contracts.size(), total_payment])
	else:
		print("No contracts completed at this station")

	print("Fuel remaining: %d/%d" % [auto_pilot.current_fuel, auto_pilot.fuel_capacity])
	print("Cargo space: %d/%d used" % [contract_system.get_used_cargo_space(), auto_pilot.cargo_capacity])

	# Auto-save on docking
	save_game()

	# Notify UI
	game_ui.on_docked()


func _on_progress_updated(progress: float) -> void:
	"""Update ship visual position during journey"""
	if destination_station != "":
		# Use journey_start_position if set (for mid-flight course changes)
		# Otherwise use the origin station position (normal journey from docked station)
		var from_pos = journey_start_position if journey_start_position != Vector2.ZERO else map_system.get_station_position(auto_pilot.origin_station)
		var to_pos = map_system.get_station_position(destination_station)
		var current_pos = from_pos.lerp(to_pos, progress)
		ship.set_ship_position(current_pos)


func _on_station_clicked(station_name: String) -> void:
	"""Handle station click on map"""
	print("Clicked station: %s" % station_name)
	game_ui.on_station_clicked(station_name)


func get_current_station() -> String:
	"""Get current station name"""
	return current_station


func get_destination_station() -> String:
	"""Get destination station name (empty if not traveling)"""
	return destination_station


func is_traveling() -> bool:
	"""Check if currently traveling"""
	return auto_pilot.is_traveling


# UI Signal Handlers

func _on_ui_refuel_requested() -> void:
	"""Handle refuel button press"""
	var fuel_needed = auto_pilot.fuel_capacity - auto_pilot.current_fuel
	var base_cost = fuel_needed * 1.5

	# Apply 2x penalty if in debt
	var cost = int(base_cost * 2.0 if money.is_in_debt() else base_cost)

	if money.try_buy(cost):
		auto_pilot.refuel(fuel_needed)
		if money.is_in_debt():
			print("Refueled for $%d (2x debt penalty applied)" % cost)
		else:
			print("Refueled for $%d" % cost)
		game_ui.update_ui()  # Refresh UI to show new fuel cost


func _on_ui_upgrade_speed() -> void:
	"""Handle speed upgrade button press"""
	if money.is_in_debt():
		print("Cannot upgrade while in debt!")
		return

	var cost = int(auto_pilot.ship_speed * 50)

	if money.try_buy(cost):
		auto_pilot.upgrade_speed(auto_pilot.ship_speed + 5.0)
		print("Upgraded speed for $%d" % cost)
		game_ui.update_ui()


func _on_ui_upgrade_fuel() -> void:
	"""Handle fuel capacity upgrade button press"""
	if money.is_in_debt():
		print("Cannot upgrade while in debt!")
		return

	var cost = int(auto_pilot.fuel_capacity * 0.5)

	if money.try_buy(cost):
		auto_pilot.upgrade_fuel_capacity(auto_pilot.fuel_capacity + 100.0)
		print("Upgraded fuel capacity for $%d" % cost)
		game_ui.update_ui()


func _on_ui_upgrade_cargo() -> void:
	"""Handle cargo capacity upgrade button press"""
	if money.is_in_debt():
		print("Cannot upgrade while in debt!")
		return

	var cost = auto_pilot.cargo_capacity * 10

	if money.try_buy(cost):
		auto_pilot.cargo_capacity += 10
		print("Upgraded cargo capacity for $%d" % cost)
		game_ui.update_ui()


func _on_ui_contract_accepted(contract: Dictionary) -> void:
	"""Handle contract acceptance from UI"""
	contract_system.accept_contract(contract)


func _on_ui_contract_dumped(contract_index: int) -> void:
	"""Handle contract dump from UI"""
	contract_system.dump_contract(contract_index, current_station, money)


func _on_ui_set_destination(station_name: String) -> void:
	"""Handle set destination button press"""
	var dest_pos = map_system.get_station_position(station_name)

	# Check if we're currently traveling
	if auto_pilot.is_traveling:
		# Change course mid-flight
		# Save current ship position (we're in space between stations)
		var current_pos = ship.global_position
		var new_distance = current_pos.distance_to(dest_pos)

		# Check if we have enough fuel for the new route
		var fuel_required = new_distance * auto_pilot.fuel_consumption_rate
		if auto_pilot.current_fuel < fuel_required:
			print("Cannot change course: insufficient fuel for new route!")
			return

		# Stop current journey
		auto_pilot.is_traveling = false
		auto_pilot.set_process(false)

		# Set new destination
		destination_station = station_name
		ship.set_destination(dest_pos)

		# Save the current position as the journey start position
		# This will be used by _on_progress_updated to interpolate from here instead of origin station
		journey_start_position = current_pos

		# Start new journey - origin station doesn't matter since we use journey_start_position
		if auto_pilot.start_journey(auto_pilot.origin_station, station_name, new_distance):
			print("Course changed to: %s" % destination_station)
			game_ui.update_ui()
		else:
			print("Failed to change course!")
			# Restore old destination if failed
			destination_station = auto_pilot.destination_station
			journey_start_position = Vector2.ZERO
			auto_pilot.is_traveling = true
			auto_pilot.set_process(true)
	else:
		# Not traveling - just set the destination
		# User must press Start Flight in Ship tab
		destination_station = station_name
		ship.set_destination(dest_pos)
		print("Destination set to: %s" % destination_station)
		game_ui.update_ui()


func _on_ui_start_flight() -> void:
	"""Handle start flight button press"""
	if destination_station != "":
		# Check if resuming a paused journey
		if auto_pilot.journey_progress > 0 and auto_pilot.journey_progress < 1.0:
			# Resume paused journey
			auto_pilot.is_traveling = true
			auto_pilot.set_process(true)
			print("Flight resumed to %s" % destination_station)
			game_ui.update_ui()
		else:
			# Start new journey from docked station
			var from_pos = map_system.get_station_position(current_station)
			var to_pos = map_system.get_station_position(destination_station)
			var distance = from_pos.distance_to(to_pos)

			# Clear journey_start_position for normal station-to-station travel
			journey_start_position = Vector2.ZERO

			# Start journey
			if auto_pilot.start_journey(current_station, destination_station, distance):
				print("Flight started to %s" % destination_station)
				game_ui.update_ui()
			else:
				print("Cannot start flight (insufficient fuel or already traveling)")
				destination_station = ""
				ship.clear_destination()
				game_ui.update_ui()


func _on_ui_stop_flight() -> void:
	"""Handle stop flight button press (pause journey)"""
	if auto_pilot.is_traveling:
		auto_pilot.is_traveling = false
		auto_pilot.set_process(false)

		# Keep destination set and ship position where it is
		# This allows resuming the flight later
		print("Flight paused. Destination: %s" % destination_station)
		game_ui.update_ui()


func _on_ui_new_game() -> void:
	"""Handle new game button - delete save and reload scene"""
	# Delete save file
	if FileAccess.file_exists(SAVE_FILE_PATH):
		DirAccess.remove_absolute(SAVE_FILE_PATH)
		print("Save file deleted")

	# Reload the scene to start fresh
	get_tree().reload_current_scene()


# ============================================================================
# SAVE/LOAD SYSTEM
# ============================================================================

const SAVE_FILE_PATH = "user://spacetruck_save.json"


func save_game() -> void:
	"""Save complete game state to file"""
	var save_data = {
		"current_station": current_station,
		"destination_station": destination_station,
		"journey_start_position": {
			"x": journey_start_position.x,
			"y": journey_start_position.y
		},
		"ship_position": {
			"x": ship.global_position.x,
			"y": ship.global_position.y
		},
		"map_system": map_system.get_save_data(),
		"auto_pilot": auto_pilot.get_save_data(),
		"money": money.get_save_data(),
		"contract_system": contract_system.get_save_data()
	}

	var json_string = JSON.stringify(save_data, "\t")
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)

	if file:
		file.store_string(json_string)
		file.close()
		print("Game saved to: %s" % SAVE_FILE_PATH)
	else:
		push_error("Failed to save game!")


func load_game() -> bool:
	"""Load game state from file. Returns true if loaded successfully."""
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		print("No save file found. Starting new game.")
		return false

	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if not file:
		push_error("Failed to open save file!")
		return false

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)

	if parse_result != OK:
		push_error("Failed to parse save file!")
		return false

	var save_data = json.data

	# Load game state
	current_station = save_data.get("current_station", "")
	destination_station = save_data.get("destination_station", "")

	var journey_pos_data = save_data.get("journey_start_position", {"x": 0, "y": 0})
	journey_start_position = Vector2(journey_pos_data.x, journey_pos_data.y)

	var ship_pos_data = save_data.get("ship_position", {"x": 0, "y": 0})
	var loaded_ship_pos = Vector2(ship_pos_data.x, ship_pos_data.y)

	# Load subsystem data
	map_system.load_save_data(save_data.get("map_system", {}))
	auto_pilot.load_save_data(save_data.get("auto_pilot", {}))
	money.load_save_data(save_data.get("money", {}))
	contract_system.load_save_data(save_data.get("contract_system", {}))

	# Set ship position
	ship.set_ship_position(loaded_ship_pos)

	# Set destination if one exists
	if destination_station != "":
		var dest_pos = map_system.get_station_position(destination_station)
		ship.set_destination(dest_pos)

	print("Game loaded successfully!")
	print("Current station: %s" % current_station)
	print("Destination: %s" % destination_station)
	print("Fuel: %.1f/%.1f" % [auto_pilot.current_fuel, auto_pilot.fuel_capacity])
	print("Money: $%d" % money.current_money)

	return true
