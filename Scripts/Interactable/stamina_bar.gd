extends Pickup

@export var amount: float = 30.0

func _ready() -> void:
	super()

func _pick_up(body: Node3D) -> bool:
	if not body.has_method("_add_curent_stamina"):
		return false

	body._add_curent_stamina(amount)
	return true
