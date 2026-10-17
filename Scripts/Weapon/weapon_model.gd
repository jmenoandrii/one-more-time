extends Node3D
class_name WeaponModel

# Root of a weapon model scene. Its animations call methods here (path "."),
# and the weapon that holds the model listens to the signals —
# so the model works no matter what node it is placed under.

signal round_loaded # one round goes in during the reload animation

func load_reload_round() -> void:
	round_loaded.emit()
