extends Area3D

@export var blast_force: float = 100.0
@export var upward_bias: float = 100.6

# Keep track of bodies already pushed so they don't get double knockback
var affected_bodies: Array[Node] = []

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
	# Wait one frame for Godot's physics engine to register overlapping bodies on spawn
	await get_tree().physics_frame
	check_already_overlapping()

func check_already_overlapping() -> void:
	for body in get_overlapping_bodies():
		_apply_blast(body)

func _on_body_entered(body: Node) -> void:
	_apply_blast(body)

func _apply_blast(body: Node) -> void:
	if body in affected_bodies:
		return
		
	if body.has_method("apply_knockback"):
		affected_bodies.append(body)
		
		# Direction pointing away from explosion center
		var dir = body.global_position - global_position
		
		# If the explosion is right on top of the player center, default to pushing UP
		if dir.length_squared() < 0.001:
			dir = Vector3.UP
		else:
			dir = dir.normalized()
		
		dir.y += upward_bias
		var impulse = dir.normalized() * blast_force
		
		body.apply_knockback(impulse)
