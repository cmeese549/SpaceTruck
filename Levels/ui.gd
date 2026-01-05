extends Control

@onready var station_panel = $StationPanel
@onready var journey_panel = $JourneyPanel
@onready var progress_bar = $JourneyPanel/MarginContainer/VBox/ProgressBar
@onready var progress_label = $JourneyPanel/MarginContainer/VBox/ProgressLabel

# Station interface elements
@onready var station_label = $StationPanel/MarginContainer/VBox/StationLabel
@onready var money_label = $StationPanel/MarginContainer/VBox/ShipStatus/MoneyLabel
@onready var fuel_label = $StationPanel/MarginContainer/VBox/ShipStatus/FuelLabel
@onready var contracts_container = $StationPanel/MarginContainer/VBox/Contracts
@onready var refuel_button = $StationPanel/MarginContainer/VBox/Services/RefuelButton
@onready var speed_upgrade_button = $StationPanel/MarginContainer/VBox/Services/SpeedUpgradeButton
@onready var fuel_upgrade_button = $StationPanel/MarginContainer/VBox/Services/FuelUpgradeButton

@onready var wallet_label : Label = $MoneyPanel/MarginContainer/Label
@onready var money : Money = $"../Money"

var main_scene: Node3D
var current_station_name: String = ""
var contract_buttons = []

# Fixed prices
var fuel_price_per_unit: float = 1.5

func _ready():
	main_scene = get_node("../")
	
	# Connect service buttons
	refuel_button.pressed.connect(_on_refuel_pressed)
	speed_upgrade_button.pressed.connect(_on_speed_upgrade_pressed)
	fuel_upgrade_button.pressed.connect(_on_fuel_upgrade_pressed)
	Events.made_money.connect(update_wallet_label)
	Events.spent_money.connect(update_wallet_label)
	update_wallet_label(0)
	# Connect to autopilot signals
	var autopilot = get_node("../AutoPilot")
	if autopilot:
		autopilot.progress_updated.connect(_on_progress_updated)
		autopilot.journey_completed.connect(_on_journey_completed)
		
func update_wallet_label(_change_anoumt: int):
	wallet_label.text = "$" + str(money.current_money)

func show_station_interface(station_name: String):
	"""Display and update station interface"""
	current_station_name = station_name
	station_panel.visible = true
	journey_panel.visible = false
	station_label.text = "Station: " + station_name
	
	update_ship_status()
	update_available_contracts()
	update_station_services()

func update_ship_status():
	"""Update ship status labels"""
	var autopilot = get_node("../AutoPilot")
	var money = get_node("../Money")
	
	if autopilot and money:
		var fuel_info = autopilot.get_fuel_info()
		money_label.text = "Credits: " + str(money.current_money)
		fuel_label.text = "Fuel: %.1f/%.1f (%.0f%%)" % [fuel_info.current, fuel_info.capacity, fuel_info.percentage]

func update_available_contracts():
	"""Update contract buttons"""
	# Clear existing contract buttons
	for button in contract_buttons:
		if button:
			button.queue_free()
	contract_buttons.clear()
	
	var space_env = get_node("../SpaceEnvironment")
	var autopilot = get_node("../AutoPilot")
	var contracts = get_node("../Contracts")
	
	if not space_env or not autopilot or not contracts:
		return
	
	var station_names = space_env.get_station_names()
	
	for dest_name in station_names:
		if dest_name == current_station_name:
			continue
			
		# Calculate journey info
		var from_pos = space_env.station_positions[current_station_name]
		var to_pos = space_env.station_positions[dest_name]
		var distance = from_pos.distance_to(to_pos)
		var fuel_cost = distance * autopilot.fuel_consumption_rate
		var payment_info = contracts.get_estimated_payment(current_station_name, dest_name, distance)
		
		# Create contract button
		var contract_button = Button.new()
		var bonus_text = " (+DISCOVERY)" if payment_info.first_visit else ""
		contract_button.text = "%s\nPay: %d credits | Fuel: %.1f%s" % [dest_name, payment_info.total, fuel_cost, bonus_text]
		contract_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		# Enable/disable based on fuel availability
		var can_travel = autopilot.can_make_journey(current_station_name, dest_name)
		contract_button.disabled = not can_travel
		if not can_travel:
			contract_button.text += " (INSUFFICIENT FUEL)"
		
		contract_button.pressed.connect(_on_contract_selected.bind(dest_name))
		contracts_container.add_child(contract_button)
		contract_buttons.append(contract_button)

func update_station_services():
	"""Update service buttons"""
	var autopilot = get_node("../AutoPilot")
	var money = get_node("../Money")
	
	if not autopilot or not money:
		return
	
	# Update refuel button
	var fuel_info = autopilot.get_fuel_info()
	var fuel_needed = fuel_info.capacity - fuel_info.current
	var refuel_cost = roundi(fuel_needed * fuel_price_per_unit)
	
	if fuel_needed > 0:
		refuel_button.text = "Refuel (%.1f units for %d credits)" % [fuel_needed, refuel_cost]
		refuel_button.disabled = not money.check_can_buy(refuel_cost)
	else:
		refuel_button.text = "Fuel Tank Full"
		refuel_button.disabled = true
	
	# Update speed upgrade button
	var speed_cost = roundi(autopilot.ship_speed * 50)
	speed_upgrade_button.text = "Upgrade Speed (+5 u/s) - %d credits" % speed_cost
	speed_upgrade_button.disabled = not money.check_can_buy(speed_cost)
	
	# Update fuel capacity upgrade button
	var fuel_cost = roundi(autopilot.fuel_capacity * 0.5)
	fuel_upgrade_button.text = "Upgrade Fuel Capacity (+100 units) - %d credits" % fuel_cost
	fuel_upgrade_button.disabled = not money.check_can_buy(fuel_cost)

func _on_contract_selected(destination: String):
	"""Handle contract selection"""
	main_scene.start_journey_to(destination)

func _on_refuel_pressed():
	"""Handle refuel purchase"""
	var autopilot = get_node("../AutoPilot")
	var money = get_node("../Money")
	
	if autopilot and money:
		var fuel_info = autopilot.get_fuel_info()
		var fuel_needed = fuel_info.capacity - fuel_info.current
		var cost = roundi(fuel_needed * fuel_price_per_unit)
		
		if money.try_buy(cost):
			autopilot.refuel(fuel_needed)
			update_ship_status()
			update_station_services()
			update_available_contracts()

func _on_speed_upgrade_pressed():
	"""Handle speed upgrade purchase"""
	var autopilot = get_node("../AutoPilot")
	var money = get_node("../Money")
	var cost = roundi(autopilot.ship_speed * 50)
	
	if autopilot and money and money.try_buy(cost):
		autopilot.upgrade_speed(autopilot.ship_speed + 5.0)
		update_station_services()
		update_available_contracts()

func _on_fuel_upgrade_pressed():
	"""Handle fuel capacity upgrade purchase"""
	var autopilot = get_node("../AutoPilot")
	var money = get_node("../Money")
	var cost = roundi(autopilot.fuel_capacity * 0.5)
	
	if autopilot and money and money.try_buy(cost):
		autopilot.upgrade_fuel_capacity(autopilot.fuel_capacity + 100.0)
		update_ship_status()
		update_station_services()
		update_available_contracts()

func hide_station_interface():
	"""Hide station interface and show journey panel"""
	station_panel.visible = false
	journey_panel.visible = true
	progress_bar.value = 0
	progress_label.text = "Departing..."

func _on_progress_updated(progress: float):
	"""Update journey progress display"""
	progress_bar.value = progress * 100
	var percentage = int(progress * 100)
	progress_label.text = "Journey Progress: " + str(percentage) + "%"

func _on_journey_completed():
	"""Hide journey panel when journey completes"""
	journey_panel.visible = false
