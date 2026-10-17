extends CharacterBody3D

# Movements
const SPEED: float  = 5.0
const RUNNING_SPEED: float = 10.0
const CROUCH_SPEED: float = 2.5
const JUMP_VELOCITY: float = 5.5
var mouse_sensitivity: float = 0.002

const CROUCH_PERSENT: float = 0.5
var normal_height: float
var crouch_height: float	# = normal_height - normal_height * CROUCH_PERSENT

# Stamina
const MAX_STAMINA: float = 100.0
const STAMINA_DRAIN_RATE: float = 20.0 # per second
const STAMINA_REGEN_RATE: float = 15.0 # per second
var current_stamina: float = MAX_STAMINA

@onready var stamina_label: Label = $"../UI/HUD/StaminaLabel"
signal stamina_changed(current: float, maximum: float)

# state params
var is_crouching := false
var is_player_dead := false
var is_cursor_locked := true

# referens
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

# shooting
@onready var aim_ray: RayCast3D = $Head/Camera3D/AimRay
@onready var ammo_label: Label = $"../UI/HUD/AmmoLabel"
@onready var weapons_manager: Node3D = $Head/Camera3D/Weapons
var weapons: Array[Node] = []
var current_weapon_index: int = -1

@onready var reserve_ammo_label: Label = $"../UI/HUD/reserveAmmo"
var current_reserve_ammo: int = 18

# health
@onready var health_label: Label = $"../UI/HUD/HealthLabel"
@onready var health_component: Node = $HealthComponent

# audio
@onready var dirt_step: AudioStreamPlayer3D = $Sounds/dirt
@onready var stone_step: AudioStreamPlayer3D = $Sounds/stone
@onready var headbob: AnimationPlayer = $Head/headbob
@onready var jump_sound: AudioStreamPlayer3D = $Sounds/jump



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
	
	health_component.died.connect(die)
	health_component.health_changed.connect(_update_health_ui)
	health_component.heal(0)	# to update health_ui
	
	stamina_changed.connect(_update_stamina_ui)
	stamina_changed.emit(current_stamina, MAX_STAMINA)
	
func _unhandled_input(event: InputEvent) -> void:
	if is_player_dead:
		return
		
	# Mouse rotation
	if is_cursor_locked and event is InputEventMouseMotion:
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
			current_reserve_ammo = weapons[current_weapon_index].reload(current_reserve_ammo)
			_update_reserve_ammo_ui(current_reserve_ammo)
	
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
	# weapon inspect (polled every frame, so releasing the button during pause isn't missed)
	if current_weapon_index != -1:
		var wants_inspect := Input.is_action_pressed("inspect") and is_cursor_locked and not is_player_dead
		weapons[current_weapon_index].set_inspecting(wants_inspect)

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
		jump_sound.play()
	elif Input.is_action_just_released("jump") and velocity.y > 0.0:
		
		velocity.y = 0.0
	
	# moving
	var current_speed: float
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var is_running := Input.is_action_pressed("run") and is_on_floor() and not is_crouching
	var is_moving := input_dir != Vector2.ZERO # Перевіряємо, чи гравець взагалі йде
	
	if is_running and is_moving and current_stamina > 0:
		current_speed = RUNNING_SPEED
		current_stamina -= STAMINA_DRAIN_RATE * delta
		stamina_changed.emit(current_stamina, MAX_STAMINA)
	else:
		current_speed = CROUCH_SPEED if is_crouching else SPEED
		# Відновлюємо стаміну, якщо не біжимо
		if current_stamina < MAX_STAMINA:
			current_stamina += STAMINA_REGEN_RATE * delta
			stamina_changed.emit(current_stamina, MAX_STAMINA)
	
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
		if current_speed == RUNNING_SPEED:
			headbob.speed_scale = 2
		else:
			headbob.speed_scale = 1
			
		if not headbob.is_playing():
			headbob.play("new_animation")
		
	else:
		headbob.stop()
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	move_and_slide()

func die() -> void:
	print("! Player DIE !")
	if is_player_dead: return
	
	is_player_dead = true

func _process_death() -> void:
	head.global_position = head.global_position.move_toward(global_position, 0.1)
	
	velocity.x = move_toward(velocity.x, 0, 0.5)
	velocity.z = move_toward(velocity.z, 0, 0.5)

func play_step_sounds():
	if $floortype_ray.is_colliding():
		var collider = $floortype_ray.get_collider()
		if collider.is_in_group("dirt"):
			stone_step.stop()
			if not stone_step.playing:
				dirt_step.play()
		elif collider.is_in_group("stone"):
			dirt_step.stop()
			if not stone_step.playing:
				stone_step.play()
		else:
			dirt_step.stop()
			stone_step.stop()
	else:
		dirt_step.stop()
		stone_step.stop()

func pick_up_weapon(weapon_name: String) -> bool:
	for i in weapons.size():
		if weapons[i].weapon_name == weapon_name:
			if weapons[i].is_owned:
				return false        # уже є — пікап лишається на мапі
			weapons[i].is_owned = true
			equip_weapon(i)         # одразу в руки
			weapons[i].play_equip()
			return true
	return false

func equip_weapon(index: int) -> void:
	if index < -1 or index >= weapons.size():
		return
		
	if not weapons[index].is_owned:
		return

	current_weapon_index = index
	
	for i in range(weapons.size()):
		weapons[i].visible = (i == current_weapon_index)
		if i != current_weapon_index:
			weapons[i].set_inspecting(false)
		
	if current_weapon_index == -1:
		ammo_label.text = ""
		reserve_ammo_label.text = ""
	else:
		var current_w = weapons[current_weapon_index]
		_update_ammo_ui(current_w.current_ammo, current_w.max_ammo)
		_update_reserve_ammo_ui(current_reserve_ammo)

func _update_ammo_ui(current: int, maximum: int) -> void:
	ammo_label.text = str(current) + " / " + str(maximum)

func _update_reserve_ammo_ui(ammo: int):
	reserve_ammo_label.text = str(ammo)

func _update_health_ui(current: int, maximum: int) -> void:
	health_label.text = str(current) + " / " + str(maximum)

func _update_stamina_ui(current: int, maximum: int) -> void:
	stamina_label.text = str(current) + " / " + str(maximum)
