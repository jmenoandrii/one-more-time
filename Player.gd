extends CharacterBody3D

const SPEED = 5.0
const CROUCH_SPEED = 2.5
const JUMP_VELOCITY = 5.5
const MOUSE_SENSITIVITY = 0.002

const CROUCH_PERSENT = 0.3
var normal_height: float
var crouch_height: float	# = normal_height - normal_height * CROUCH_PERSENT
var default_head_y: float

var is_crouching := false
var is_player_dead := false
var is_cursor_locked := true

var head_world_position: Vector3

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var ceiling_check: RayCast3D = $Head/CeilingCheck

@onready var dirt_step: AudioStreamPlayer3D = $Sounds/dirt
@onready var stone_step: AudioStreamPlayer3D = $Sounds/stone
@onready var headbob: AnimationPlayer = $Head/headbob
@onready var jump_sound: AudioStreamPlayer3D = $Sounds/jump


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	normal_height = collision_shape.shape.height
	crouch_height = normal_height - (normal_height * CROUCH_PERSENT)
	default_head_y = head.position.y

func _unhandled_input(event: InputEvent) -> void:
	if is_player_dead or not is_cursor_locked:
		pass
	elif event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-85.0), deg_to_rad(85.0))

	if Input.is_action_just_pressed("ui_cancel"):
		is_cursor_locked = not is_cursor_locked
		if is_cursor_locked:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			
	if Input.is_action_just_pressed("dying"):
		die()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if is_player_dead:
		_process_death()
		move_and_slide()
		return
	
	if Input.is_key_pressed(KEY_SHIFT):
		is_crouching = true
	else:
		if not ceiling_check.is_colliding():
			is_crouching = false
	
	var target_height := crouch_height if is_crouching else normal_height
	
	collision_shape.shape.height = lerp(collision_shape.shape.height, target_height, 10.0 * delta)
	if mesh_instance.mesh is CapsuleMesh:
		mesh_instance.mesh.height = lerp(mesh_instance.mesh.height, target_height, 10.0 * delta)
	
	collision_shape.position.y = collision_shape.shape.height / 2.0
	mesh_instance.position.y = collision_shape.shape.height / 2.0
	
	head.position.y = collision_shape.shape.height - 0.5

	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_crouching:
		velocity.y = JUMP_VELOCITY
		jump_sound.play()
	elif Input.is_action_just_released("jump") and velocity.y > 0.0:
		
		velocity.y = 0.0
	
	var current_speed := CROUCH_SPEED if is_crouching else SPEED
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
		headbob.play("new_animation")
		
	else:
		headbob.stop()
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
