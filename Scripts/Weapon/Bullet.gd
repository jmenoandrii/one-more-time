extends CharacterBody3D


const SPEED := 50.0
var lifetime := 2.0
var damage := 25.0 # set by the weapon that fired it


func _ready() -> void:
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _process(delta: float) -> void:
	var collision = move_and_collide(-transform.basis.z * SPEED * delta)
	
	if collision:
		var hit_object = collision.get_collider()
		print("[BULLET]: hit '", hit_object.name, "'!")
		
		if hit_object.has_method("take_damage"):
			hit_object.take_damage(damage)
			
		queue_free()
	
