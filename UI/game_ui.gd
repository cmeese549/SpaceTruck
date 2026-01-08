extends CanvasLayer
class_name GameUI

## Main UI system for Space Truck 2D
## Manages tabbed panel with Station/Contracts/Ship tabs

signal refuel_requested
signal upgrade_speed_requested
signal upgrade_fuel_capacity_requested
signal upgrade_cargo_capacity_requested
signal contract_accepted(contract: Dictionary)
signal contract_dumped(contract_index: int)
signal set_destination_requested(station_name: String)
signal start_flight_requested
signal stop_flight_requested
signal new_game_requested

# UI State
enum Tab { STATION, CONTRACTS, SHIP }
var current_tab: Tab = Tab.STATION
var is_collapsed := false
var selected_station := ""  # Station selected on map (not necessarily current)
var hovered_contract_destination := ""  # Destination being hovered over in contracts

# References (set by main level)
var main_level: MainLevel2D = null

# UI Node references
@onready var panel_container: PanelContainer = $Control/PanelContainer
@onready var tab_buttons: HBoxContainer = $Control/PanelContainer/VBoxContainer/TabButtons
@onready var station_tab_button: Button = $Control/PanelContainer/VBoxContainer/TabButtons/StationTab
@onready var contracts_tab_button: Button = $Control/PanelContainer/VBoxContainer/TabButtons/ContractsTab
@onready var ship_tab_button: Button = $Control/PanelContainer/VBoxContainer/TabButtons/ShipTab
@onready var collapse_button: Button = $Control/CollapseButton

@onready var tab_content: Control = $Control/PanelContainer/VBoxContainer/TabContent

# Tab panels
@onready var station_panel: Control = $Control/PanelContainer/VBoxContainer/TabContent/StationPanel
@onready var contracts_panel: Control = $Control/PanelContainer/VBoxContainer/TabContent/ContractsPanel
@onready var ship_panel: Control = $Control/PanelContainer/VBoxContainer/TabContent/ShipPanel

# Top bar labels
@onready var top_bar_money: Label = $Control/TopBar/HBoxContainer/MoneyLabel
@onready var top_bar_fuel: Label = $Control/TopBar/HBoxContainer/FuelLabel
@onready var top_bar_destination: Label = $Control/TopBar/HBoxContainer/DestinationLabel
@onready var top_bar_eta: Label = $Control/TopBar/HBoxContainer/ETALabel


func _ready() -> void:
	# Connect tab buttons
	station_tab_button.pressed.connect(_on_station_tab_pressed)
	contracts_tab_button.pressed.connect(_on_contracts_tab_pressed)
	ship_tab_button.pressed.connect(_on_ship_tab_pressed)
	collapse_button.pressed.connect(_on_collapse_pressed)

	# Connect station panel buttons
	station_panel.get_node("ScrollContainer/VBoxContainer/RefuelButton").pressed.connect(_on_refuel_pressed)
	station_panel.get_node("ScrollContainer/VBoxContainer/UpgradeSpeedButton").pressed.connect(_on_upgrade_speed_pressed)
	station_panel.get_node("ScrollContainer/VBoxContainer/UpgradeFuelButton").pressed.connect(_on_upgrade_fuel_pressed)
	station_panel.get_node("ScrollContainer/VBoxContainer/UpgradeCargoButton").pressed.connect(_on_upgrade_cargo_pressed)
	station_panel.get_node("ScrollContainer/VBoxContainer/SetDestinationButton").pressed.connect(_on_set_destination_pressed)

	# Connect ship panel buttons
	ship_panel.get_node("VBoxContainer/FlightButton").pressed.connect(_on_flight_button_pressed)
	ship_panel.get_node("VBoxContainer/NewGameButton").pressed.connect(_on_new_game_pressed)

	# Start with station tab
	switch_to_tab(Tab.STATION)


func _process(_delta: float) -> void:
	# Only update labels that change frequently (not buttons!)
	if main_level:
		# Always update top bar
		update_top_bar()

		# Update active tab
		if current_tab == Tab.SHIP:
			update_ship_panel_realtime()
		elif current_tab == Tab.STATION:
			update_station_contracts_realtime()
		elif current_tab == Tab.CONTRACTS:
			update_active_contracts_realtime()


func initialize(level: MainLevel2D) -> void:
	"""Initialize UI with reference to main level"""
	main_level = level
	update_ui()  # Initial update


func update_ui() -> void:
	"""Update all UI elements - call this when game state changes, NOT every frame"""
	if not main_level:
		return

	var is_docked = not main_level.is_traveling() and main_level.destination_station == ""
	var current_station = main_level.current_station

	# Update tab visibility
	update_station_tab_visibility()

	# Update current tab content
	match current_tab:
		Tab.STATION:
			update_station_panel(current_station, is_docked)
		Tab.CONTRACTS:
			update_contracts_panel()
		Tab.SHIP:
			update_ship_panel()


func update_ship_panel_realtime() -> void:
	"""Update only the real-time changing values in ship panel (called every frame)"""
	if not main_level or current_tab != Tab.SHIP:
		return

	var vbox = ship_panel.get_node("VBoxContainer")
	var fuel_bar = vbox.get_node("FuelBar")
	var fuel_label = vbox.get_node("FuelLabel")
	var progress_bar = vbox.get_node("ProgressBar")
	var progress_label = vbox.get_node("ProgressLabel")

	# Update fuel
	var fuel_info = main_level.auto_pilot.get_fuel_info()
	fuel_bar.value = fuel_info.percentage
	fuel_label.text = "Fuel: %.0f / %.0f (%.0f%%)" % [
		fuel_info.current,
		fuel_info.capacity,
		fuel_info.percentage
	]

	# Update progress if traveling
	if main_level.destination_station != "":
		var journey = main_level.auto_pilot.get_journey_info()
		if progress_bar.visible:
			progress_bar.value = journey.progress * 100
			progress_label.text = "Progress: %.0f%%" % (journey.progress * 100)


func update_station_contracts_realtime() -> void:
	"""Update contract expiry times in station panel (called every frame)"""
	if not main_level or current_tab != Tab.STATION:
		return

	var vbox = station_panel.get_node("ScrollContainer/VBoxContainer")
	var contracts_container = vbox.get_node("ContractsContainer")

	# Get current station (could be viewing remote station)
	var station_name = selected_station if selected_station != "" else main_level.current_station
	var contracts = main_level.contract_system.get_station_contracts(station_name)

	# Update button text for each contract
	var button_index = 0
	for child in contracts_container.get_children():
		if child is Button and button_index < contracts.size():
			var contract = contracts[button_index]
			var range_icon = {"short": "●", "medium": "●●", "long": "●●●"}[contract.range_category]
			var time_left = int(contract.time_remaining)
			var minutes = time_left / 60
			var seconds = time_left % 60

			# Calculate $ per fuel and flight time
			var dollars_per_fuel = contract.payment / contract.fuel_required if contract.fuel_required > 0 else 0
			var flight_time = contract.fuel_required / main_level.auto_pilot.ship_speed  # distance = fuel needed
			var flight_minutes = int(flight_time / 60)
			var flight_seconds = int(flight_time) % 60

			child.text = "%s %s -> %s\n%d cargo | $%d | %.0f fuel | $%.1f/fuel | %d:%02ds | Expires: %d:%02d" % [
				range_icon,
				contract.origin_station,
				contract.destination_station,
				contract.cargo_units,
				contract.payment,
				contract.fuel_required,
				dollars_per_fuel,
				flight_minutes,
				flight_seconds,
				minutes,
				seconds
			]
			button_index += 1


func update_active_contracts_realtime() -> void:
	"""Update active contract expiry times in contracts panel (called every frame)"""
	if not main_level or current_tab != Tab.CONTRACTS:
		return

	var vbox = contracts_panel.get_node("ScrollContainer/VBoxContainer")
	var contracts_container = vbox.get_node("ContractsContainer")
	var active_contracts = main_level.contract_system.get_active_contracts()

	# Update each contract panel's details label
	var panel_index = 0
	for child in contracts_container.get_children():
		if child is PanelContainer and panel_index < active_contracts.size():
			var contract = active_contracts[panel_index]
			var hbox = child.get_child(0)  # HBoxContainer
			var info = hbox.get_child(0)   # VBoxContainer with contract info

			# Find the details label (second child after destination label)
			if info.get_child_count() >= 2:
				var details_label = info.get_child(1)
				if details_label is Label:
					var time_left = int(contract.time_remaining)
					var minutes = time_left / 60
					var seconds = time_left % 60

					details_label.text = "%d cargo | $%d | Expires: %d:%02d" % [
						contract.cargo_units,
						contract.payment,
						minutes,
						seconds
					]
			panel_index += 1


func update_station_tab_visibility() -> void:
	"""Show/hide station tab based on game state"""
	var is_actually_traveling = main_level.is_traveling()

	if not is_actually_traveling:
		# Show station tab when not traveling (docked or destination set but not flying)
		station_tab_button.visible = true
	elif selected_station != "":
		# Show station tab when a station is selected (even while traveling)
		station_tab_button.visible = true
	else:
		# Hide station tab when traveling with no selection
		station_tab_button.visible = false
		if current_tab == Tab.STATION:
			switch_to_tab(Tab.CONTRACTS)


func update_station_panel(current_station: String, is_docked: bool) -> void:
	"""Update the station panel content"""
	var vbox = station_panel.get_node("ScrollContainer/VBoxContainer")
	var header = vbox.get_node("StationHeader")
	var status = vbox.get_node("StatusLabel")
	var refuel_btn = vbox.get_node("RefuelButton")
	var upgrade_speed_btn = vbox.get_node("UpgradeSpeedButton")
	var upgrade_fuel_btn = vbox.get_node("UpgradeFuelButton")
	var upgrade_cargo_btn = vbox.get_node("UpgradeCargoButton")
	var set_dest_btn = vbox.get_node("SetDestinationButton")
	var contracts_container = vbox.get_node("ContractsContainer")

	# Check if we're viewing a remote station (different from current)
	var viewing_remote_station = selected_station != "" and selected_station != current_station

	if is_docked and not viewing_remote_station:
		# Docked at station - full functionality
		header.text = "Station: %s" % current_station
		status.text = "Docked"

		# Update refuel button
		var fuel_needed = main_level.auto_pilot.fuel_capacity - main_level.auto_pilot.current_fuel
		var base_refuel_cost = fuel_needed * 1.5
		var refuel_cost = int(base_refuel_cost * 2.0 if main_level.money.is_in_debt() else base_refuel_cost)

		refuel_btn.visible = true
		if main_level.money.is_in_debt():
			refuel_btn.text = "Refuel ($%d for %.0f fuel) [2x DEBT]" % [refuel_cost, fuel_needed]
		else:
			refuel_btn.text = "Refuel ($%d for %.0f fuel)" % [refuel_cost, fuel_needed]
		refuel_btn.disabled = fuel_needed <= 0

		# Update upgrade buttons (disabled when in debt)
		var in_debt = main_level.money.is_in_debt()

		upgrade_speed_btn.visible = true
		var speed_cost = int(main_level.auto_pilot.ship_speed * 50)
		if in_debt:
			upgrade_speed_btn.text = "Upgrade Speed [DISABLED: IN DEBT]"
			upgrade_speed_btn.disabled = true
		else:
			upgrade_speed_btn.text = "Upgrade Speed ($%d) +5 u/s" % speed_cost
			upgrade_speed_btn.disabled = main_level.money.current_money < speed_cost

		upgrade_fuel_btn.visible = true
		var fuel_cost = int(main_level.auto_pilot.fuel_capacity * 0.5)
		if in_debt:
			upgrade_fuel_btn.text = "Upgrade Fuel Cap [DISABLED: IN DEBT]"
			upgrade_fuel_btn.disabled = true
		else:
			upgrade_fuel_btn.text = "Upgrade Fuel Cap ($%d) +100" % fuel_cost
			upgrade_fuel_btn.disabled = main_level.money.current_money < fuel_cost

		upgrade_cargo_btn.visible = true
		var cargo_cost = main_level.auto_pilot.cargo_capacity * 10
		if in_debt:
			upgrade_cargo_btn.text = "Upgrade Cargo Cap [DISABLED: IN DEBT]"
			upgrade_cargo_btn.disabled = true
		else:
			upgrade_cargo_btn.text = "Upgrade Cargo Cap ($%d) +10" % cargo_cost
			upgrade_cargo_btn.disabled = main_level.money.current_money < cargo_cost

		# Hide set destination button when docked
		set_dest_btn.visible = false

		# Show available contracts
		update_station_contracts(contracts_container, current_station, true)

	elif viewing_remote_station:
		# Viewing a remote station (different from current)
		header.text = "Station: %s" % selected_station
		var distance = main_level.map_system.get_station_position(current_station).distance_to(
			main_level.map_system.get_station_position(selected_station)
		)
		var fuel_required = distance * main_level.auto_pilot.fuel_consumption_rate

		status.text = "Distance: %.0f units | Fuel: %.0f" % [distance, fuel_required]

		# Hide service buttons
		refuel_btn.visible = false
		upgrade_speed_btn.visible = false
		upgrade_fuel_btn.visible = false
		upgrade_cargo_btn.visible = false

		# Show set destination button
		set_dest_btn.visible = true
		var has_enough_fuel = main_level.auto_pilot.current_fuel >= fuel_required
		set_dest_btn.disabled = not has_enough_fuel
		if has_enough_fuel:
			set_dest_btn.text = "Set as Destination"
		else:
			set_dest_btn.text = "Insufficient Fuel"

		# Show contracts (read-only preview)
		update_station_contracts(contracts_container, selected_station, false)


func update_station_contracts(container: VBoxContainer, station_name: String, allow_accept: bool) -> void:
	"""Update the list of contracts at a station"""
	# Clear existing contract buttons
	for child in container.get_children():
		child.queue_free()

	var contracts = main_level.contract_system.get_station_contracts(station_name)

	if contracts.size() == 0:
		var label = Label.new()
		label.text = "No contracts available"
		container.add_child(label)
		return

	# Add header
	var header = Label.new()
	header.text = "\nAvailable Contracts:"
	header.add_theme_font_size_override("font_size", 16)
	container.add_child(header)

	# Add contract buttons
	for contract in contracts:
		var btn = Button.new()
		var range_icon = {"short": "●", "medium": "●●", "long": "●●●"}[contract.range_category]
		var time_left = int(contract.time_remaining)
		var minutes = time_left / 60
		var seconds = time_left % 60

		# Calculate $ per fuel and flight time
		var dollars_per_fuel = contract.payment / contract.fuel_required if contract.fuel_required > 0 else 0
		var flight_time = contract.fuel_required / main_level.auto_pilot.ship_speed  # distance = fuel needed
		var flight_minutes = int(flight_time / 60)
		var flight_seconds = int(flight_time) % 60

		btn.text = "%s %s -> %s\n%d cargo | $%d | %.0f fuel | $%.1f/fuel | %d:%02ds | Expires: %d:%02d" % [
			range_icon,
			contract.origin_station,
			contract.destination_station,
			contract.cargo_units,
			contract.payment,
			contract.fuel_required,
			dollars_per_fuel,
			flight_minutes,
			flight_seconds,
			minutes,
			seconds
		]

		# Set minimum size and ensure button can receive mouse input
		btn.custom_minimum_size = Vector2(0, 60)
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.focus_mode = Control.FOCUS_ALL

		# Add hover highlighting for contract destination
		var dest_name = contract.destination_station
		btn.mouse_entered.connect(func(): _on_contract_hover_enter(dest_name))
		btn.mouse_exited.connect(func(): _on_contract_hover_exit())

		if allow_accept:
			# Check if player can accept
			var cargo_space = main_level.auto_pilot.cargo_capacity - main_level.contract_system.get_used_cargo_space()
			btn.disabled = contract.cargo_units > cargo_space

			if not btn.disabled:
				# Create a captured reference to avoid issues with loop variable
				var contract_copy = contract.duplicate()
				btn.pressed.connect(func(): _on_contract_accepted(contract_copy))
		else:
			btn.disabled = true

		container.add_child(btn)


func update_contracts_panel() -> void:
	"""Update the contracts tab"""
	var vbox = contracts_panel.get_node("ScrollContainer/VBoxContainer")
	var header = vbox.get_node("Header")
	var contracts_container = vbox.get_node("ContractsContainer")

	# Update header
	var cargo_used = main_level.contract_system.get_used_cargo_space()
	var cargo_max = main_level.auto_pilot.cargo_capacity
	header.text = "Active Contracts (%d/%d cargo)" % [cargo_used, cargo_max]

	# Clear existing contract items
	for child in contracts_container.get_children():
		child.queue_free()

	var active_contracts = main_level.contract_system.get_active_contracts()

	if active_contracts.size() == 0:
		var label = Label.new()
		label.text = "No active contracts"
		contracts_container.add_child(label)
		return

	# Add active contracts
	for i in active_contracts.size():
		var contract = active_contracts[i]
		var panel = PanelContainer.new()
		var hbox = HBoxContainer.new()

		# Contract info
		var info = VBoxContainer.new()
		var dest_label = Label.new()
		dest_label.text = "To: %s" % contract.destination_station
		dest_label.add_theme_font_size_override("font_size", 16)

		var details = Label.new()
		var credits_per_fuel = contract.payment / contract.fuel_required if contract.fuel_required > 0 else 0
		details.text = "Cargo: %d units | Payment: $%d | Credits/fuel: %.1f" % [
			contract.cargo_units,
			contract.payment,
			credits_per_fuel
		]

		info.add_child(dest_label)
		info.add_child(details)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# Buttons
		var buttons = VBoxContainer.new()

		var select_btn = Button.new()
		select_btn.text = "Set Destination"
		select_btn.custom_minimum_size = Vector2(120, 0)
		select_btn.pressed.connect(func(): _on_contract_selected(contract))

		var dump_btn = Button.new()
		dump_btn.text = "Dump (Penalty)"
		dump_btn.pressed.connect(func(): _on_contract_dump_requested(i))

		buttons.add_child(select_btn)
		buttons.add_child(dump_btn)

		hbox.add_child(info)
		hbox.add_child(buttons)
		panel.add_child(hbox)

		# Add hover highlighting for contract destination
		var dest_name = contract.destination_station
		panel.mouse_entered.connect(func(): _on_contract_hover_enter(dest_name))
		panel.mouse_exited.connect(func(): _on_contract_hover_exit())

		contracts_container.add_child(panel)


func update_ship_panel() -> void:
	"""Update the ship tab"""
	var vbox = ship_panel.get_node("VBoxContainer")
	var fuel_bar = vbox.get_node("FuelBar")
	var fuel_label = vbox.get_node("FuelLabel")
	var speed_label = vbox.get_node("SpeedLabel")
	var cargo_label = vbox.get_node("CargoLabel")
	var dest_label = vbox.get_node("DestinationLabel")
	var progress_bar = vbox.get_node("ProgressBar")
	var progress_label = vbox.get_node("ProgressLabel")
	var flight_btn = vbox.get_node("FlightButton")

	# Fuel
	var fuel_info = main_level.auto_pilot.get_fuel_info()
	fuel_bar.value = fuel_info.percentage
	fuel_label.text = "Fuel: %.0f / %.0f (%.0f%%)" % [
		fuel_info.current,
		fuel_info.capacity,
		fuel_info.percentage
	]

	# Stats
	speed_label.text = "Speed: %.1f units/sec" % main_level.auto_pilot.ship_speed
	var cargo_used = main_level.contract_system.get_used_cargo_space()
	cargo_label.text = "Cargo Capacity: %d / %d units" % [cargo_used, main_level.auto_pilot.cargo_capacity]

	# Journey info
	if main_level.is_traveling():
		var journey = main_level.auto_pilot.get_journey_info()
		dest_label.text = "Destination: %s" % main_level.destination_station
		progress_bar.visible = true
		progress_bar.value = journey.progress * 100
		progress_label.visible = true
		progress_label.text = "Progress: %.0f%%" % (journey.progress * 100)
		flight_btn.text = "Stop Flight"
		flight_btn.disabled = false
	elif main_level.destination_station != "":
		# Destination set but not traveling - show progress and check fuel
		dest_label.text = "Destination: %s" % main_level.destination_station

		# Keep progress bar visible showing current progress
		var journey = main_level.auto_pilot.get_journey_info()
		progress_bar.visible = true
		progress_bar.value = journey.progress * 100
		progress_label.visible = true
		progress_label.text = "Progress: %.0f%% (Stopped)" % (journey.progress * 100)

		# Calculate fuel needed for the journey
		var current_pos = main_level.ship.global_position
		var dest_pos = main_level.map_system.get_station_position(main_level.destination_station)
		var distance = current_pos.distance_to(dest_pos)
		var fuel_needed = distance * main_level.auto_pilot.fuel_consumption_rate
		var has_enough_fuel = main_level.auto_pilot.current_fuel >= fuel_needed

		if has_enough_fuel:
			flight_btn.text = "Start Flight"
			flight_btn.disabled = false
		else:
			flight_btn.text = "Insufficient Fuel"
			flight_btn.disabled = true
	else:
		dest_label.text = "Destination: None"
		progress_bar.visible = false
		progress_label.visible = false
		flight_btn.text = "Start Flight"
		flight_btn.disabled = true


# Tab switching
func switch_to_tab(tab: Tab) -> void:
	"""Switch to a specific tab"""
	current_tab = tab

	# Update button states
	station_tab_button.button_pressed = (tab == Tab.STATION)
	contracts_tab_button.button_pressed = (tab == Tab.CONTRACTS)
	ship_tab_button.button_pressed = (tab == Tab.SHIP)

	# Show/hide panels
	station_panel.visible = (tab == Tab.STATION)
	contracts_panel.visible = (tab == Tab.CONTRACTS)
	ship_panel.visible = (tab == Tab.SHIP)

	# Update the content of the newly shown tab
	update_ui()


func _on_station_tab_pressed() -> void:
	switch_to_tab(Tab.STATION)


func _on_contracts_tab_pressed() -> void:
	switch_to_tab(Tab.CONTRACTS)


func _on_ship_tab_pressed() -> void:
	switch_to_tab(Tab.SHIP)


func _on_collapse_pressed() -> void:
	is_collapsed = not is_collapsed
	collapse_button.text = ">" if is_collapsed else "<"

	# Animate the panel sliding in/out (button stays fixed at right edge)
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)

	if is_collapsed:
		# Slide panel out to the right (600px is panel width)
		tween.parallel().tween_property(panel_container, "offset_left", 0.0, 0.3)
		tween.parallel().tween_property(panel_container, "offset_right", 600.0, 0.3)
		tween.parallel().tween_property(panel_container, "modulate:a", 0.0, 0.3)
	else:
		# Slide panel in from the right
		tween.parallel().tween_property(panel_container, "offset_left", -600.0, 0.3)
		tween.parallel().tween_property(panel_container, "offset_right", 0.0, 0.3)
		tween.parallel().tween_property(panel_container, "modulate:a", 1.0, 0.3)


# Signal handlers
func _on_refuel_pressed() -> void:
	refuel_requested.emit()


func _on_upgrade_speed_pressed() -> void:
	upgrade_speed_requested.emit()


func _on_upgrade_fuel_pressed() -> void:
	upgrade_fuel_capacity_requested.emit()


func _on_upgrade_cargo_pressed() -> void:
	upgrade_cargo_capacity_requested.emit()


func _on_set_destination_pressed() -> void:
	if selected_station != "":
		set_destination_requested.emit(selected_station)


func _on_contract_accepted(contract: Dictionary) -> void:
	print("UI: Contract button clicked - %s to %s" % [contract.origin_station, contract.destination_station])
	contract_accepted.emit(contract)
	# Refresh UI immediately to remove the button
	update_ui()


func _on_contract_selected(contract: Dictionary) -> void:
	# Set this contract's destination as the ship's destination
	set_destination_requested.emit(contract.destination_station)
	# Also switch to Ship tab to show flight controls
	switch_to_tab(Tab.SHIP)


func _on_contract_dump_requested(contract_index: int) -> void:
	contract_dumped.emit(contract_index)
	# Refresh UI immediately to update contract list
	update_ui()


func _on_flight_button_pressed() -> void:
	if main_level.is_traveling():
		stop_flight_requested.emit()
	else:
		start_flight_requested.emit()


func _on_new_game_pressed() -> void:
	new_game_requested.emit()


# External events
func on_station_clicked(station_name: String) -> void:
	"""Called when a station is clicked on the map"""
	# Clear selected_station if clicking current station to show services
	if station_name == main_level.current_station:
		selected_station = ""
	else:
		selected_station = station_name
	switch_to_tab(Tab.STATION)
	if is_collapsed:
		_on_collapse_pressed()  # Expand panel
	update_ui()


func on_docked() -> void:
	"""Called when ship docks at a station"""
	selected_station = ""
	switch_to_tab(Tab.STATION)
	if is_collapsed:
		_on_collapse_pressed()  # Expand panel
	update_ui()


func update_top_bar() -> void:
	"""Update top status bar (called every frame)"""
	if not main_level:
		return

	# Update money
	top_bar_money.text = "Money: $%d" % main_level.money.current_money

	# Update fuel
	var fuel_info = main_level.auto_pilot.get_fuel_info()
	top_bar_fuel.text = "Fuel: %.0f / %.0f (%.0f%%)" % [
		fuel_info.current,
		fuel_info.capacity,
		fuel_info.percentage
	]

	# Update destination and ETA
	if main_level.destination_station != "":
		top_bar_destination.text = "Destination: %s" % main_level.destination_station

		# Calculate ETA
		var journey = main_level.auto_pilot.get_journey_info()
		if journey.is_traveling:
			var remaining_time = journey.duration * (1.0 - journey.progress)
			var minutes = int(remaining_time / 60.0)
			var seconds = int(remaining_time) % 60
			top_bar_eta.text = "ETA: %d:%02d" % [minutes, seconds]
		else:
			top_bar_eta.text = "ETA: Ready"
	else:
		top_bar_destination.text = "Destination: None"
		top_bar_eta.text = "ETA: --"


func _on_contract_hover_enter(destination: String) -> void:
	"""Called when mouse enters a contract button/panel"""
	hovered_contract_destination = destination
	main_level.map_system.set_contract_hover_destination(destination)


func _on_contract_hover_exit() -> void:
	"""Called when mouse exits a contract button/panel"""
	hovered_contract_destination = ""
	main_level.map_system.set_contract_hover_destination("")
