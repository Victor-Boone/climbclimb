extends CharacterBody2D

"""
A Body Part.

1. About collisions: The collision shape watches MASK 1 but is on no layers, so
   that no body part can collide with another. "Collisions" between body parts
   must be managed by strings/poles or other mechanisms. 
"""

func get_radius() -> float:
	return $CollisionShape2D.get_shape().get_radius()

func get_distance_to_floor() -> float:
	var cp: Vector2 = $DownRay.get_collision_point()
	return abs(global_position.distance_to(cp) - get_radius())

func set_label_color(color: Color) -> void:
	$DebugVector/Label.add_theme_color_override("font_color", color)

func _update_velocity_vector() -> void:
	$DebugVector/Line2D.set_point_position(1, 0.3 * velocity)
	$DebugVector/Label.text = str(int(velocity.length()))
