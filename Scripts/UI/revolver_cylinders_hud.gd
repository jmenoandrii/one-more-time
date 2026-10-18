extends Control

# Cylinders of the weapon in hands. The children are revolver_cylinder_hud.gd nodes:
# the 1st for the right (or only) revolver, the 2nd for the left one of the dual revolvers.
# A cylinder the weapon doesn't have is hidden. Not a Container on purpose:
# containers reset the children's rotation and scale, which the spin and the pulse use.

func _enter_tree() -> void:
	# connect before the player's _ready, which sends the initial ammo
	GameEvents.cylinders_changed.connect(_on_cylinders_changed)
	GameEvents.weapon_unequipped.connect(hide)

func _ready() -> void:
	visible = false

func _on_cylinders_changed(rounds: Array[int], animate: bool) -> void:
	visible = true
	var cylinders := get_children()
	for i in cylinders.size():
		var cylinder := cylinders[i] as Control
		cylinder.visible = i < rounds.size()
		if cylinder.visible:
			cylinder.set_rounds(rounds[i], animate)
