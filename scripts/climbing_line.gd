extends Area2D
class_name ClimbingLine

@export var MATERIAL: float = 1.0
@export var MESH_SIZE : int = 6

func _ready() -> void:
	assert($Line2D.get_point_count() == 2)

func get_line() -> Line2D:
	return $Line2D

func get_tip() -> Vector2:
	""" Return the _global_ position of the Line2D's tip. """
	var line_pos: Vector2 = $Line2D.global_position
	var tip: Vector2 = $Line2D.get_point_position(0) + line_pos
	return tip
	
func get_end() -> Vector2:
	""" Return the _global_ position of the Line2D's end. """
	var line_pos: Vector2 = $Line2D.global_position
	var end: Vector2 = $Line2D.get_point_position(1) + line_pos
	return end

func point_within_segment(point: Vector2) -> bool:
	var tip: Vector2 = get_tip()
	var end: Vector2 = get_end()
	var scal1: bool = (point - tip).dot(end - tip) >= 0
	var scal2: bool = (point - end).dot(tip - end) >= 0
	return scal1 and scal2


func circle_segment_intersection(center: Vector2, radius: float) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var tip: Vector2 = get_tip()
	var end: Vector2 = get_end()
	var lambda1: float = Geometry2D.segment_intersects_circle(tip, end, center, radius)
	var lambda2: float = Geometry2D.segment_intersects_circle(end, tip, center, radius)
	if lambda1 != -1: result.push_back(lambda1 * end + (1 - lambda1) * tip)
	if lambda2 != -1: result.push_back(lambda2 * tip + (1 - lambda2) * end)
	return result


func grippable_points_wrt(center: Vector2, radius: float, direction: Vector2) -> Array[Vector2]:
	"""
	Given the GripArea circle centered at 'center' with radius 'radius', and
	given that the player's input direction 'direction', return an array of the
	potentially promising grippable points (in global coordinates).
	"""
	var tip: Vector2 = get_tip()
	var end: Vector2 = get_end()
	
	# Find two extremities of the segment in the circle
	var sup = tip
	var inf = end 
	if not Geometry2D.is_point_in_circle(tip, center, radius):
		var lambda = Geometry2D.segment_intersects_circle(tip, end, center, 1.1 * radius)
		if lambda == -1 : return []
		sup = lambda * end + (1 - lambda) * tip
	if not Geometry2D.is_point_in_circle(end, center, radius):
		var lambda = Geometry2D.segment_intersects_circle(end, tip, center, 1.1 * radius)
		if lambda == -1 : return []
		inf = lambda * tip + (1 - lambda) * end
		
	var result : Array[Vector2] = []
	var dir = sup - inf
	if dir.length() < 0.01 :
		return [sup]
	for index in range(MESH_SIZE) :
		var lambda : float = index / float(MESH_SIZE - 1)
		result.push_back(inf + lambda * dir)
	return result
	
