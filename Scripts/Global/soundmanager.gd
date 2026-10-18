extends Node
@onready var staminabar_pickup: AudioStreamPlayer3D = $"StaminaBar PickUp"
@onready var ammo_pickup: AudioStreamPlayer3D = $"Ammo PickUp"
@onready var heal_pickup: AudioStreamPlayer3D = $"Heal PickUp"
@onready var gun_pickup: AudioStreamPlayer3D = $"Gun PickUp"

func _ready() -> void:
	GameEvents.stamina_bar_picked.connect(_stamina_bar_fxc)
	GameEvents.ammo_picked.connect(_ammo_fxc)
	GameEvents.heal_picked.connect(_heal_fxc)
	GameEvents.gun_picked.connect(_gun_fxc)
	GameEvents.key_picked.connect(_key_fxc)
	
func _stamina_bar_fxc():
	staminabar_pickup.play()
func _ammo_fxc():
	ammo_pickup.play()
func _heal_fxc():
	heal_pickup.play()
func _gun_fxc():
	gun_pickup.play()
func _key_fxc():
	ammo_pickup.play()
