extends CharacterBody2D

"""
A Body Part.

1. About collisions: The collision shape watches MASK 1 but is on no layers, so
   that no body part can collide with another. "Collisions" between body parts
   must be managed by strings/poles or other mechanisms. 
"""

@export_range(0.0, 1.0) var BOUNCE_FACTOR_X: float = 1.0
@export_range(0.0, 1.0) var BOUNCE_FACTOR_Y: float = 1.0
const MAX_BOUNCE_STEPS: int = 5

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

func move_and_bounce(delta: float):
	"""
	Move and bounce the bodypart around.
	
	- On collision, the bodypart bounces with respect to the normal of the 
	  collided object. 
	"""
	var butt_budget: float = delta
	for step in range(MAX_BOUNCE_STEPS):
		var p_init = position
		var butt_collision = move_and_collide(velocity * butt_budget)
		var dp = position - p_init
		var dt = dp.length() / velocity.length() 
		butt_budget -= dt
		if butt_collision:
			# TODO: retrieve the bouncing attributes of the material 
			velocity = velocity.bounce(butt_collision.get_normal())
			velocity.x *= BOUNCE_FACTOR_X
			velocity.y *= BOUNCE_FACTOR_Y
		if butt_budget < 1e-5: break
