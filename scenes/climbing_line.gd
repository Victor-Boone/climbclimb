extends Area2D

@export var MATERIAL: float = 1.0

func _ready() -> void:
	assert($Line2D.get_point_count() == 2)

func get_line() -> Line2D:
	return $Line2D

func get_tip() -> Vector2:
	var line_pos: Vector2 = $Line2D.global_position
	var tip: Vector2 = $Line2D.get_point_position(0) + line_pos
	return tip
	
func get_end() -> Vector2:
	var line_pos: Vector2 = $Line2D.global_position
	var end: Vector2 = $Line2D.get_point_position(1) + line_pos
	return end
