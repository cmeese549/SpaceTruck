extends Node

class_name Money

@export var starting_money: int = 0

var current_money: int
var lifetime_money: int

# Debt tracking
signal debt_status_changed(in_debt: bool)

func get_save_data() -> Dictionary:
	var data: Dictionary = {}
	data.current_money = current_money
	data.lifetime_money = lifetime_money
	return data

func load_save_data(data: Dictionary) -> void:
	current_money = data.current_money
	lifetime_money = data.lifetime_money

func _ready():
	current_money = starting_money
	lifetime_money = starting_money
	Events.make_money.connect(make_money)

func make_money(amount):
	var was_in_debt = is_in_debt()
	Events.made_money.emit(amount)
	current_money += amount
	lifetime_money += amount

	# Check if debt status changed
	var now_in_debt = is_in_debt()
	if was_in_debt != now_in_debt:
		debt_status_changed.emit(now_in_debt)

func is_in_debt() -> bool:
	"""Check if player is in debt (negative balance)"""
	return current_money < 0

func get_debt_amount() -> int:
	"""Get the absolute value of debt (0 if not in debt)"""
	return abs(min(current_money, 0))

func check_can_buy(amount: int) -> bool:
	"""Check if player can afford something (only true if not going into debt)"""
	return current_money >= amount

func try_buy(amount: int) -> bool:
	"""Attempt to buy something. Always succeeds but may put player into debt."""
	var was_in_debt = is_in_debt()
	current_money -= amount
	Events.spent_money.emit(amount)

	# Check if debt status changed
	var now_in_debt = is_in_debt()
	if was_in_debt != now_in_debt:
		debt_status_changed.emit(now_in_debt)

	if now_in_debt:
		print("Purchase of $%d puts you into debt! Current balance: $%d" % [amount, current_money])

	return true
