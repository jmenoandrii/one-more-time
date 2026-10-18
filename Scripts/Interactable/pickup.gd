extends Area3D
class_name Pickup

# Base for things lying on the map: the model spins and bobs, and when a body enters the area
# _pick_up(body) decides whether it was taken. Taken -> the pickup disappears.

@export var model: Node3D # optional: the first Node3D child is used
@export var spin_speed: float = 1.5
@export var bob_height: float = 0.15
@export var bob_speed: float = 2.0

var _time := 0.0
var _base_y: float

func _ready() -> void:
	if model == null:
		for child in get_children():
			if child is Node3D and not child is CollisionShape3D:
				model = child
				break
	_base_y = model.position.y
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_time += delta
	model.rotate_y(spin_speed * delta)
	model.position.y = _base_y + sin(_time * bob_speed) * bob_height

func _on_body_entered(body: Node3D) -> void:
	if _pick_up(body):\
		queue_free()

# override: give the item to the body, return true if it was taken
func _pick_up(_body: Node3D) -> bool:
	return false
