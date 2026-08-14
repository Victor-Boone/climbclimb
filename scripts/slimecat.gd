extends Node2D
const Utils = preload("res://scripts/utils.gd")

@export var FLY_MODE: bool = false
var throw_timer: float = 0.0
@export var THROW_DELAY: float = 0.3

# Movement related variables
# - WALK_SPEED : Top speed while walking
# - AIR_SPEED : Top speed while airborn
# - JUMP_VELOCITY : Crude velocity set when jumping. 
@export var WALK_SPEED: float = 90.0
@export var AIR_SPEED: float = WALK_SPEED / 5.0
@export var GROUND_JUMP_VELOCITY: float = 500.0
@export var CLIMB_JUMP_VELOCITY: float = 300.0

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
func is_climbing()      -> bool: return Input.is_action_pressed("climb")
func is_gripped()       -> bool: return hand_grip[LEFT]["load"] + hand_grip[RIGHT]["load"] > 0.01


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

func get_Vector2_direction() -> Vector2:
	""" Read the player's direction. """
	var direction_x: float = Input.get_axis("move_left", "move_right")
	var direction_y: float = Input.get_axis("move_up", "move_down")
	var direction: Vector2 = Vector2(direction_x, direction_y)
	var velocity: Vector2 = 0.5 * ($Head.velocity + $Butt.velocity)
	if direction.length() > 1e-3 or is_gripped():
		return direction
	else:
		return velocity 


func movement_manager() -> void:
	"""Manage the Player's input for movement on ground. """
	var x_direction: float = Input.get_axis("move_left", "move_right")
	var v_butt = $Butt.velocity
	var v_head = $Head.velocity
	if is_climbing():
		if Input.is_action_just_pressed("jump") and is_gripped():
			state = State.IDLE
			var dir: Vector2 = Vector2(x_direction, -2.0).normalized()
			$Butt.velocity += CLIMB_JUMP_VELOCITY * dir
			hand_grip[LEFT]["load"] = 0.0
			hand_grip[RIGHT]["load"] = 0.0
			throw_timer = THROW_DELAY
	elif Input.is_action_just_pressed("jump") \
		and ((is_standing() and is_on_floor()) or FLY_MODE): # Jumping
		state = State.IDLE
		$Butt.velocity.y -= GROUND_JUMP_VELOCITY
	elif x_direction and is_standing():
		state = State.WALK
		# TODO
		var speed: float = WALK_SPEED if is_on_floor() else AIR_SPEED
		var target_x_velocity: float = x_direction * WALK_SPEED
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
		var correction: float = 0.33 if is_climbing() else 1.0
		dtheta = move_toward(dtheta, target_speed, correction * STANDING_STRENGTH * delta)
	
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

@export var ARM_LENGTH: float = 0.0
@export var ARM_SPEED: float = 2.0
@export var ARM_POWER: float = 10000.0
@export var GRIP_TRACTION: float = 20.0

const LEFT: int = 0
const RIGHT: int = 1
var hand_grip : Array[Dictionary] = [
	{"load": 0.0, "point": Vector2.ZERO},
	{"load": 0.0, "point": Vector2.ZERO}
]

func get_body_position() -> Vector2: return 0.25 * $Butt.position + 0.75 * $Head.position
func get_grip_area_position() -> Vector2: return -.00 * $Butt.position + 1.00 * $Head.position
func _update_grip_area() -> void: $GripArea.position = get_grip_area_position()
func total_hand_load() -> float: return hand_grip[LEFT]["load"] + hand_grip[RIGHT]["load"]

func display_hands() -> void:
	if hand_grip[RIGHT]["load"] == 0.0: $RightHand.hide()
	else:
		$RightHand.position = hand_grip[RIGHT]["point"] 
		$RightHand.show()
	if hand_grip[LEFT]["load"] == 0.0: $LeftHand.hide()
	else: 
		$LeftHand.position = hand_grip[LEFT]["point"]
		$LeftHand.show()


func gripping_score_of_point(point: Vector2) -> float:
	""" Return the gripping score of a point (relative position). """
	var center: Vector2 = get_grip_area_position()
	var direction: Vector2 = get_Vector2_direction()
	var align_score  = direction.dot((point - center).normalized())
	var normal_score = abs(direction.rotated(PI/2).dot((point - center).normalized()))
	var norm = (point - center).length()
	# return align_score - normal_score # FORMULA 1 
	# return align_score # FORMULA 2
	return norm * align_score - normal_score


func get_gripping_points() -> Array[Vector2]:
	""" Return an array of gripping points """
	var collisions = $GripArea.get_overlapping_areas()
	var global_center: Vector2 = global_position + $GripArea.position
	var radius: float = $GripArea/CollisionShape2D.get_shape().get_radius()
	var points: Array[Vector2] = []
	var dir = get_Vector2_direction()
	for object in collisions:
		var object_points = object.grippable_points_wrt(global_center, 1.1*radius, dir)
		for point in object_points:
			points.push_back(point)
	return points


func choose_grip_point(points) -> Array[Vector2]:
	""" Grip a point (with available hand) """
	var best_score = - INF
	var best_point: Vector2 = Vector2.ZERO
	for point in points:
		point -= global_position
		var score = gripping_score_of_point(point)
		if score >= 0.0 and score > best_score:
			best_score = score
			best_point = point
	return [best_point] if best_score != - INF else []


func climbing_manager(delta) -> void:
	throw_timer = move_toward(throw_timer, 0.0, delta)
	_update_grip_area()
	_DEBUG_display_grip_points()
	var input_dir: Vector2 = get_Vector2_direction()
	if not is_climbing() or throw_timer > 0.0:
		hand_grip[RIGHT]["load"] = 0.0
		hand_grip[LEFT ]["load"] = 0.0
		if not is_climbing() :
			throw_timer = 0.0
	elif total_hand_load() == 0.0:
		var points: Array[Vector2] = get_gripping_points()
		for grip_point in choose_grip_point(points): # haha HACKY
			hand_grip[RIGHT]["load"] = 0.5
			hand_grip[RIGHT]["point"] = grip_point
	elif total_hand_load() < 0.99:
		# WARNING: RIGHT is considered the only hand gripped here
		hand_grip[RIGHT]["load"] = move_toward(hand_grip[RIGHT]["load"], 1.0, delta * ARM_SPEED)
	elif input_dir.length() > 1e-3:
		var body_point: Vector2 = get_body_position()
		var LEFT_load: float = hand_grip[LEFT]["load"]
		var RIGHT_load: float = hand_grip[RIGHT]["load"]
		var weak_hand: int = LEFT if LEFT_load < RIGHT_load else RIGHT
		var strong_hand: int = 1 - weak_hand
		# Main logic
		# print("Weak hand: ", weak_hand)
		if hand_grip[weak_hand]["load"] < 0.01:
			# print("[Climbing] Trying to set a new hand")
			# if the weak hand is too weak ( < 0.01 )
			var points: Array[Vector2] = get_gripping_points()
			for grip_point in choose_grip_point(points): # haha HACKY
				hand_grip[weak_hand]["load"] = 0.25
				hand_grip[weak_hand]["point"] = grip_point
				hand_grip[strong_hand]["load"] = 0.75
			if hand_grip[weak_hand]["load"] != 0.25:
				print("[WARNING] Failed to find a new grip. ")
		else: # General case, slide hands in direction
			var rh_direction = (hand_grip[RIGHT]["point"] - body_point) # .normalized()
			var lh_direction = (hand_grip[LEFT ]["point"] - body_point) # .normalized()
			var rh_score: float = rh_direction.dot(input_dir)
			var lh_score: float = lh_direction.dot(input_dir)
			var good_hand: int = LEFT if lh_score > rh_score else RIGHT
			var bad_hand : int = 1 - good_hand
			hand_grip[good_hand]["load"] = move_toward(
				hand_grip[good_hand]["load"],
				1.0,
				delta * ARM_SPEED
			)
			hand_grip[bad_hand]["load"] = move_toward(
				hand_grip[bad_hand]["load"],
				0.0,
				delta * ARM_SPEED
			)
	else:
		pass
	# print("[RIGHT: ", hand_grip[RIGHT]["load"], "], [LEFT: ", hand_grip[LEFT]["load"], "]")
	display_hands()


func _apply_gripping_traction(delta) -> void:
	var body_point: Vector2 = get_body_position()
	var body_axis = ($Head.position - $Butt.position).normalized()
	var shoulder_axis = body_axis.rotated(-PI/2)
	var velocity: Vector2 = $Head.velocity
	var new_velocity: Vector2 = Vector2.ZERO
	var hand: float = 0 # commodity variable tracking the currently selected hand
	var total_load: float = 0.0
	for hand_data in hand_grip:
		var sgn = -1.0 if hand == LEFT else +1.0
		var shoulder_point = body_point + 3.0 * sgn * shoulder_axis
		var hand_load  = hand_data["load"]
		var hand_point = hand_data["point"]
		var hand_power = hand_load * ARM_POWER * delta 
		var hand_vec: Vector2 = hand_point - shoulder_point
		var hand_dir: Vector2 = hand_vec.normalized()
		var hand_normal: Vector2 = hand_dir.rotated(-PI/2)
		var hand_desired_v: Vector2 = \
			GRIP_TRACTION * hand_load * abs(hand_vec.length() - ARM_LENGTH) * hand_dir
		# Compute component of hand velocity on the axis of the arm (hand_dir),
		# then correct it. If distance to the arm is too large, the velocity
		# is killed to 0.0, simulating the bone of the arm (that poor shoulder
		# should not be dislocated).
		var hd_velocity: Vector2 = velocity.dot(hand_dir) * hand_dir
		if hand_load > 0.0 and hand_vec.length() > 1.5 * ARM_LENGTH: 
			hd_velocity = Vector2.ZERO
		hd_velocity.x = move_toward(hd_velocity.x, hand_desired_v.x, hand_power)
		hd_velocity.y = move_toward(hd_velocity.y, hand_desired_v.y, hand_power)
		# Compute component of hand velocity on the normal.
		var hn_velocity: Vector2 = velocity.dot(hand_normal) * hand_normal
		# Recompose the vector, add half of it to new_velocity (there are two hands)
		new_velocity += hand_load * (hd_velocity + hn_velocity)
		total_load += hand_load
		hand += 1
	$Head.velocity += total_load * (new_velocity - $Head.velocity)


func _DEBUG_display_grip_points() -> void:
	"""
	Display best grip points per grippable object around.
	Must be called after _update_grip_area().
	"""
	var collisions = $GripArea.get_overlapping_areas()
	var global_center = global_position + $GripArea.position
	var radius = $GripArea/CollisionShape2D.get_shape().get_radius()
	$DebugLine.clear_points()
	var dir = get_Vector2_direction()
	for object in collisions:
		var points = object.grippable_points_wrt(global_center, 1.1*radius, dir)
		for point in points:
			$DebugLine.add_point(point - global_position)


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
	climbing_manager(delta)
	
	# Compute physics
	_apply_gripping_traction(delta)
	_head_butt_interaction(delta)
	_apply_air_friction(delta)
	_apply_gravity(delta)
	_apply_velocity(delta)
	
	# Visuals
	rotate_head()
	flip_head()
	
	
	# Debug
	$Butt._update_velocity_vector()
	$Head._update_velocity_vector()
