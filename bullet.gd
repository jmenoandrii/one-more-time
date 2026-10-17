extends CharacterBody3D


const SPEED = 50.0


func _process(delta: float) -> void:
	position += transform.basis * Vector3(0,0,-SPEED) * delta
	
