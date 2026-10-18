extends Node
class_name RandomMaterial

# Gives the model a random look on spawn: one material from the list goes to every mesh under target.
# The material is shared, not duplicated, so enemies with the same look still batch together.

@export var target: Node3D
@export var materials: Array[Material] = []

func _ready() -> void:
	if target == null or materials.is_empty():
		return
	var material: Material = materials.pick_random()
	for mesh in target.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_override = material
