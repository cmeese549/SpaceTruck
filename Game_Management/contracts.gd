extends Node
class_name Contracts

# Payment settings
@export var credits_per_unit: float = 2.0
@export var discovery_bonus: float = 50.0

# Discovery tracking
var discovered_stations = {}

signal payment_completed(amount: float, breakdown: Dictionary)

func _ready():
	pass

func calculate_payment(from_station: String, to_station: String, distance: float) -> Dictionary:
	"""Calculate payment for a journey"""
	var base_payment = distance * credits_per_unit
	var bonus_payment = 0.0
	var payment_breakdown = {
		"base": base_payment,
		"discovery": 0.0,
		"total": base_payment,
		"first_visit": false
	}
	
	# Discovery bonus for first visit
	if not discovered_stations.has(to_station):
		discovered_stations[to_station] = true
		bonus_payment = discovery_bonus
		payment_breakdown.discovery = bonus_payment
		payment_breakdown.first_visit = true
	
	payment_breakdown.total = roundi(base_payment + bonus_payment)
	return payment_breakdown

func process_journey_payment(from_station: String, to_station: String, distance: float, money_system: Money):
	"""Process payment for completed journey"""
	var breakdown = calculate_payment(from_station, to_station, distance)
	
	money_system.make_money(breakdown.total)
	payment_completed.emit(breakdown.total, breakdown)
	
	# Console output
	var bonus_text = ""
	if breakdown.first_visit:
		bonus_text = " (+ %.1f discovery bonus)" % breakdown.discovery
	
	print("Payment: %.1f credits%s" % [breakdown.total, bonus_text])

func get_estimated_payment(from_station: String, to_station: String, distance: float) -> Dictionary:
	"""Get estimated payment without marking station as discovered"""
	var base_payment = distance * credits_per_unit
	var will_get_bonus = not discovered_stations.has(to_station)
	
	return {
		"base": base_payment,
		"discovery": discovery_bonus if will_get_bonus else 0.0,
		"total": base_payment + (discovery_bonus if will_get_bonus else 0.0),
		"first_visit": will_get_bonus
	}

func has_discovered(station_name: String) -> bool:
	"""Check if station has been discovered"""
	return discovered_stations.has(station_name)

func get_discovery_progress() -> Dictionary:
	"""Get discovery statistics"""
	return {
		"discovered": discovered_stations.size(),
		"stations": discovered_stations.keys()
	}
