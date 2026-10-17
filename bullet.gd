extends Node3D

const SPEED = 40.0

const BLAST_RADIUS = 7.0
const BLAST_FORCE = 15.0

const EXPLOSION = preload("res://explosion.tscn")
const EXPLOSION_PARTICLES = preload("res://Scenes/exp_particles.tscn")

@onready var mesh = $MeshInstance3D
@onready var particles = $GPUParticles3D

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

	# --- Direct Knockback Query ---
	for player in get_tree().get_nodes_in_group("player"):
		var dist = global_position.distance_to(player.global_position)
		
		if dist <= BLAST_RADIUS:
			var falloff = 1.0 - (dist / BLAST_RADIUS)
			var dir = (player.global_position - global_position).normalized()
			dir.y = max(dir.y + 0.5, 0.5)
			
			var impulse = dir.normalized() * (BLAST_FORCE * falloff)
			print("Explosion hit player with impulse: ", impulse)
			player.apply_knockback(impulse)

	# --- Audio FX (Spawned into the main scene so queue_free doesn't kill it) ---
		var sfx = AudioStreamPlayer3D.new()
		sfx.stream = load("res://sfx/explosion-sfx.wav")
		sfx.pitch_scale = randf_range(0.98, 1.02) 
		sfx.volume_db = linear_to_db(0.2)
		get_tree().current_scene.add_child(sfx)
		sfx.global_position = global_position
		sfx.finished.connect(sfx.queue_free)
		sfx.play()


	# --- Visual FX Setup ---
	var e = EXPLOSION.instantiate()
	get_tree().current_scene.add_child(e)
	e.global_position = global_position

	var anim: AnimationPlayer = e.find_child("AnimationPlayer", true, false)
	if anim and anim.has_animation("explode"):
		anim.animation_finished.connect(func(_n): e.queue_free())
		anim.play("explode")
		var p = EXPLOSION_PARTICLES.instantiate()
		get_tree().current_scene.add_child(p)
		p.global_position = global_position
	else:
		push_warning("Explosion anim not found.")
		get_tree().create_timer(1.0).timeout.connect(e.queue_free)

	queue_free()
