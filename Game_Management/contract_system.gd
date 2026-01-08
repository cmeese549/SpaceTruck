extends Node
class_name ContractSystem

## New Contract System for Space Truck 2D
## Manages contract generation, expiry, and tracking

signal contract_generated(station_name: String, contract: Dictionary)
signal contract_expired(station_name: String, contract: Dictionary)
signal contract_accepted(contract: Dictionary)
signal contract_completed(contract: Dictionary, payment: int)
signal contract_dumped(contract: Dictionary, penalty: int)

# Contract generation settings
const SHORT_RANGE_SLOTS = 2
const MEDIUM_RANGE_SLOTS = 3
const LONG_RANGE_SLOTS = 2
const TOTAL_CONTRACTS_PER_STATION = 7

# Range thresholds (as percentage of fuel capacity)
const SHORT_RANGE_MAX = 0.33
const MEDIUM_RANGE_MAX = 0.66
const LONG_RANGE_MAX = 1.0

# Payment settings (base rate, scales with range)
const BASE_CREDITS_PER_UNIT = 2.0
const CREDITS_PER_CARGO_UNIT = 1.0

# Payment multipliers by range category
const SHORT_RANGE_PAYMENT_MULTIPLIER = 1.0
const MEDIUM_RANGE_PAYMENT_MULTIPLIER = 1.3
const LONG_RANGE_PAYMENT_MULTIPLIER = 1.6

# Contract expiry times (in seconds)
const BASE_EXPIRY_TIMES = [60.0, 120.0, 180.0, 240.0, 300.0, 360.0, 420.0]  # 1-7 minutes

# Station contracts storage
# Structure: { "Station Name": [ {contract}, {contract}, ... ] }
var station_contracts := {}

# Active contracts (accepted by player)
# Array of contract dictionaries
var active_contracts := []

# References (set by main level)
var map_system: MapSystem = null
var auto_pilot: AutoPilot = null


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	# Update contract expiry timers
	check_expired_contracts(delta)


func initialize(map: MapSystem, pilot: AutoPilot) -> void:
	"""Initialize contract system with references"""
	map_system = map
	auto_pilot = pilot
	generate_all_station_contracts()


func generate_all_station_contracts() -> void:
	"""Generate initial contracts for all stations"""
	if not map_system:
		push_error("ContractSystem: MapSystem not set!")
		return

	for station_name in map_system.get_all_station_names():
		generate_station_contracts(station_name)

	print("ContractSystem: Generated contracts for %d stations" % station_contracts.size())


func generate_station_contracts(station_name: String) -> void:
	"""Generate 7 contracts for a station with staggered expiry"""
	if not map_system or not auto_pilot:
		return

	var contracts := []
	var station_pos = map_system.get_station_position(station_name)
	var cross_ring_count = 0  # Track how many contracts go to other ring

	# Generate 2 short range
	for i in SHORT_RANGE_SLOTS:
		var contract = generate_contract(station_name, station_pos, "short", BASE_EXPIRY_TIMES[i], cross_ring_count)
		contracts.append(contract)
		# Check if this contract crosses rings
		if is_cross_ring_contract(station_name, contract.destination_station):
			cross_ring_count += 1

	# Generate 3 medium range
	for i in MEDIUM_RANGE_SLOTS:
		var contract = generate_contract(station_name, station_pos, "medium", BASE_EXPIRY_TIMES[SHORT_RANGE_SLOTS + i], cross_ring_count)
		contracts.append(contract)
		if is_cross_ring_contract(station_name, contract.destination_station):
			cross_ring_count += 1

	# Generate 2 long range
	for i in LONG_RANGE_SLOTS:
		var contract = generate_contract(station_name, station_pos, "long", BASE_EXPIRY_TIMES[SHORT_RANGE_SLOTS + MEDIUM_RANGE_SLOTS + i], cross_ring_count)
		contracts.append(contract)
		if is_cross_ring_contract(station_name, contract.destination_station):
			cross_ring_count += 1

	station_contracts[station_name] = contracts


func generate_contract(origin_station: String, origin_pos: Vector2, range_category: String, expiry_time: float, current_cross_ring_count: int = 0) -> Dictionary:
	"""Generate a single contract based on range category"""
	var destination_station := ""
	var destination_pos := Vector2.ZERO
	var distance := 0.0
	var fuel_required := 0.0
	var origin_ring = map_system.get_station_ring(origin_station)

	# Calculate fuel thresholds
	var short_range_fuel = auto_pilot.fuel_capacity * SHORT_RANGE_MAX
	var medium_range_fuel = auto_pilot.fuel_capacity * MEDIUM_RANGE_MAX
	var long_range_fuel = auto_pilot.fuel_capacity * LONG_RANGE_MAX

	# Find a destination within the range category
	var max_attempts = 50
	var attempts = 0

	while attempts < max_attempts:
		# Pick random destination (not origin)
		var all_stations = map_system.get_all_station_names()
		destination_station = all_stations[randi() % all_stations.size()]

		if destination_station == origin_station:
			attempts += 1
			continue

		# Check cross-ring limit (max 2 contracts to other ring)
		var dest_ring = map_system.get_station_ring(destination_station)
		if origin_ring != dest_ring and current_cross_ring_count >= 2:
			# Already have 2 cross-ring contracts, skip this destination
			attempts += 1
			continue

		destination_pos = map_system.get_station_position(destination_station)
		distance = origin_pos.distance_to(destination_pos)
		fuel_required = distance * auto_pilot.fuel_consumption_rate

		# Check if distance fits the range category
		var fits_range = false
		match range_category:
			"short":
				fits_range = fuel_required > 0 and fuel_required <= short_range_fuel
			"medium":
				fits_range = fuel_required > short_range_fuel and fuel_required <= medium_range_fuel
			"long":
				fits_range = fuel_required > medium_range_fuel

		if fits_range:
			break

		attempts += 1

	# Fallback if no suitable destination found
	if attempts >= max_attempts:
		var all_stations = map_system.get_all_station_names()
		destination_station = all_stations[randi() % all_stations.size()]
		while destination_station == origin_station:
			destination_station = all_stations[randi() % all_stations.size()]
		destination_pos = map_system.get_station_position(destination_station)
		distance = origin_pos.distance_to(destination_pos)
		fuel_required = distance * auto_pilot.fuel_consumption_rate

	# Calculate cargo units (constrained by player capacity, biased toward larger for longer trips)
	var cargo_units = calculate_cargo_units(range_category)

	# Calculate payment
	var payment = calculate_payment(distance, cargo_units, range_category)

	return {
		"origin_station": origin_station,
		"destination_station": destination_station,
		"cargo_units": cargo_units,
		"payment": payment,
		"expiry_time": expiry_time,
		"time_remaining": expiry_time,
		"range_category": range_category,
		"distance": distance,
		"fuel_required": fuel_required
	}


func is_cross_ring_contract(origin_station: String, destination_station: String) -> bool:
	"""Check if a contract crosses between rings"""
	var origin_ring = map_system.get_station_ring(origin_station)
	var dest_ring = map_system.get_station_ring(destination_station)
	return origin_ring != dest_ring


func calculate_cargo_units(range_category: String) -> int:
	"""Calculate cargo units for a contract"""
	var max_cargo = min(auto_pilot.cargo_capacity, 30)  # Cap at 30 for initial range
	var min_cargo = 10

	# Bias toward larger payloads for longer trips
	var bias = 1.0
	match range_category:
		"short":
			bias = 0.8  # Smaller cargo for short trips
		"medium":
			bias = 1.0
		"long":
			bias = 1.2  # 20% bias toward larger cargo

	var base_cargo = randi_range(min_cargo, max_cargo)
	var biased_cargo = int(base_cargo * bias)

	return clamp(biased_cargo, min_cargo, max_cargo)


func calculate_payment(distance: float, cargo_units: int, range_category: String) -> int:
	"""Calculate payment for a contract"""
	# Get multiplier based on range
	var multiplier = SHORT_RANGE_PAYMENT_MULTIPLIER
	match range_category:
		"short":
			multiplier = SHORT_RANGE_PAYMENT_MULTIPLIER
		"medium":
			multiplier = MEDIUM_RANGE_PAYMENT_MULTIPLIER
		"long":
			multiplier = LONG_RANGE_PAYMENT_MULTIPLIER

	var base_payment = distance * BASE_CREDITS_PER_UNIT * multiplier
	var cargo_payment = cargo_units * CREDITS_PER_CARGO_UNIT
	return int(base_payment + cargo_payment)


func check_expired_contracts(delta: float) -> void:
	"""Check and refresh expired contracts"""
	for station_name in station_contracts.keys():
		var contracts = station_contracts[station_name]

		for i in contracts.size():
			contracts[i].time_remaining -= delta

			# Refresh expired contract
			if contracts[i].time_remaining <= 0:
				var old_contract = contracts[i]
				var range_cat = old_contract.range_category
				var expiry = old_contract.expiry_time

				# Count current cross-ring contracts (excluding the one being replaced)
				var cross_ring_count = 0
				for j in contracts.size():
					if j != i and is_cross_ring_contract(station_name, contracts[j].destination_station):
						cross_ring_count += 1

				# Generate replacement
				var station_pos = map_system.get_station_position(station_name)
				var new_contract = generate_contract(station_name, station_pos, range_cat, expiry, cross_ring_count)

				contracts[i] = new_contract
				contract_expired.emit(station_name, old_contract)
				contract_generated.emit(station_name, new_contract)


func get_station_contracts(station_name: String) -> Array:
	"""Get all contracts available at a station"""
	if station_name in station_contracts:
		return station_contracts[station_name]
	return []


func accept_contract(contract: Dictionary) -> bool:
	"""Accept a contract (add to active contracts)"""
	# Check cargo capacity
	var used_cargo = get_used_cargo_space()
	if used_cargo + contract.cargo_units > auto_pilot.cargo_capacity:
		push_warning("Insufficient cargo space!")
		return false

	# Add to active contracts
	active_contracts.append(contract.duplicate())
	contract_accepted.emit(contract)

	# Remove from station's available contracts and generate replacement
	var station_name = contract.origin_station
	if station_name in station_contracts:
		var contracts_list = station_contracts[station_name]

		# Find and remove this specific contract
		for i in contracts_list.size():
			if contracts_list[i].destination_station == contract.destination_station and \
			   contracts_list[i].cargo_units == contract.cargo_units:
				var removed_contract = contracts_list[i]
				contracts_list.remove_at(i)

				# Count current cross-ring contracts (after removal)
				var cross_ring_count = 0
				for remaining_contract in contracts_list:
					if is_cross_ring_contract(station_name, remaining_contract.destination_station):
						cross_ring_count += 1

				# Generate replacement contract with same range and expiry time
				var station_pos = map_system.get_station_position(station_name)
				var new_contract = generate_contract(
					station_name,
					station_pos,
					removed_contract.range_category,
					removed_contract.expiry_time,
					cross_ring_count
				)
				contracts_list.append(new_contract)
				contract_generated.emit(station_name, new_contract)
				break

	print("Contract accepted: %s -> %s (%d units, $%d)" % [
		contract.origin_station,
		contract.destination_station,
		contract.cargo_units,
		contract.payment
	])

	return true


func complete_contracts_at_station(station_name: String, money_system: Money) -> Array:
	"""Complete all contracts with this destination and return payments"""
	var completed := []
	var i = 0

	while i < active_contracts.size():
		var contract = active_contracts[i]

		if contract.destination_station == station_name:
			# Complete contract
			money_system.make_money(contract.payment)
			completed.append(contract)
			contract_completed.emit(contract, contract.payment)

			print("Contract completed: $%d paid for %d units to %s" % [
				contract.payment,
				contract.cargo_units,
				contract.destination_station
			])

			# Remove from active contracts
			active_contracts.remove_at(i)
		else:
			i += 1

	return completed


func dump_contract(contract_index: int, current_station: String, money_system: Money) -> int:
	"""Dump a contract and pay penalty"""
	if contract_index < 0 or contract_index >= active_contracts.size():
		return 0

	var contract = active_contracts[contract_index]

	# Calculate penalty (based on distance from current position to destination)
	var current_pos = map_system.get_station_position(current_station)
	var dest_pos = map_system.get_station_position(contract.destination_station)
	var distance_remaining = current_pos.distance_to(dest_pos)
	var total_distance = contract.distance
	var completion_ratio = 1.0 - (distance_remaining / total_distance) if total_distance > 0 else 0.0
	var penalty = int(contract.payment * completion_ratio)

	# Deduct penalty
	money_system.try_buy(penalty)

	# Remove contract
	active_contracts.remove_at(contract_index)
	contract_dumped.emit(contract, penalty)

	print("Contract dumped: %s. Penalty: $%d" % [contract.destination_station, penalty])

	return penalty


func get_active_contracts() -> Array:
	"""Get all active contracts"""
	return active_contracts


func get_used_cargo_space() -> int:
	"""Get total cargo space used by active contracts"""
	var total = 0
	for contract in active_contracts:
		total += contract.cargo_units
	return total


func get_contracts_to_station(station_name: String) -> Array:
	"""Get all active contracts going to a specific station"""
	var matching := []
	for contract in active_contracts:
		if contract.destination_station == station_name:
			matching.append(contract)
	return matching


func get_save_data() -> Dictionary:
	"""Get save data for ContractSystem"""
	return {
		"station_contracts": station_contracts,
		"active_contracts": active_contracts
	}


func load_save_data(data: Dictionary) -> void:
	"""Load save data for ContractSystem"""
	station_contracts = data.get("station_contracts", {})
	active_contracts = data.get("active_contracts", [])
