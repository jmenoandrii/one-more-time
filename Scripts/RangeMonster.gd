extends CharacterBody3D

@export var stone_scene: PackedScene
@export var stone_damage: float = 15.0
@export var windup_time: float = 0.5 # cooldown befor throw
@export var cooldown_time: float = 1.5 # cooldown after throw
@export var stop_distance: float = 12.0

@export var speed: float = 4.0
@export var aggro_time: float = 2.0
var aggro_time_left: float = 0.0

@onready var detection_area: Area3D = $DetectionArea
@onready var sight_ray: RayCast3D = $SightRay
@onready var throw_pos: Marker3D = $ThrowPos
@onready var health_component: Node = $HealthComponent

var player: Node3D = null
var can_see_player := false
var is_throwing := false # Block movement and throwing when animation paly

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
		can_see_player = false

func _physics_process(delta: float) -> void:
	# gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# sight system
	if aggro_time_left > 0:
		aggro_time_left -= delta
		can_see_player = true
	else:
		if player:
			sight_ray.target_position = sight_ray.to_local(player.global_position + Vector3(0, 1.0, 0))
			sight_ray.force_raycast_update()
			
			if sight_ray.is_colliding() and sight_ray.get_collider() == player:
				can_see_player = true
			else:
				can_see_player = false

	# movement and attack
	if can_see_player and player:
		# turn to player
		var look_pos = Vector3(player.global_position.x, global_position.y, player.global_position.z)
		if global_position.distance_squared_to(look_pos) > 0.01:
			look_at(look_pos, Vector3.UP)

		var distance_to_player = global_position.distance_to(player.global_position)
		
		# move to player
		if distance_to_player <= stop_distance:
			velocity.x = move_toward(velocity.x, 0, speed)
			velocity.z = move_toward(velocity.z, 0, speed) # Повернули зупинку по Z!
			
			if not is_throwing:
				_throw_routine()
		# throw in player
		elif not is_throwing:
			var direction = (player.global_position - global_position).normalized()
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = move_toward(velocity.x, 0, speed)
			velocity.z = move_toward(velocity.z, 0, speed)
	else:
		# if do not see player just stand
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()

# Coroutine
func _throw_routine() -> void:
	is_throwing = true
	
	# 1. windup
	await get_tree().create_timer(windup_time).timeout
	
	if not is_inside_tree() or not can_see_player or not player:
		is_throwing = false
		return
		
	# 2. stone spawning
	if stone_scene:
		var stone = stone_scene.instantiate()
		
		if "damage" in stone:
			stone.damage = stone_damage
			
		get_tree().root.add_child(stone)
		stone.global_position = throw_pos.global_position
		
		var target_point = player.global_position + Vector3(0, 1.0, 0)
		stone.look_at(target_point, Vector3.UP)
		
	# 3. Cooldown
	await get_tree().create_timer(cooldown_time).timeout
	
	is_throwing = false

func _on_damage_caused(amount: float) -> void:
	aggro_time_left = aggro_time
	
	if player == null:
		player = get_tree().current_scene.get_node_or_null("Player")

func die():
	queue_free()
	
