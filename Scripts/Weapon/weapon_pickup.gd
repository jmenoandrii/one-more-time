extends Pickup

@export var weapon_name: String = "revolver"

func _pick_up(body: Node3D) -> bool:
	return body.has_method("pick_up_weapon") and body.pick_up_weapon(weapon_name)
