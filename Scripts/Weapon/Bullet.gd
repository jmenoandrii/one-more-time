extends CharacterBody3D


const SPEED := 50.0
var lifetime := 2.0
var damage: float = 0.0


func _ready() -> void:
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _process(delta: float) -> void:
	var collision = move_and_collide(-transform.basis.z * SPEED * delta)
	
	if collision:
		var hit_object = collision.get_collider()
		print("[BULLET]: hit '", hit_object.name, "'!")
		
		var health_component = hit_object.get_node_or_null("HealthComponent")
		
		if health_component and health_component.has_method("take_damage"):
			health_component.take_damage(damage)
			
		queue_free()
	
