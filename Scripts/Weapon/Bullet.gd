extends CharacterBody3D

var lifetime: float = 2.0
@export var speed: float = 50.0
@export var damage: float = 0.0
@export var target_obj_name := ""


func _ready() -> void:
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	var collision = move_and_collide(-transform.basis.z * speed * delta)
	
	if collision:
		var hit_object = collision.get_collider()
		print("[BULLET]: hit '", hit_object.name, "'!")
		
		if not target_obj_name or hit_object.name == target_obj_name:
			var health_component = hit_object.get_node_or_null("HealthComponent")
			
			if health_component and health_component.has_method("take_damage"):
				health_component.take_damage(damage)
			
		queue_free()
	
