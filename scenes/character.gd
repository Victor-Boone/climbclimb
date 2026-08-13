extends CharacterBody2D

@export var SPEED = 100.0
@export_range(0.0, 10.0) var GROUND_FRICTION = 8.0
@export_range(0.0, 10.0) var AIR_FRICTION = 1.0
@export var JUMP_VELOCITY = 200.0
@export var MAX_STAMINA : float = 1.0
@export_range(0.0, 1.0) var STAMINA_DECAY : float = 0.2
var stamina : float = 1.0
var weight : float = 1.0
var face_direction : int = 1

# Collision variables --- FOR SPEED-UP
var on_floor : bool
var on_wall : bool
var climbing_mode : bool

# Initialize the player
func _ready():
	stamina = MAX_STAMINA
	$AnimatedSprite2D.animation = "idle"
	$AnimatedSprite2D.play()


func is_climbing() -> bool:
	""" Check if the caracter is climbing. 
	Must be called after updating the 'on_wall' variable. """
	var climb = Input.is_action_pressed("climb") # and on_wall
	return climb
	


func get_direction() -> float:
	var direction: float = Input.get_axis("move_left", "move_right")
	return direction


func select_animation():
	""" Select the animation of the character.
	Must be called after _updating_collision_metadata() and _update_velocity_XXX()"""
	# Select WALK/IDLE
	if velocity.length() > 0 and is_on_floor():
		$AnimatedSprite2D.animation = "walk"
	else:
		$AnimatedSprite2D.animation = "idle"
	# Turn around
	var direction = get_direction()
	if abs(direction) > 1e-3:
		face_direction = 2 * int(direction > 0) - 1
	else:
		face_direction = 0
	if face_direction == 1:
		$AnimatedSprite2D.flip_h = false
	elif face_direction == -1:
		$AnimatedSprite2D.flip_h = true
	# Debug color for climbing
	if climbing_mode:
		$AnimatedSprite2D.modulate = Color(1.0, 0.0, 0.0)
	else:
		$AnimatedSprite2D.modulate = Color(1.0, 1.0, 1.0)


func _process(delta: float) -> void:
	select_animation()
	
func _update_collision_metadata() -> void:
	""" Update on_floor, on_wall, climbing_mode """
	on_floor      = is_on_floor()
	on_wall       = is_on_wall()
	climbing_mode = is_climbing()
	# print("| ON WALL: ", on_wall)

func _update_velocity(delta: float) -> void:
	""" Update the vector 'velocity' of the character. 
	Take into account gravity, climbing & player input. 
	Must be called after _update_collision_metadata(). """
	if climbing_mode: _update_velocity_climbing(delta)
	else: _update_velocity_non_climbing(delta)
	

func _update_velocity_climbing(delta: float) -> void:
	""" Update the velocity vector in climbing mode."""
	velocity.y = 0.0
	velocity.x = 0.0
	
func _update_velocity_non_climbing(delta: float) -> void:
	""" Update the velocity while non-climbing. """
	if not on_floor: # Falling
		velocity += get_gravity() * delta
	if Input.is_action_just_pressed("jump") and is_on_floor(): # Jumping
		velocity.y -= JUMP_VELOCITY
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction = get_direction()
	if direction and on_floor:
		var target_x_velocity: float = direction * SPEED
		velocity.x = move_toward(velocity.x, target_x_velocity, SPEED)
	if not direction: # Apply friction if no input direction
		var friction: float = GROUND_FRICTION if on_floor else AIR_FRICTION
		velocity.x = move_toward(velocity.x, 0, delta * friction * SPEED)

func _physics_process(delta: float) -> void:
	_update_collision_metadata()
	_update_velocity(delta)
	move_and_slide()
	#for i in get_slide_collision_count():
		#var collision = get_slide_collision(i)
		#print("I collided with ", collision.get_collider().name)
	#


func _on_right_body_entered(body: Node2D) -> void:
	# print("Right body [", body.name, "] entered.") 
	pass


func _on_right_body_exited(body: Node2D) -> void:
	# print("Right body [", body.name, "] exited.") # Replace with function body.
	pass 
