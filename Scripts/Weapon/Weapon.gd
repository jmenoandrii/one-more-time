extends Node3D

signal ammo_updated(current: int, maximum: int)

@export var weapon_name: String
@export var bullet_scene: PackedScene
@export var fire_rate: float = 0.5 # in sec
@export var max_ammo: int = 6

var current_ammo: int
var can_shoot: bool = true

@onready var bullet_pos: Marker3D = $BulletPos


func _ready() -> void:
	current_ammo = max_ammo

func shoot(target_point: Vector3) -> void:
	# shot accessibility check
	if not can_shoot or current_ammo <= 0:
		return
		
	# shooting
	can_shoot = false
	_update_ammo(current_ammo - 1)
	
	var instance = bullet_scene.instantiate()
	get_tree().root.add_child(instance)
	
	instance.global_position = bullet_pos.global_position
	#instance.global_transform.basis = bullet_pos.global_transform.basis
	instance.look_at(target_point, Vector3.UP)
	
	# timer
	await get_tree().create_timer(fire_rate).timeout
	can_shoot = true

func reload(reserve_ammo: int) -> int:
	if current_ammo == max_ammo or reserve_ammo <= 0:
		return reserve_ammo
	
	var needed_ammo = max_ammo - current_ammo
	
	if reserve_ammo >= needed_ammo:
		_update_ammo(current_ammo + needed_ammo)
		reserve_ammo -= needed_ammo
	else:
		_update_ammo(current_ammo + reserve_ammo)
		reserve_ammo = 0
		
	return reserve_ammo

func _update_ammo(ammo: int) -> void:
	current_ammo = ammo
	ammo_updated.emit(current_ammo, max_ammo)
