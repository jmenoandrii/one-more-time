class_name OneShotSound

# Plays a copy of a 3D sound player once, on its own, and frees it after — for sounds that must
# outlive their owner (a death sound: the dying enemy is freed in the same frame).
# The copy keeps everything set up on the original (stream, volume, distance, bus).

static func play_copy(template: AudioStreamPlayer3D) -> void:
	if template == null or template.stream == null:
		return
	var sound := template.duplicate() as AudioStreamPlayer3D
	sound.autoplay = false
	sound.finished.connect(sound.queue_free)
	template.get_tree().current_scene.add_child(sound)
	sound.global_transform = template.global_transform
	sound.play()
