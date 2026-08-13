extends Node


static func clip(x: float, inf: float, sup: float) -> float:
	return min(sup, max(x, inf))
static func mod_2PI(angle: float) -> float:
	return angle - 2 * PI * floor(0.5 * angle / PI)

## Computes
#static func foo(
	#circle_position: Vector2,
	#circle_radius: float,
	#input_direction: Vector2,
	#lines: Array[ClimbingLine]
#) -> void:
	#pass
