extends CharacterBody2D

var radius: float

func _ready() -> void:
	var shape = $OuterCollisionShape.get_shape()
	radius = shape.get_radius()
	print("radius", radius)
	floor_max_angle = 9 * PI / 10

func get_distance_to_floor() -> float:
	var cp: Vector2 = $DownRay.get_collision_point()
	return abs(global_position.distance_to(cp) - radius)

func set_label_color(color: Color) -> void:
	$Label.add_theme_color_override("font_color", color)

func _update_velocity_vector() -> void:
	$Line2D.set_point_position(1, 0.3 * velocity)
	$Label.text = str(int(velocity.length()))
