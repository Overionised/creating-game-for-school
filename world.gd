extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	MusicManager.play_music(preload("res://sfx/music/music-fx-plus-guitar.ogg"))



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
