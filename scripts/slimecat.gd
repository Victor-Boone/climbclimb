extends Node2D
const Utils = preload("res://scripts/utils.gd")

@export var L0: float = 13 # resting distance between ends
@export var WALK_SPEED: float = 90.0
@export var AIR_SPEED: float = WALK_SPEED / 5.0
@export var JUMP_VELOCITY: float = 500.0
@export var HEADBODYRATIO: float = 0.5 # [ mass of head ] / [ mass of body ]

@export_range(0.0, 1.0) var GRAVITY_SCALING : float = 1.0
@export var AIR_FRICTION: float = 0.0
@export var GROUND_FRICTION: float = 0.99
@export_range(0.0, 10.0) var STANDING_STRENGTH: float = 25.0
@export_range(0.0, 10.0) var IDEAL_ANGLE_SPEED: float = 2.0
const STILL_ANGLE = 1.5 * PI

enum State { IDLE, WALK, STUN }
var state: State = State.IDLE


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Head.floor_max_angle = 10.0
	pass # Replace with function body.

func butt_is_on_floor() -> bool:
	return $Butt.get_distance_to_floor() < 0.2
func head_is_on_floor() -> bool:
	return $Head.get_distance_to_floor() < 0.13
func is_on_floor() -> bool:
	return butt_is_on_floor()

func body_angle() -> float:
	""" Return the body angle, in the range [0, 2PI] """
	var body: Vector2 = $Head.position - $Butt.position
	var angle: float = body.angle()
	return Utils.mod_2PI(angle)


func is_standing() -> bool:
	return abs(body_angle() - STILL_ANGLE) < 0.25 * PI


func desired_angle_speed_wrt(angle: float) -> float:
	var angle_to_still: float = STILL_ANGLE - angle
	angle_to_still = Utils.mod_2PI(angle_to_still + PI) - PI
	return IDEAL_ANGLE_SPEED * angle_to_still
	

func rotate_head() -> void:
	var p_butt: Vector2 = $Butt.position
	var p_head: Vector2 = $Head.position
	var angle: float = (p_butt - p_head).angle()
	$Head.rotation = angle - PI/2

func movement_manager() -> void:
	"""Manage the Player's input for movement. """
	var direction: float = Input.get_axis("move_left", "move_right")
	var v_butt = $Butt.velocity
	var v_head = $Head.velocity
	print("Is_on_floor:", is_on_floor())
	if Input.is_action_just_pressed("jump") and is_standing() and is_on_floor(): # Jumping
		state = State.IDLE
		$Butt.velocity.y -= JUMP_VELOCITY
	elif direction and is_standing():
		state = State.WALK
		# TODO
		var speed: float = WALK_SPEED if is_on_floor() else AIR_SPEED
		var target_x_velocity: float = direction * WALK_SPEED
		$Butt.velocity.x = move_toward(v_butt.x, target_x_velocity, speed)
		if false and not is_on_floor():
			$Head.velocity.x = move_toward(v_head.x, target_x_velocity, speed)
	else: 
		state = State.IDLE
	# state = State.STUN
	

func _apply_gravity(delta: float) -> void:
	""" Apply gravity to Butt and Head. """
	if not $Butt.is_on_floor():
		var butt_gravity = GRAVITY_SCALING * $Butt.get_gravity()
		$Butt.velocity += butt_gravity * delta
	if not $Head.is_on_floor():
		var head_gravity = GRAVITY_SCALING * $Head.get_gravity()
		$Head.velocity += head_gravity * delta
		

func _correct_velocity(delta: float) -> void:
	""" Pole correction. """
	# Aliases
	var r: float = HEADBODYRATIO
	var p_butt: Vector2 = $Butt.position
	var v_butt: Vector2 = $Butt.velocity
	var p_head: Vector2 = $Head.position
	var v_head: Vector2 = $Head.velocity
	var p     : Vector2 = (p_butt + r * p_head) / (1 + r)
	var axis  : Vector2 = (p_head - p_butt).normalized()
	var normal: Vector2 = (p_head - p_butt).rotated(PI/2).normalized()
	var theta : float   = body_angle()
	var L     : float   = (p_head - p_butt).length()
	
	# Infinitesimal displacements
	var dp    : Vector2 = (v_butt + r * v_head) * delta / (1 + r) # displ of barycenter
	var dtheta: float   = - (v_butt - v_head).dot(normal) / L * delta 
	
	# Correct theta to push it towards STANDING_ANGLE
	if true and state != State.STUN:
		var target_speed: float = desired_angle_speed_wrt(theta)
		dtheta = move_toward(dtheta, target_speed, STANDING_STRENGTH * delta)
	
	# Correct distance between head & butt
	var dL: float = 12 * (L0 - L) * delta
	dL += (v_butt + r * v_head).dot(axis) / (1 + r) * delta 
	L = Utils.clip(L + dL, 0.66 * L0, 1.2 * L0)
	
	# Compute ideal next positions
	var new_theta: float = Utils.mod_2PI(theta + dtheta)
	var cossin: Vector2 = Vector2(1, 0).rotated(new_theta)
	var next_p_butt: Vector2 = p + dp - r/(1+r)*L*cossin
	var next_p_head: Vector2 = p + dp + 1/(1+r)*L*cossin
	
	# Correcting velocities
	var new_v_butt: Vector2 = (next_p_butt - p_butt) / delta
	var new_v_head: Vector2 = (next_p_head - p_head) / delta
	# if new_v_butt.length() < 0.13: new_v_butt = Vector2.ZERO # WTH
	# qif new_v_head.length() < 0.13: new_v_head = Vector2.ZERO # WTH
	
	# Correction done
	$Butt.velocity = new_v_butt
	$Head.velocity = new_v_head
	

func _apply_velocity(delta) -> void:
	""" Move Butt and Head. """
	$Butt.move_and_bounce(delta)
	$Head.move_and_bounce(delta)


func _apply_air_friction(delta) -> void:
	$Butt.velocity *= pow(1.0 - AIR_FRICTION, delta)
	$Head.velocity *= pow(1.0 - AIR_FRICTION, delta)

func _physics_process(delta: float) -> void:
	movement_manager()
	_correct_velocity(delta)
	# _apply_air_friction(delta)
	_apply_gravity(delta)
	_apply_velocity(delta)
	rotate_head()
	$Butt._update_velocity_vector()
	$Head._update_velocity_vector()
