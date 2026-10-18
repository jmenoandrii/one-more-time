extends Pickup

# A key lying on the map: walk into it and it goes to the player's pocket.
# A door opens with it when its required_key is the same as this key_id.

@export var key_id: String = "red"
@export var key_color: Color = Color(0.85, 0.1, 0.1)

func _ready() -> void:
	super()
	var material := StandardMaterial3D.new()
	material.albedo_color = key_color
	material.metallic = 0.6
	material.roughness = 0.35
	material.emission_enabled = true # glows a little, so it's easy to spot
	material.emission = key_color
	material.emission_energy_multiplier = 0.3
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = material

func _pick_up(body: Node3D) -> bool:
	if not body.has_method("add_key"):
		return false
	body.add_key(key_id, key_color)
	GameEvents.key_picked.emit()
	return true
