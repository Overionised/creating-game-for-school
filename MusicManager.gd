# MusicManager.gd (Set as Autoload in Project Settings)
extends Node

@onready var player = AudioStreamPlayer.new()

func _ready() -> void:
	add_child(player)

func play_music(stream: AudioStream, volume_db: float = 0.0) -> void:
	if player.stream == stream and player.playing:
		return # Already playing this track
	
	player.stream = stream
	player.volume_db = volume_db
	player.play()
