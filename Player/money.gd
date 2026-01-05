extends Node

class_name Money

@export var starting_money: int = 0

var current_money: int

var lifetime_money: int

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
	Events.made_money.emit(amount)
	current_money += amount
	lifetime_money += amount
	
func check_can_buy(amount: int) -> bool:
	if roundi(current_money) >= amount:
		return true
	else:
		return false

func try_buy(amount: int) -> bool:
	if roundi(current_money) >= amount:
		current_money -= amount
		Events.spent_money.emit(amount)
		return true
	else:
		print("Not enough money, need "+str(amount)+" have "+str(current_money))
		return false
