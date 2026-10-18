extends Pickup

@export var amount: int = 5

func _ready() -> void:
	super()

func _pick_up(body: Node3D) -> bool:
	if not body.has_method("_add_reserve_ammo"):
		return false
	GameEvents.ammo_picked.emit()
	body._add_reserve_ammo(amount)
	return true
