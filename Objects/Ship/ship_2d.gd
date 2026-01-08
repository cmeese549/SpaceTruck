extends Node2D
class_name Ship2D

## 2D Ship visualization for Space Truck
## Displays ship position and draws travel line to destination

signal position_changed(new_position: Vector2)

# Visual settings
const SHIP_SIZE = 12.0
const SHIP_COLOR = Color(1.0, 0.4, 0.2)  # Orange
const SHIP_OUTLINE_COLOR = Color(1.0, 0.6, 0.3)
const TRAVEL_LINE_COLOR = Color(0.5, 0.5, 0.8, 0.5)
const TRAVEL_LINE_WIDTH = 2.0

# State
var current_position := Vector2.ZERO
var destination_position := Vector2.ZERO
var is_traveling := false
var ship_rotation := 0.0  # Rotation in radians


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	# Draw travel line if traveling
	if is_traveling:
		draw_line(Vector2.ZERO, destination_position - current_position, TRAVEL_LINE_COLOR, TRAVEL_LINE_WIDTH)

	# Draw ship as triangle pointing right (base shape before rotation)
	var base_points := PackedVector2Array([
		Vector2(SHIP_SIZE, 0),           # Nose (right)
		Vector2(-SHIP_SIZE * 0.6, -SHIP_SIZE * 0.8),  # Top wing
		Vector2(-SHIP_SIZE * 0.6, SHIP_SIZE * 0.8)    # Bottom wing
	])

	# Rotate points based on ship_rotation
	var rotated_points := PackedVector2Array()
	for point in base_points:
		var rotated = point.rotated(ship_rotation)
		rotated_points.append(rotated)

	draw_colored_polygon(rotated_points, SHIP_COLOR)
	draw_polyline(rotated_points + PackedVector2Array([rotated_points[0]]), SHIP_OUTLINE_COLOR, 2.0)


func set_ship_position(pos: Vector2) -> void:
	"""Update ship's position on the map"""
	current_position = pos
	position = current_position
	position_changed.emit(current_position)
	queue_redraw()


func set_destination(dest_pos: Vector2) -> void:
	"""Set destination for travel line visualization"""
	destination_position = dest_pos
	is_traveling = true

	# Calculate rotation to point toward destination
	var direction = (destination_position - current_position).normalized()
	ship_rotation = direction.angle()

	queue_redraw()


func clear_destination() -> void:
	"""Clear destination (arrived)"""
	is_traveling = false
	queue_redraw()


func _get_position() -> Vector2:
	"""Get current ship position"""
	return current_position


func move_towards_destination(delta: float, speed: float) -> void:
	"""Smoothly move ship towards destination (visual only)"""
	if is_traveling and current_position.distance_to(destination_position) > 1.0:
		var direction = (destination_position - current_position).normalized()
		var movement = direction * speed * delta
		set_ship_position(current_position + movement)
