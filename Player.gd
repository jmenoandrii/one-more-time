extends CharacterBody3D

const SPEED = 5.0
const RUNNING_SPEED = 10.0
const CROUCH_SPEED = 2.5
const JUMP_VELOCITY = 5.5
var mouse_sensitivity := 0.002

const CROUCH_PERSENT = 0.5
var normal_height: float
var crouch_height: float	# = normal_height - normal_height * CROUCH_PERSENT

var is_crouching := false
var is_player_dead := false
var is_cursor_locked := true

var head_world_position: Vector3

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

@onready var aim_ray: RayCast3D = $Head/Camera3D/AimRay
@onready var ammo_label: Label = $"../HUD/AmmoLabel"
@onready var weapons_manager: Node3D = $Head/Camera3D/Weapons
var weapons: Array[Node] = []
var current_weapon_index: int = -1


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	normal_height = collision_shape.shape.height
	crouch_height = normal_height - (normal_height * CROUCH_PERSENT)
	
	weapons = weapons_manager.get_children()
	for w in weapons:
		w.ammo_updated.connect(_update_ammo_ui)
	equip_weapon(-1)

	mouse_sensitivity = Settings.mouse_sensitivity * 0.0005
	
	GameEvents.pause_pressed.connect(_on_pause_pressed)
	GameEvents.unpause_pressed.connect(_on_unpause_pressed)
	GameEvents.sensitivity_changed.connect(_on_sensitivity_changed)
	
func _unhandled_input(event: InputEvent) -> void:
	# Mouse rotation
	if is_player_dead or not is_cursor_locked:
		pass
	elif event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-85.0), deg_to_rad(85.0))
	
	if current_weapon_index != -1:
		# Shooting
		if Input.is_action_just_pressed("click"):
			var target_point: Vector3
			
			if aim_ray.is_colliding():
				target_point = aim_ray.get_collision_point()
			else:
				target_point = aim_ray.to_global(aim_ray.target_position)
				
			weapons[current_weapon_index].shoot(target_point)
		
		# Reload
		if Input.is_action_just_pressed("reload"):
			weapons[current_weapon_index].reload()
	
	# Change weapon
	if Input.is_action_just_pressed("weapon_1"):
		equip_weapon(0)
	elif Input.is_action_just_pressed("weapon_2"):
		equip_weapon(1)
		
func _on_pause_pressed() -> void:
	is_cursor_locked = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_unpause_pressed() -> void:
	is_cursor_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_sensitivity_changed(value: float) -> void:
	mouse_sensitivity = value * 0.0005

func _physics_process(delta: float) -> void:
	# gravity
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# dead
	if is_player_dead:
		_process_death()
		move_and_slide()
		return
	
	# crouching
	if Input.is_action_pressed("crouch"):
		is_crouching = true
	else:
		if not is_on_ceiling():
			is_crouching = false
	
	var target_height := crouch_height if is_crouching else normal_height
	
	collision_shape.shape.height = lerp(collision_shape.shape.height, target_height, 10.0 * delta)
	if mesh_instance.mesh is CapsuleMesh:
		mesh_instance.mesh.height = lerp(mesh_instance.mesh.height, target_height, 10.0 * delta)
	
	collision_shape.position.y = collision_shape.shape.height / 2.0
	mesh_instance.position.y = collision_shape.shape.height / 2.0
	
	head.position.y = collision_shape.shape.height - 0.5
	
	# jumping
	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_crouching:
		velocity.y = JUMP_VELOCITY
	elif Input.is_action_just_released("jump") and velocity.y > 0.0:
		velocity.y = 0.0
	
	# moving
	var current_speed := CROUCH_SPEED if is_crouching else (RUNNING_SPEED if Input.is_action_pressed("run") else SPEED)
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	move_and_slide()

func die() -> void:
	if is_player_dead: return
	
	is_player_dead = true
	head_world_position = head.global_position

func _process_death() -> void:
	head.global_position = head.global_position.move_toward(global_position, 0.1)
	
	velocity.x = move_toward(velocity.x, 0, 0.5)
	velocity.z = move_toward(velocity.z, 0, 0.5)

func equip_weapon(index: int) -> void:
	if index < -1 or index >= weapons.size(): 
		return
	
	current_weapon_index = index
	
	for i in range(weapons.size()):
		weapons[i].visible = (i == current_weapon_index)
		
	if current_weapon_index == -1:
		ammo_label.text = ""
	else:
		var current_w = weapons[current_weapon_index]
		_update_ammo_ui(current_w.current_ammo, current_w.max_ammo)

func _update_ammo_ui(current: int, maximum: int) -> void:
	ammo_label.text = str(current) + " / " + str(maximum)
