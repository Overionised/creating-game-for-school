extends Node3D

@onready var ray: RayCast3D = $"../RayCast3D" 
const MAX_PULL := 10
var rest_pos: Vector3

func _ready():
	rest_pos = position
	ray.add_exception($"../..")  # ignore the player body (owner = scene root; adjust if your player isn't it)

func _process(delta):
	var pull := 0.0
	if ray.is_colliding():
		var dist := ray.global_position.distance_to(ray.get_collision_point())
		pull = clampf(ray.target_position.length() - dist, 0.0, MAX_PULL)
	var target := rest_pos + Vector3(0, 0, pull)  # +Z = back toward the camera
	position = position.lerp(target, 1.0 - exp(-15.0 * delta))
