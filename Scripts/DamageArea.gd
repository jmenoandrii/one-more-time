extends Area3D

@export var damage_amount: float = 10.0
@export var target_obj_name := ""

var targets_in_range: Array[Node3D] = []

@onready var damage_timer: Timer = $Timer

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	damage_timer.timeout.connect(_on_timer_timeout)

func _on_body_entered(body: Node3D) -> void:
	if target_obj_name and body.name != target_obj_name:
		return
	if not body.has_node("HealthComponent"):
		return
	
	targets_in_range.append(body)
		
	_deal_damage_to(body)
	
	if targets_in_range.size() == 1:
		damage_timer.start()

func _on_body_exited(body: Node3D) -> void:
	if targets_in_range.has(body):
		targets_in_range.erase(body)
		
		if targets_in_range.is_empty():
			damage_timer.stop()

func _on_timer_timeout() -> void:
	for target in targets_in_range:
		_deal_damage_to(target)

func _deal_damage_to(target: Node3D) -> void:
	var health = target.get_node("HealthComponent") as HealthComponent
	if health:
		health.take_damage(damage_amount)
		print("[", name, "]: damaged ", target.name, " on ", damage_amount)
