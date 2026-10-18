extends CharacterBody3D

# Keeps its distance and throws stones. With a rigged model (EnemyAnimator) the stone is held
# in the palm during the throw animation and flies out of it at throw_release_time;
# without one it just appears at ThrowPos after the windup.

@export var stone_scene: PackedScene
@export var stone_damage: float = 15.0
@export var melee_damage: float = 10.0
@export var windup_time: float = 0.5 # aiming pause before the throw
@export var cooldown_time: float = 1.5 # pause after the throw
@export var stop_distance: float = 12.0

@export var speed: float = 4.0
@export var aggro_time: float = 2.0
var aggro_time_left: float = 0.0

@export_group("Throw")
@export var throw_release_time: float = 0.78 # s into the throw animation: the arm is straight, the stone leaves the palm
@export var hand_bone: String = "RightHand" # end of the bone name; the forearm is "<side>ForeArm"
@export var palm_offset: float = 0.1 # the palm is this far past the wrist, toward the fingers, m

@onready var detection_area: Area3D = $DetectionArea
@onready var sight_ray: RayCast3D = $SightRay
@onready var throw_pos: Marker3D = $ThrowPos
@onready var health_component: Node = $HealthComponent
@onready var damage_area: Node = $DamageArea
@onready var animator: EnemyAnimator = get_node_or_null("EnemyAnimator")

var player: Node3D = null
var can_see_player := false
var is_throwing := false # blocks walking while aiming / throwing / cooling down

enum ThrowState { READY, WINDUP, THROWING, COOLDOWN }
var _throw_state := ThrowState.READY
var _state_time := 0.0
var _throw_length := 0.0
var _released := false
var _held_stone: Node3D # the stone's look, shown in the palm during the throw
var _hand := -1
var _forearm := -1

@export_group("Randomization")

@export_subgroup("Scale")
@export var min_height_offset: float = 0.1
@export var max_offset: float = 0.1

@export_subgroup("Speed")
@export var min_speed_offset: float = 1.5
@export var max_speed_offset: float = 0.5

@export_subgroup("Damage")
@export var min_melee_damage_offset: float = 2.0
@export var max_melee_damage_offset: float = 2.0
@export var min_range_damage_offset: float = 2.0
@export var max_range_damage_offset: float = 2.0

@export_subgroup("Cooldown timer")
@export var min_windup_offset: float = 0.1
@export var max_windup_offset: float = 0.2
@export var min_cooldown_offset: float = 0.3
@export var max_cooldown_offset: float = 0.2


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

	stone_damage += randf_range(-min_range_damage_offset, max_range_damage_offset)

	melee_damage += randf_range(-min_melee_damage_offset, max_melee_damage_offset)
	if has_node("DamageArea") and "damage_amount" in damage_area:
		damage_area.damage_amount = melee_damage

	windup_time = max(0.01, windup_time + randf_range(-min_windup_offset, max_windup_offset))
	cooldown_time = max(0.01, cooldown_time + randf_range(-min_cooldown_offset, max_cooldown_offset))

	if _uses_throw_animation():
		_hand = animator.find_bone(hand_bone)
		_forearm = animator.find_bone(hand_bone.replace("Hand", "ForeArm"))
		_create_held_stone()

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

	_update_throw(delta)

	# movement and attack
	if can_see_player and player:
		# turn to player
		var look_pos = Vector3(player.global_position.x, global_position.y, player.global_position.z)
		if global_position.distance_squared_to(look_pos) > 0.01:
			look_at(look_pos, Vector3.UP)

		var distance_to_player = global_position.distance_to(player.global_position)

		# close enough: stop and throw
		if distance_to_player <= stop_distance:
			velocity.x = move_toward(velocity.x, 0, speed)
			velocity.z = move_toward(velocity.z, 0, speed)

			if _throw_state == ThrowState.READY:
				_set_state(ThrowState.WINDUP)
		# move to player
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
	_update_locomotion()

# the held stone follows the hand every rendered frame, not only on physics ticks
func _process(_delta: float) -> void:
	if _held_stone and _held_stone.visible:
		_held_stone.global_position = _get_palm_position()

func _uses_throw_animation() -> bool:
	return animator != null and animator.can_attack()

func _set_state(state: ThrowState) -> void:
	_throw_state = state
	_state_time = 0.0
	is_throwing = state != ThrowState.READY

func _update_throw(delta: float) -> void:
	if _throw_state == ThrowState.READY:
		return
	_state_time += delta

	match _throw_state:
		ThrowState.WINDUP:
			if _state_time < windup_time:
				return
			if not can_see_player or player == null:
				_set_state(ThrowState.READY)
			elif _uses_throw_animation():
				_set_state(ThrowState.THROWING)
				_released = false
				_throw_length = animator.play_random_attack()
				if _held_stone:
					_held_stone.global_position = _get_palm_position()
					_held_stone.visible = true
			else:
				_release_stone()
				_set_state(ThrowState.COOLDOWN)

		ThrowState.THROWING:
			if not _released and _state_time >= throw_release_time:
				_release_stone()
			if _state_time >= _throw_length:
				_set_state(ThrowState.COOLDOWN)

		ThrowState.COOLDOWN:
			if _state_time >= cooldown_time:
				_set_state(ThrowState.READY)

func _release_stone() -> void:
	_released = true
	if _held_stone:
		_held_stone.visible = false
	if stone_scene == null:
		return

	var from := _get_palm_position()
	# lost the player mid-throw: the stone still flies where the monster faces
	var target_point := from - global_basis.z * 10.0
	if player:
		target_point = player.global_position + Vector3(0, 1.0, 0)

	var stone = stone_scene.instantiate()
	if "damage" in stone:
		stone.damage = stone_damage
	# the palm can be inside the monster's own collision box
	stone.add_collision_exception_with(self)
	stone.transform = Transform3D(Basis.looking_at(target_point - from, Vector3.UP), from)
	get_tree().root.add_child(stone)

func _get_palm_position() -> Vector3:
	if _hand < 0:
		return throw_pos.global_position
	var hand := animator.get_bone_position(_hand)
	if _forearm < 0:
		return hand
	var forearm := animator.get_bone_position(_forearm)
	return hand + (hand - forearm).normalized() * palm_offset

# the stone's meshes without its body: instanced once, only the visuals are kept
func _create_held_stone() -> void:
	if stone_scene == null:
		return
	var stone := stone_scene.instantiate()
	_held_stone = Node3D.new()
	_held_stone.top_level = true
	_held_stone.visible = false
	for child in stone.get_children():
		if child is VisualInstance3D:
			child.reparent(_held_stone, false)
	stone.free()
	add_child(_held_stone)

func _update_locomotion() -> void:
	if animator == null or _throw_state == ThrowState.THROWING:
		return
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if horizontal_speed > 0.1:
		animator.play_walk(horizontal_speed)
	else:
		animator.play_idle()

func _on_damage_caused(amount: float) -> void:
	aggro_time_left = aggro_time

	if player == null:
		player = get_tree().current_scene.get_node_or_null("Player")

func die():
	queue_free()
