extends Node
class_name HealthComponent

signal health_changed(current: float, maximum: float)
signal damage_caused(amount: float)
signal healing_caused(amount: float)
signal died()

@export var max_health: float = 100.0
var current_health: float


func _ready() -> void:
	_update_health(max_health)

func take_damage(amount: float) -> void:
	if current_health <= 0:
		return
		
	_update_health(current_health - amount)
	damage_caused.emit(amount)
	
	if current_health <= 0:
		died.emit()

func heal(amount: float) -> void:
	if current_health <= 0:
		return
		
	_update_health(current_health + amount)
	healing_caused.emit(amount)

# new maximum, the health is refilled to it
func set_max_health(value: float) -> void:
	max_health = value
	_update_health(max_health)

func _update_health(health: float) -> void:
	if health < 0: 
		current_health = 0.0
	elif health > max_health:
		current_health = max_health
	else:
		current_health = health
	health_changed.emit(current_health, max_health)
	
