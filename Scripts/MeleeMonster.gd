extends CharacterBody3D

@onready var detection_area: Area3D = $DetectionArea
@onready var sight_ray: RayCast3D = $SightRay
@onready var health_component: Node = $HealthComponent
@onready var damage_area: Node = $DamageArea
@onready var animator: EnemyAnimator = get_node_or_null("EnemyAnimator")
@onready var goblin_sound: AudioStreamPlayer3D = $GoblinSound
@onready var goblin_attack: AudioStreamPlayer3D = $GoblinAttack
@onready var goblin_ambient: GoblinGrowl = $GoblinAmbient
@onready var goblin_hurt: AudioStreamPlayer3D = get_node_or_null("GoblinHurt")

var player: Node3D = null
var is_chasing := false

@export var speed: float = 2.0
@export var melee_damage: float = 15.0
@export var xp_reward: int = 10
@export var aggro_time: float = 2.0
var aggro_time_left: float = 0.0

# with attack animations the monster stops in range and hits on the swing;
# without them (no rigged model) the DamageArea deals contact damage as before
@export_group("Attack")
@export var attack_range: float = 1.6 # starts an attack when the player is this close, m
@export var attack_hit_time: float = 0.5 # the hit lands at this part of the animation, 0..1
@export var attack_cooldown: float = 0.4 # pause after an attack, s
var is_attacking := false
var _attack_length := 0.0
var _attack_time := 0.0
var _attack_hit_done := false
var _attack_cooldown_left := 0.0

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
	add_to_group("enemy") # World opens the final gate when the group is empty
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
	if _uses_attack_animations():
		damage_area.monitoring = false
	
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
	
	# asleep until the level timer starts: just stand (and fall)
	if not GameEvents.level_running:
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
		_update_locomotion()
		return
	
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
	
	goblin_ambient.active = is_chasing # growls only while after the player
	_update_attack(delta)
	
	# chasing
	if is_attacking:
		velocity.x = 0
		velocity.z = 0
		_face(player)
	elif is_chasing and player and _uses_attack_animations() and _in_attack_range(attack_range):
		velocity.x = 0
		velocity.z = 0
		_face(player)
		if _attack_cooldown_left <= 0.0:
			_start_attack()
	elif is_chasing and player:
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
	_update_locomotion()

func _uses_attack_animations() -> bool:
	return animator != null and animator.can_attack()

func _in_attack_range(range_m: float) -> bool:
	
	if player == null:
		return false
	var offset := player.global_position - global_position
	offset.y = 0
	return offset.length() <= range_m

func _face(target: Node3D) -> void:
	if target == null:
		return
	var look_pos := Vector3(target.global_position.x, global_position.y, target.global_position.z)
	if global_position.distance_squared_to(look_pos) > 0.01:
		look_at(look_pos, Vector3.UP)

func _start_attack() -> void:
	is_attacking = true
	_attack_time = 0.0
	_attack_hit_done = false
	_attack_length = animator.play_random_attack()
	goblin_attack.play()

func _update_attack(delta: float) -> void:
	_attack_cooldown_left = maxf(_attack_cooldown_left - delta, 0.0)
	if not is_attacking:
		return
	
	_attack_time += delta
	# the hit only lands if the player is still close (a bit of slack for the swing)
	if not _attack_hit_done and _attack_time >= _attack_length * attack_hit_time:
		_attack_hit_done = true
		if _in_attack_range(attack_range * 1.3):
			var health := player.get_node_or_null("HealthComponent") as HealthComponent
			if health:
				health.take_damage(melee_damage)
	
	if _attack_time >= _attack_length:
		is_attacking = false
		_attack_cooldown_left = attack_cooldown

func _update_locomotion() -> void:
	if animator == null or is_attacking:
		return
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if horizontal_speed > 0.1:
		animator.play_walk(horizontal_speed)
	else:
		animator.play_idle()

func _on_damage_caused(amount: float) -> void:
	aggro_time_left = aggro_time
	if goblin_hurt and health_component.current_health > 0: # the killing hit has the death sound
		goblin_hurt.play()
	
	if player == null:
		player = get_tree().current_scene.get_node_or_null("Player")

func die():
	RunState.add_xp(xp_reward)
	GameEvents.enemy_killed.emit()
	# the goblin is freed right away: its death sound plays on its own, where it died
	OneShotSound.play_copy(goblin_sound)
	queue_free()
