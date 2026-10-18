extends CharacterBody3D

@onready var detection_area: Area3D = $DetectionArea
@onready var sight_ray: RayCast3D = $SightRay
@onready var health_component: Node = $HealthComponent
@onready var damage_area: Node = $DamageArea

var player: Node3D = null
var is_chasing := false

@export var speed: float = 4.0
@export var melee_damage: float = 15.0
@export var xp_reward: int = 10
@export var aggro_time: float = 2.0
var aggro_time_left: float = 0.0

@export_group("Randomization")

@export_subgroup("Scale")
@export var min_height_offset: float = 0.1
@export var max_offset: float = 0.1

@export_subgroup("Speed")
@export var min_speed_offset: float = 0.2
@export var max_speed_offset: float = 0.2

@export_subgroup("Damage")
@export var min_melee_damage_offset: float = 2.0
@export var max_melee_damage_offset: float = 2.0

@export_subgroup("Ex reward")
@export var min_xp_reward_offset: int = 0
@export var max_xp_reward_offset: int = 0


func _ready() -> void:
	sight_ray.add_exception(self)
	
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)
	
	health_component.died.connect(die)
	health_component.damage_caused.connect(_on_damage_caused)
	
	# Randomization
	speed += randf_range(-min_speed_offset, max_speed_offset)
	
	var random_scale = 1.0 + randf_range(-min_height_offset, max_offset)
	scale = Vector3(random_scale, random_scale, random_scale)
	
	melee_damage += randf_range(-min_melee_damage_offset, max_melee_damage_offset)
	if "damage_amount" in damage_area:
		damage_area.damage_amount = melee_damage
	
	xp_reward += randi_range(-min_xp_reward_offset, max_xp_reward_offset)

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
	RunState.add_xp(xp_reward)
	queue_free()
