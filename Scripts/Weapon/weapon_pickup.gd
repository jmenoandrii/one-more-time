extends Area3D

@export var weapon_name: String = "revolver"
@export var spin_speed: float = 1.5
@export var bob_height: float = 0.15
@export var bob_speed: float = 2.0

@onready var model: Node3D = $Revolver
var _time := 0.0
var _base_y: float

func _ready() -> void:
	_base_y = model.position.y
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_time += delta
	model.rotate_y(spin_speed * delta)
	model.position.y = _base_y + sin(_time * bob_speed) * bob_height

func _on_body_entered(body: Node3D) -> void:
	if body.has_method("pick_up_weapon") and body.pick_up_weapon(weapon_name):
		queue_free()
