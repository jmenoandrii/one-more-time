extends CharacterBody3D

# Movements (the consts are the base values, the vars are with the run's upgrades)
const SPEED: float  = 5.0
const RUNNING_SPEED: float = 10.0
const CROUCH_SPEED: float = 2.5
var speed: float
var running_speed: float
var crouch_speed: float
const SENSITIVITY_SCALE := 0.0005
var mouse_sensitivity: float = 0.002

#jumping
const GROUND_ACCEL := 60.0
const GROUND_DECEL := 50.0
const AIR_ACCEL := 15.0
const FALL_GRAVITY_MULT := 1.8
const JUMP_CUT := 0.5
const COYOTE_TIME := 0.1
const JUMP_BUFFER := 0.1
const JUMP_VELOCITY: float = 5.5
var jump_velocity: float
var _air_speed := 0.0 # horizontal speed kept from the takeoff
var _coyote := 0.0
var _jump_buffer := 0.0

const CROUCH_PERSENT: float = 0.5
var normal_height: float
var crouch_height: float	# = normal_height - normal_height * CROUCH_PERSENT

@onready var floortype_ray: RayCast3D = $floortype_ray

# Stamina
const MAX_STAMINA: float = 100.0
const STAMINA_DRAIN_RATE: float = 20.0 # per second
const STAMINA_REGEN_RATE: float = 10.0 # per second
const STAMINA_JUMP_RATE: float = 10.0
var max_stamina: float
var stamina_drain_rate: float
var stamina_regen_rate: float
var stamina_jump_rate: float
var current_stamina: float

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
@onready var weapons_manager: Node3D = $Head/Camera3D/Weapons
var weapons: Array[Weapon] = []
var current_weapon_index: int = -1

const RESERVE_AMMO: int = 18
var current_reserve_ammo: int

# health
@onready var health_component: Node = $HealthComponent

# audio
@onready var dirt_step: AudioStreamPlayer3D = $Sounds/dirt
@onready var stone_step: AudioStreamPlayer3D = $Sounds/stone
@onready var headbob: AnimationPlayer = $Head/headbob
@onready var jump_sound: AudioStreamPlayer3D = $Sounds/jump

#interact
@onready var interact_ray: RayCast3D = $Head/Camera3D/InteractRay
const INTERACT_SEARCH_DEPTH := 3
var _interact_target: Node = null

# keys
var keys: Dictionary = {}

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_apply_upgrades()

	normal_height = collision_shape.shape.height
	crouch_height = normal_height - (normal_height * CROUCH_PERSENT)
	
	weapons.assign(weapons_manager.get_children())
	for w in weapons:
		w.ammo_updated.connect(_on_weapon_ammo_updated.bind(w))
		w.reserve_ammo_changed.connect(_on_weapon_reserve_ammo_changed)
	equip_weapon(-1)

	mouse_sensitivity = Settings.mouse_sensitivity * SENSITIVITY_SCALE
	
	GameEvents.pause_pressed.connect(_on_pause_pressed)
	GameEvents.unpause_pressed.connect(_on_unpause_pressed)
	GameEvents.sensitivity_changed.connect(_on_sensitivity_changed)
	
	health_component.died.connect(die)
	health_component.health_changed.connect(GameEvents.health_changed.emit)
	health_component.set_max_health(RunState.get_stat("max_health", health_component.max_health))

	stamina_changed.connect(GameEvents.stamina_changed.emit)
	stamina_changed.emit(current_stamina, max_stamina)

func _apply_upgrades() -> void:
	var move_mult := RunState.get_stat("move_speed", 1.0)
	speed = SPEED * move_mult
	running_speed = RUNNING_SPEED * move_mult
	crouch_speed = CROUCH_SPEED * move_mult
	jump_velocity = RunState.get_stat("jump", JUMP_VELOCITY)

	max_stamina = RunState.get_stat("max_stamina", MAX_STAMINA)
	stamina_drain_rate = RunState.get_stat("stamina_drain", STAMINA_DRAIN_RATE)
	stamina_regen_rate = RunState.get_stat("stamina_regen", STAMINA_REGEN_RATE)
	stamina_jump_rate = RunState.get_stat("stamina_jump", STAMINA_JUMP_RATE)
	current_stamina = max_stamina

	current_reserve_ammo = int(RunState.get_stat("reserve_ammo", RESERVE_AMMO))

func _unhandled_input(event: InputEvent) -> void:
	if is_player_dead:
		return
		
	if event.is_action_pressed("interact"):
		_try_interact()
		
	# Mouse rotation
	if is_cursor_locked and event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-85.0), deg_to_rad(85.0))
	
	if current_weapon_index != -1:
		# Shooting
		if Input.is_action_pressed("click"):
			var target_point: Vector3
			
			if aim_ray.is_colliding():
				target_point = aim_ray.get_collision_point()
			else:
				target_point = aim_ray.to_global(aim_ray.target_position)
				
			weapons[current_weapon_index].shoot(target_point)
		
		# Reload
		if Input.is_action_pressed("reload"):
			_reload_current_weapon()
	
	# Change weapon
	if Input.is_action_pressed("weapon_1"):
		equip_weapon(0)
	elif Input.is_action_pressed("weapon_2"):
		equip_weapon(1)
		
func _on_pause_pressed() -> void:
	is_cursor_locked = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_unpause_pressed() -> void:
	is_cursor_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_sensitivity_changed(value: float) -> void:
	mouse_sensitivity = value * SENSITIVITY_SCALE

# interactables implement interact(interactor) and optionally get_interact_text(interactor) -> String
func _try_interact() -> void:
	if is_instance_valid(_interact_target):
		_interact_target.interact(self)
		_update_interact_prompt() # the target's state changed (e.g. open -> closed)
		
func _update_interact_target() -> void:
	var target: Node = null if is_player_dead else _get_interactable()
	if target != _interact_target:
		_interact_target = target
		_update_interact_prompt()

func _update_interact_prompt() -> void:
	var text := ""
	if is_instance_valid(_interact_target):
		text = "[E] Interact"
		if _interact_target.has_method("get_interact_text"):
			text = _interact_target.get_interact_text(self)
	GameEvents.interact_prompt_changed.emit(text)

func add_key(key_id: String, key_color: Color) -> void:
	if key_id not in keys:
		keys[key_id] = key_color
	GameEvents.keys_changed.emit(keys)
	_update_interact_prompt() # picked up right in front of its door -> "Locked" becomes "Unlock"

func has_key(key_id: String) -> bool:
	return keys.has(key_id)

func remove_key(key_id: String) -> void:
	keys.erase(key_id)
	GameEvents.keys_changed.emit(keys)
		
func _get_interactable() -> Node:
	if not interact_ray.is_colliding():
		return null
	var node: Node = interact_ray.get_collider()
	for i in INTERACT_SEARCH_DEPTH:
		if node == null:
			return null
		if node.is_in_group("interactable") and node.has_method("interact"):
			return node
		node = node.get_parent()
	return null
	
func _physics_process(delta: float) -> void:
	_update_interact_target()
	
	if current_weapon_index != -1:
		var wants_inspect := Input.is_action_pressed("inspect") and is_cursor_locked and not is_player_dead
		weapons[current_weapon_index].set_inspecting(wants_inspect)

	# gravity
	if not is_on_floor():
		var mult := FALL_GRAVITY_MULT if velocity.y < 0.0 else 1.0
		velocity += get_gravity() * mult * delta
	
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
	
	# moving
	var on_floor := is_on_floor()
	var current_speed: float
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var is_moving := input_dir != Vector2.ZERO # Перевіряємо, чи гравець взагалі йде
	var is_running := Input.is_action_pressed("run") and is_on_floor() and not is_crouching and is_moving and current_stamina > 0

	if not on_floor:
		current_speed = _air_speed # keep the takeoff speed
	elif is_running:
		current_speed = running_speed
	else:
		current_speed = crouch_speed if is_crouching else speed

	if is_running:
		current_stamina -= stamina_drain_rate * delta
		stamina_changed.emit(current_stamina, max_stamina)
	elif current_stamina < max_stamina:
		current_stamina = min(current_stamina + stamina_regen_rate * delta, max_stamina)
		stamina_changed.emit(current_stamina, max_stamina)
	
	# jumping
	_coyote = COYOTE_TIME if is_on_floor() else _coyote - delta
	_jump_buffer = JUMP_BUFFER if Input.is_action_just_pressed("jump") else _jump_buffer - delta

	if _jump_buffer > 0.0 and _coyote > 0.0 and not is_crouching and current_stamina >= stamina_jump_rate:
		velocity.y = jump_velocity
		_jump_buffer = 0.0
		_coyote = 0.0
		_air_speed = maxf(Vector2(velocity.x, velocity.z).length(), speed)
		current_stamina = maxf(current_stamina - stamina_jump_rate, 0.0)
		stamina_changed.emit(current_stamina, max_stamina)
		jump_sound.play()
	elif Input.is_action_just_released("jump") and velocity.y > 0.0:
		velocity.y *= JUMP_CUT
	
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var target := direction * current_speed
	var accel := (GROUND_ACCEL if direction else GROUND_DECEL) if on_floor else AIR_ACCEL
	var horizontal := Vector2(velocity.x, velocity.z).move_toward(Vector2(target.x, target.z), accel * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.y

	if direction and on_floor:
		headbob.speed_scale = 2 if is_running else 1
	if not headbob.is_playing():
		headbob.play("new_animation")
	else:
		headbob.stop()

	move_and_slide()

func die() -> void:
	print("! Player DIE !")
	if is_player_dead: return

	is_player_dead = true
	GameEvents.player_died.emit()

func _process_death() -> void:
	head.global_position = head.global_position.move_toward(global_position, 0.1)
	
	velocity.x = move_toward(velocity.x, 0, 0.5)
	velocity.z = move_toward(velocity.z, 0, 0.5)

func play_step_sounds():
	if floortype_ray.is_colliding():
		var collider = floortype_ray.get_collider()
		if collider.is_in_group("dirt"):
			stone_step.stop()
			if not dirt_step.playing:
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

# gives the first not yet owned weapon this pickup belongs to:
# the 1st revolver pickup -> Revolver, the 2nd -> DualRevolvers (its pickup_name is "revolver")
func pick_up_weapon(pickup: String) -> bool:
	for i in weapons.size():
		var weapon := weapons[i]
		var weapon_pickup: String = weapon.pickup_name if weapon.pickup_name != "" else weapon.weapon_name
		if weapon_pickup == pickup and not weapon.is_owned:
			weapon.is_owned = true
			equip_weapon(i, false)  # the pickup has its own equip animation
			weapon.play_equip()
			return true
	return false     # everything from this pickup is already owned — it stays on the map

func equip_weapon(index: int, draw: bool = true) -> void:
	if index < -1 or index >= weapons.size():
		return
		
	# index -1 means "no weapon"; weapons[-1] would be the last weapon
	if index != -1 and not weapons[index].is_owned:
		return

	var switched := index != current_weapon_index
	current_weapon_index = index
	
	for i in range(weapons.size()):
		weapons[i].visible = (i == current_weapon_index)
		if i != current_weapon_index:
			weapons[i].set_inspecting(false)
		
	if current_weapon_index == -1:
		GameEvents.weapon_unequipped.emit()
	else:
		var current_w = weapons[current_weapon_index]
		if switched and draw:
			current_w.play_draw()
		GameEvents.ammo_changed.emit(current_w.current_ammo, current_w.max_ammo)
		GameEvents.cylinders_changed.emit(current_w.get_cylinder_rounds(), false)
		GameEvents.reserve_ammo_changed.emit(current_reserve_ammo)

func _reload_current_weapon() -> void:
	# Weapon.reload() waits for the reload animation, so it has to be awaited
	var weapon := weapons[current_weapon_index]
	current_reserve_ammo = await weapon.reload(current_reserve_ammo)
	GameEvents.reserve_ammo_changed.emit(current_reserve_ammo)

func _add_reserve_ammo(amount: int) -> void:
	current_reserve_ammo += amount
	GameEvents.reserve_ammo_changed.emit(current_reserve_ammo)

func _on_weapon_reserve_ammo_changed(amount: int) -> void:
	# the reserve is shared, so it's updated even if the reloading weapon was put away
	current_reserve_ammo = amount
	GameEvents.reserve_ammo_changed.emit(current_reserve_ammo)

func _on_weapon_ammo_updated(current: int, maximum: int, weapon: Weapon) -> void:
	# a hidden weapon may still finish its reload — only the weapon in hands goes to the HUD
	if current_weapon_index != -1 and weapons[current_weapon_index] == weapon:
		GameEvents.ammo_changed.emit(current, maximum)
		GameEvents.cylinders_changed.emit(weapon.get_cylinder_rounds(), true)

func _add_curent_stamina(amount: float) -> void:
	current_stamina = minf(current_stamina + amount, max_stamina)
	stamina_changed.emit(current_stamina, max_stamina)
	
