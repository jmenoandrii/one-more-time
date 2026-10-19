extends Pickup

@export var amount: float = 30.0

func _ready() -> void:
	super()

func _pick_up(body: Node3D) -> bool:
	# only the player: bullets, stones and goblins also walk into pickups
	if not body.is_in_group("player"):
		return false
	var health := body.get_node_or_null("HealthComponent") as HealthComponent
	if health == null:
		return false
	GameEvents.heal_picked.emit()
	health.heal(amount)
	return true
