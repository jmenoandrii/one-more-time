extends Pickup

@export var amount: float = 30.0

func _ready() -> void:
	super()

func _pick_up(body: Node3D) -> bool:
	var health := body.get_node_or_null("HealthComponent") as HealthComponent
	GameEvents.heal_picked.emit()
	health.heal(amount)
	return true
