extends Node3D

class_name Destination

@export var _name: String = "Blorpotron III"

@onready var label: Label3D = find_child("NameLabel")

func _ready():
	label.text = _name
