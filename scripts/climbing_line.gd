extends Area2D
class_name ClimbingLine

@export var MATERIAL: float = 1.0

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
	#var result: Array[Vector2] = []
	#var p1: Vector2 = get_tip()
	#var p2: Vector2 = get_end()
	#var dx: float = p2.x - p1.x
	#var dy: float = p2.y - p1.y
	#var dr: float = sqrt(dx*dx + dy*dy)
	#var D : float = p1.x * p2.y - p2.x * p1.y
	#var sgn: float = -1 if dy < 0 else 1
	#sgn *= dx * sqrt(radius*radius * dr*dr - D*D)
	#var abso: float = abs(dy) * sqrt(radius*radius * dr*dr - D*D)
	#for i in range(2):
		#var p: Vector2
		#var s = 2 * i - 1
		#p.x = (D * dy + s * sgn) / (dr * dr)
		#p.y = (- D * dx + s * abso) / (dr * dr)
		#if true or point_within_segment(p):
			#result.push_back(p)
	#return result
	var result: Array[Vector2] = []
	var tip: Vector2 = get_tip()
	var end: Vector2 = get_end()
	var lambda1: float = Geometry2D.segment_intersects_circle(tip, end, center, radius)
	var lambda2: float = Geometry2D.segment_intersects_circle(end, tip, center, radius)
	if lambda1 != -1: result.push_back(lambda1 * end + (1 - lambda1) * tip)
	if lambda2 != -1: result.push_back(lambda2 * tip + (1 - lambda2) * end)
	return result

func point_score_wrt(center: Vector2, radius: float, direction: Vector2) -> Dictionary:
	"""
	Given the GripArea circle centered at 'center' with radius 'radius', and
	given that the player's input direction 'direction', return a dictionary
	
	- Dict["point"] = Vector2 best aligned to the desired player's direction.
	- Dict["score"] = Associated alignement score. 
	"""
	var tip: Vector2 = get_tip()
	var end: Vector2 = get_end()
	var inter = Geometry2D.segment_intersects_segment(tip, end, center - radius * direction, center + radius * direction)
	var points = circle_segment_intersection(center, radius)
	if Geometry2D.is_point_in_circle(tip, center, radius): points.push_back(tip)
	if Geometry2D.is_point_in_circle(end, center, radius): points.push_back(end)
	if inter != null and Geometry2D.is_point_in_circle(inter, center, radius): points.push_back(inter)
	var best_point: Vector2 = Vector2.ZERO
	var best_score: float = -INF
	direction = direction.normalized()
	for point in points:
		var align_score  = direction.dot((point - center).normalized())
		var normal_score = abs(direction.rotated(PI/2).dot((point - center).normalized()))
		var score = align_score - normal_score
		print("Score of ", point, " = ", score)
		if score > best_score:
			best_point = point
			best_score = score
	return {"point": best_point, "score": best_score}
	
	
