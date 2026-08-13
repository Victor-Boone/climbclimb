extends Node2D
const Utils = preload("res://scripts/utils.gd")

# Movement related variables
# - WALK_SPEED : Top speed while walking
# - AIR_SPEED : Top speed while airborn
# - JUMP_VELOCITY : Crude velocity set when jumping. 
@export var WALK_SPEED: float = 90.0
@export var AIR_SPEED: float = WALK_SPEED / 5.0
@export var JUMP_VELOCITY: float = 500.0

# Physics related variables ( how the character is affected by physics )
# - GRAVITY_SCALING : Beware of that force that pulls you down.
# - AIR_FRICTION : How much the air slow downs the character mid-air. 
@export_range(0.0, 1.0) var GRAVITY_SCALING : float = 1.0
@export var AIR_FRICTION: float = 0.0

# Variables related to character standing still
# - HEADBUTT_DISTANCE : resting distance between Head and Butt
# - BODY_STIFFNESS : Stiffness of the spring linking Head and Butt.
# - HEADBODYRATIO : [ mass of head ] / [ mass of body ]
# - STANDING_STRENGTH : Strength of the neck of the character ( hability to 
#                       to correct the angle speed at which their poor head 
#                       is yangling around. )
# - IDEAL_ANGLE_SPEED : Speed at which the character _wants_ to turn their head
#                       while getting up. 
# - STILL_ANGLE : Angle of verticality ( commodity constant )
@export var HEADBUTT_DISTANCE: float = 13.0
@export var BODY_STIFFNESS: float = 12.0
@export var HEADBODYRATIO: float = 0.5 
@export_range(0.0, 10.0) var STANDING_STRENGTH: float = 25.0 
@export_range(0.0, 10.0) var IDEAL_ANGLE_SPEED: float = 2.0
const STILL_ANGLE = 1.5 * PI

# State automaton 
enum State { IDLE, WALK, STUN }
var state: State = State.IDLE



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Head/DebugVector.hide() 
	$Head/DownRay.hide()
	$Butt/DebugVector.hide()
	$Butt/DownRay.hide()



# Properties of the character
func butt_is_on_floor() -> bool: return $Butt.get_distance_to_floor() < 0.2
func head_is_on_floor() -> bool: return $Head.get_distance_to_floor() < 0.13
func is_on_floor()      -> bool: return butt_is_on_floor()
func is_standing()      -> bool: return abs(body_angle() - STILL_ANGLE) < 0.25 * PI



# Visual-related functions

func rotate_head() -> void:
	""" Rotate the face relatively to the body angle. """
	var p_butt: Vector2 = $Butt.position
	var p_head: Vector2 = $Head.position
	var angle: float = (p_butt - p_head).angle()
	$Head.rotation = angle - PI/2


func flip_head() -> void:
	""" Flip the heat relatively to the facing direction. """
	var direction: float = Input.get_axis("move_left", "move_right")
	if direction > 0.0:
		$Head/Sprite2D.flip_h = false
	if direction < 0.0:
		$Head/Sprite2D.flip_h = true


# Player input

func movement_manager() -> void:
	"""Manage the Player's input for movement. """
	var direction: float = Input.get_axis("move_left", "move_right")
	var v_butt = $Butt.velocity
	var v_head = $Head.velocity
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



# Internal Physics (mostly interection between body parts)

func body_angle() -> float:
	""" Return the body angle, in the range [0, 2PI] """
	var body: Vector2 = $Head.position - $Butt.position
	var angle: float = body.angle()
	return Utils.mod_2PI(angle)


func desired_angle_speed_wrt(angle: float) -> float:
	""" Return the angle-speed desired by the character when standing-up. """
	var angle_to_still: float = STILL_ANGLE - angle
	angle_to_still = Utils.mod_2PI(angle_to_still + PI) - PI
	return IDEAL_ANGLE_SPEED * angle_to_still


func _head_butt_interaction(delta: float) -> void:
	""" Adjust the Head's and Butt's velocities.
	
	The Head and Butt are attached together with a semi-rigid pole.
	The pole acts like a spring with resting length HEADBUTT_DISTANCE. 
	Its length is clipped to a segment 
	        [ alpha HEADBUTT_DISTANCE, beta HEADBUTT_DISTANCE ] 
	to avoid the character from being torn apart.
	
	The character further tries to stand up when eligible. """
	
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
	var dL: float = BODY_STIFFNESS * (HEADBUTT_DISTANCE - L) * delta
	dL += (v_butt + r * v_head).dot(axis) / (1 + r) * delta 
	L = Utils.clip(L + dL, 0.66 * HEADBUTT_DISTANCE, 1.2 * HEADBUTT_DISTANCE)
	
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



# Climb logic

func _update_grip_area() -> void:
	var grip_center = 0.25 * $Butt.position + 0.75 * $Head.position
	$GripArea.position = grip_center

func _DEBUG_display_grip_points() -> void:
	"""
	Display best grip points per grippable object around.
	Must be called after _update_grip_area().
	"""
	var collisions = $GripArea.get_overlapping_areas()
	var global_center = global_position + $GripArea.position
	var radius = $GripArea/CollisionShape2D.get_shape().get_radius()
	# print()
	# print("Global center:", global_center)
	$DebugLine.clear_points()
	# $DebugLine.add_point($GripArea.position)
	# print("Center:", global_center)
	for object in collisions:
		var d = object.point_score_wrt(global_center, 1.1*radius, Vector2(0,-1))
		if d["score"] != -INF:
			var point: Vector2 = d["point"] - global_position
			$DebugLine.add_point(point)


# External Physics

func _apply_gravity(delta: float) -> void:
	""" Apply gravity to Butt and Head. """
	if not $Butt.is_on_floor():
		var butt_gravity = GRAVITY_SCALING * $Butt.get_gravity()
		$Butt.velocity += butt_gravity * delta
	if not $Head.is_on_floor():
		var head_gravity = GRAVITY_SCALING * $Head.get_gravity()
		$Head.velocity += head_gravity * delta


func _apply_velocity(delta) -> void:
	""" Move Butt and Head. 
	
	Both use an home-made method 'move_and_bounce()' for wiggling physics.
	Refer to 'move_and_bounce()' in 'bodypart.gd' for more information. """
	$Butt.move_and_bounce(delta)
	$Head.move_and_bounce(delta)


func _apply_air_friction(delta) -> void:
	$Butt.velocity *= pow(1.0 - AIR_FRICTION, delta)
	$Head.velocity *= pow(1.0 - AIR_FRICTION, delta)


func _physics_process(delta: float) -> void:
	# Read Player's input
	movement_manager()
	
	# Compute physics
	_head_butt_interaction(delta)
	_apply_air_friction(delta)
	_apply_gravity(delta)
	_apply_velocity(delta)
	
	# Visuals
	rotate_head()
	flip_head()
	_update_grip_area()
	_DEBUG_display_grip_points()
	
	# Debug
	$Butt._update_velocity_vector()
	$Head._update_velocity_vector()
