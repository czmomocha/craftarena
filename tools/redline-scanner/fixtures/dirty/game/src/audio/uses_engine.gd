extends RefCounted


func play() -> void:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.play()
