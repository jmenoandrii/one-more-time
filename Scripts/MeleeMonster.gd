extends CharacterBody3D

@export var speed: float = 4.0
@export var aggro_time: float = 2.0
var aggro_time_left: float = 0.0


@onready var detection_area: Area3D = $DetectionArea
@onready var sight_ray: RayCast3D = $SightRay
@onready var health_component: Node = $HealthComponent

var player: Node3D = null
var is_chasing := false


func _ready() -> void:
	sight_ray.add_exception(self)
	
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)
	
	health_component.died.connect(die)
	health_component.damage_caused.connect(_on_damage_caused)

func _on_body_entered(body: Node3D) -> void:
	if body.name == "Player": 
		player = body

func _on_body_exited(body: Node3D) -> void:
	if body == player:
		player = null
		is_chasing = false

func _physics_process(delta: float) -> void:
	# gravity
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# sight system
	if aggro_time_left > 0:
		aggro_time_left -= delta
		is_chasing = true
	else:
		if player:
			sight_ray.target_position = sight_ray.to_local(player.global_position + Vector3(0, 1.0, 0))
			sight_ray.force_raycast_update()
			
			if sight_ray.is_colliding() and sight_ray.get_collider() == player:
				is_chasing = true
			else:
				is_chasing = false
		else:
			is_chasing = false
	
	# chasing
	if is_chasing and player:
		var direction = (player.global_position - global_position)
		direction.y = 0
		direction = direction.normalized()
		
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		
		var look_pos = Vector3(player.global_position.x, global_position.y, player.global_position.z)
		
		if global_position.distance_squared_to(look_pos) > 0.01:
			look_at(look_pos, Vector3.UP)
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()

func _on_damage_caused(amount: float) -> void:
	aggro_time_left = aggro_time
	
	if player == null:
		player = get_tree().current_scene.get_node_or_null("Player")

func die():
	queue_free()
