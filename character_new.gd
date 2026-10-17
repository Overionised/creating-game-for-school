extends CharacterBody3D

const SPEED = 6.0
const JUMP_VELOCITY = 5
const FRICTION = 25
const HORIZONTAL_ACCELERATION = 30   # ground acceleration / braking
const MAX_SPEED=30

# bunny hopping
const AUTO_BHOP = false          # hold jump to keep hopping (false = press jump again each time)
const JUMP_BUFFER_TIME = 0.12   # a jump pressed this early before landing still counts
const AIR_ACCEL = 10.0          # how quickly air strafing builds speed
const AIR_CAP = 0.7             # max speed air strafing adds along your wish direction (higher = easier to gain speed)

# slide tuning
const SLIDE_BOOST = 3.0        # speed added in your running direction when a slide starts
const SLIDE_COOLDOWN = 1.0      # seconds before another slide start gives the boost again
const SLIDE_FRICTION = 2      # speed lost per second while sliding (0 = keep all momentum)
const SLIDE_MIN_SPEED = 1.0     # the slide ends if you drop below this (e.g. sliding up a long ramp)
const SLIDE_SNAP = 1.0          # how far the floor can pull you down while sliding, keeps you glued to ramps
const DEFAULT_SNAP = 0.1        # Godot's default floor_snap_length
const SLIDE_DROP = 0.3         # how far the camera drops and the body shrinks while sliding
const DUCK_SPEED = 6.0          # how fast the camera drops / rises (units per second)

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

#sliding
var fall_distance = 0.0
var can_slide = false
var sliding = false
var falling = false
var slide_cooldown_left = 0.0

#jumping
var jump_buffer = 0.2

#ducking
@onready var collision_shape = $CollisionShape3D   # rename if your collision node is called something else
var stand_height = 2.0
var shape_rest_y = 0.0
var camera_rest_y = 0.0
var ducked = false

#bullets
var bullet = load("res://bullet.tscn") 
var instance
const KNOCKBACK_DECAY = 15.0

var walk_velocity := Vector3.ZERO   # typed, so assigning a float to it is caught immediately
var knockback = Vector3.ZERO



@onready var camera = $Camera3D
@onready var gun_anim = $Camera3D/weaponholder/shotgun2/AnimationPlayer
@onready var flash_particles = $Camera3D/weaponholder/shotgun2/Muzzle/GPUParticles3D
@onready var flash_light = $Camera3D/weaponholder/shotgun2/Muzzle/OmniLight3D
@onready var gun_barrel = $Camera3D/weaponholder/shotgun2/Muzzle/RayCast3D






func apply_knockback(impulse: Vector3):
	knockback.x += impulse.x
	knockback.z += impulse.z
	velocity.y += impulse.y

func muzzle_flash():
	flash_particles.restart()
	flash_light.visible = true
	await get_tree().create_timer(0.06).timeout
	flash_light.visible = false
	
func _ready():
	add_to_group("player")
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	camera_rest_y = camera.position.y
	shape_rest_y = collision_shape.position.y
	stand_height = get_shape_height()

func _unhandled_input(event):
	if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * .01)
		camera.rotate_x(-event.relative.y * .01)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)

func _unhandled_key_input(event):
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.mouse_mode==Input.MOUSE_MODE_CAPTURED: 
			Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func _physics_process(delta):
	slide_cooldown_left = max(slide_cooldown_left - delta, 0.0)
	
	#slide: landing while sliding adds your fall speed to your momentum
	if falling and is_on_floor() and sliding:
		walk_velocity += walk_velocity.normalized() * (max(fall_distance, 0.0) / 10)
	fall_distance= -velocity.y
	
	
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta
		falling = true
	else:
		falling = false
		
	#slide
	if Input.is_action_just_pressed("slide") and walk_velocity.length() > 3:
		can_slide = true 

	if Input.is_action_pressed("slide") and is_on_floor() and can_slide:
		slide(delta)
	elif is_on_floor():
		# on the ground but the slide conditions aren't met -> slide is over
		sliding = false
		can_slide = false
	if Input.is_action_just_released("slide"):
		can_slide = false
		sliding = false

	# Handle Jump (buffered, and optionally auto-repeating for bunny hopping).
	if Input.is_action_just_pressed("ui_accept"):
		jump_buffer = JUMP_BUFFER_TIME
	else:
		jump_buffer = max(jump_buffer - delta, 0.0)
	var jumped = false
	var wants_jump = jump_buffer > 0.0 or (AUTO_BHOP and Input.is_action_pressed("ui_accept"))
	if wants_jump and is_on_floor() and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		# keep upward speed from ramps, but ignore the downward part of a downhill slide
		velocity.y = max(velocity.y, 0.0) + JUMP_VELOCITY
		jump_buffer = 0.0
		jumped = true
		

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Vector3.ZERO
	input_dir.x = Input.get_vector("move_left", "move_right", "move_forward", "move_backward").x
	input_dir.y = Input.get_vector("move_left", "move_right", "move_forward", "move_backward").y

	input_dir=input_dir.normalized()
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var wish_dir = Vector3(direction.x, 0, direction.z).normalized()
	direction *= SPEED

	if is_on_floor() and not jumped:
		# ground: your original accelerate/brake toward the wanted speed.
		# (skipped while sliding, slide() owns walk_velocity then)
		if not sliding:
			walk_velocity.x = move_toward(walk_velocity.x, direction.x, HORIZONTAL_ACCELERATION * delta)
			walk_velocity.z = move_toward(walk_velocity.z, direction.z, HORIZONTAL_ACCELERATION * delta)
	elif input_dir != Vector3.ZERO:
		# air (including the frame you jump): Source-style air strafing.
		# It can add speed but never takes any away, and there is no ground friction.
		air_accelerate(wish_dir, delta)
	walk_velocity = walk_velocity.limit_length(MAX_SPEED)

	knockback = knockback.move_toward(Vector3.ZERO, KNOCKBACK_DECAY * delta)

	velocity.x = walk_velocity.x + knockback.x
	velocity.z = walk_velocity.z + knockback.z
	var angle=5
	var t = delta * 6
	if Input.mouse_mode==Input.MOUSE_MODE_CAPTURED: 
		rotation_degrees=rotation_degrees.lerp(Vector3(input_dir.normalized().y*angle,rotation_degrees.y,-input_dir.normalized().x*angle),t)


	# shooting
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_action_pressed("shoot"):
		if not gun_anim.is_playing():
			gun_anim.play("shoot")
			muzzle_flash()
			apply_knockback(camera.global_transform.basis.z * 6.0)

			var instance = bullet.instantiate()
			get_tree().current_scene.add_child(instance)
			instance.global_transform = Transform3D(
				camera.global_transform.basis.orthonormalized(),
				gun_barrel.global_position)
			instance.shooter = self

	update_duck(delta)

	# the one and only move_and_slide() for the whole controller
	floor_snap_length = SLIDE_SNAP if sliding else DEFAULT_SNAP
	move_and_slide()


func air_accelerate(wish_dir: Vector3, delta):
	# only the part of your speed that points along wish_dir counts, so
	# turning your view while holding A/D keeps adding speed (air strafing)
	var current_speed = walk_velocity.dot(wish_dir)
	var add_speed = AIR_CAP - current_speed
	if add_speed <= 0.0:
		return
	var accel_speed = min(AIR_ACCEL * SPEED * delta, add_speed)
	walk_velocity += wish_dir * accel_speed


func slide(delta):
	if not sliding:
		# slide start: boost in the direction you're running, then a cooldown
		# so tapping slide over and over can't stack the boost
		if slide_cooldown_left <= 0.0:
			var dir = Vector3(walk_velocity.x, 0, walk_velocity.z).normalized()
			walk_velocity += dir * SLIDE_BOOST
			slide_cooldown_left = SLIDE_COOLDOWN
	sliding = true

	# gravity along the slope: speeds you up downhill, slows you down uphill
	var slope_accel = (Vector3.DOWN * gravity).slide(get_floor_normal())
	walk_velocity.x += slope_accel.x * delta
	walk_velocity.z += slope_accel.z * delta

	# optional friction (0 by default = no momentum loss)
	walk_velocity = walk_velocity.move_toward(Vector3.ZERO, SLIDE_FRICTION * delta)
	walk_velocity = walk_velocity.limit_length(MAX_SPEED)

	if walk_velocity.length() < SLIDE_MIN_SPEED:
		sliding = false
		can_slide = false


func update_duck(delta):
	if sliding and not ducked:
		ducked = true
		set_shape_height(stand_height - SLIDE_DROP)
	elif ducked and not sliding and can_stand():
		# only stand up when there is room, so you can't end a slide inside a ceiling
		ducked = false
		set_shape_height(stand_height)
	# move the camera's local y only (assigning the whole transform would reset your mouse pitch)
	var target_y = camera_rest_y - (SLIDE_DROP if ducked else 0.0)
	camera.position.y = move_toward(camera.position.y, target_y, DUCK_SPEED * delta)


func can_stand() -> bool:
	# the body is currently shrunk: would it hit something if it grew back to full height?
	var grow = stand_height - get_shape_height()
	return not test_move(global_transform, Vector3.UP * grow)


func get_shape_height() -> float:
	var s = collision_shape.shape
	if s is CapsuleShape3D or s is CylinderShape3D:
		return s.height
	if s is BoxShape3D:
		return s.size.y
	return 2.0


func set_shape_height(h: float):
	var s = collision_shape.shape
	if s is CapsuleShape3D:
		s.height = max(h, s.radius * 2.0)
	elif s is CylinderShape3D:
		s.height = h
	elif s is BoxShape3D:
		s.size.y = h
	else:
		return
	# keep the feet where they are: the shape's centre moves down by half of what was removed
	collision_shape.position.y = shape_rest_y - (stand_height - get_shape_height()) / 2.0
