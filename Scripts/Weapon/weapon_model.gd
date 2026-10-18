extends Node3D
class_name WeaponModel

# Root of a weapon model scene. Its animations call methods here (path "."),
# and the weapon that holds the model listens to the signals —
# so the model works no matter what node it is placed under.

signal round_loaded # one round goes in during the reload animation
signal shells_ejected(origin: Vector3) # the cylinder swung out, spent casings fall from origin

@export var shell_eject_point: Node3D # where the casings fall from; a mesh uses its center, empty = the model root

func load_reload_round() -> void:
	round_loaded.emit()

func eject_shells() -> void:
	shells_ejected.emit(_get_eject_origin())

func _get_eject_origin() -> Vector3:
	if shell_eject_point is MeshInstance3D:
		var mesh_instance := shell_eject_point as MeshInstance3D
		return mesh_instance.global_transform * mesh_instance.get_aabb().get_center()
	if shell_eject_point:
		return shell_eject_point.global_position
	return global_position
