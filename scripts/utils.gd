extends Node


static func clip(x: float, inf: float, sup: float) -> float:
	return min(sup, max(x, inf))
static func mod_2PI(angle: float) -> float:
	return angle - 2 * PI * floor(0.5 * angle / PI)
