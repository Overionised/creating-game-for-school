extends Node3D

const SPEED = 40.0
const EXPLOSION = preload("res://explosion.tscn")

@onready var mesh = $MeshInstance3D
@onready var particles = $GPUParticles3D
@onready var explosion = $Explosion

var shooter: CollisionObject3D
var hit := false

func _ready():
	get_tree().create_timer(5.0).timeout.connect(queue_free)

func _physics_process(delta):
	if hit:
		return

	var from = global_position
	var to = from - global_transform.basis.z.normalized() * SPEED * delta

	var query = PhysicsRayQueryParameters3D.create(from, to)
	if shooter:
		query.exclude = [shooter.get_rid()]
	var result = get_world_3d().direct_space_state.intersect_ray(query)

	if result:
		hit = true
		global_position = result.position
		mesh.visible = false
		particles.restart()
		explode()
	else:
		global_position = to
var exploded := false

func explode():
	if exploded:
		return
	exploded = true

	var e = EXPLOSION.instantiate()
	get_tree().current_scene.add_child(e)
	e.global_position = global_position

	var anim: AnimationPlayer = e.find_child("AnimationPlayer", true, false)
	anim.animation_finished.connect(func(_name): e.queue_free())
	anim.play("Explode") #broken

	queue_free()
