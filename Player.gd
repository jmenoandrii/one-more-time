extends CharacterBody3D

const SPEED = 5
const JUMP_VELOCITY = 5.5
const SENSITIVITY = 0.04

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var _isCursorLocked: bool = true

var isPlayerDead := false
var head_world_position: Vector3

@onready var camera = $head/Camera3D
@onready var head = $head

func _ready() -> void:
 Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
 if event is InputEventMouseMotion:
  if not _isCursorLocked or isPlayerDead:
   return
   
  head.rotate_y(-event.relative.x * SENSITIVITY)
  camera.rotate_x(-event.relative.y * SENSITIVITY)
  camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-40), deg_to_rad(40))
 elif event.is_action_pressed("ui_cancel"):
  if _isCursorLocked:
   Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
  else:
   Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
  _isCursorLocked = !_isCursorLocked
  pass
 elif event.is_action_pressed("dying"):
  die()
 
func _physics_process(delta: float) -> void:
 movement(delta)
 
 if not is_on_floor():
  velocity.y -= gravity * delta
  
 if Input.is_action_just_pressed("jump") and is_on_floor():
  velocity.y = JUMP_VELOCITY
 elif Input.is_action_just_released("jump") and velocity.y > 0.0:
  velocity.y = 0.0
  
 dying_process()
 
 move_and_slide()

func die() -> void:
 if (isPlayerDead):
  return
  
 isPlayerDead = true
 head_world_position = head.global_position
 pass
 
func movement(delta: float) -> void:
 if isPlayerDead:
  return
 
 var input_direction_2D = Input.get_vector(
  "move_left", "move_right", "move_forward", "move_back"
 )
 var input_direction_3D = Vector3(
  input_direction_2D.x, 0.0, input_direction_2D.y
 )
 var direction = (head.transform.basis * input_direction_3D).normalized()
 
 if direction:
  velocity.x = direction.x * SPEED
  velocity.z = direction.z * SPEED
 else:
  velocity.x = 0.0
  velocity.z = 0.0

func dying_process() -> void:
 if not isPlayerDead:
  return

 head.global_position = head_world_position

 var target_position = global_position

 if head.global_position.distance_squared_to(target_position) > 0.001:
  head.look_at(target_position, Vector3.UP)
