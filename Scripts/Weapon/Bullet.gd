extends CharacterBody3D

# The body flies straight along the aim; what is drawn (model + tracer) can start somewhere else —
# the player's bullets fly from the camera, but are seen leaving the muzzle and merging into
# the real path over converge_distance (see set_visual_start).

var lifetime: float = 2.0
@export var speed: float = 50.0
@export var damage: float = 0.0
@export var target_obj_name := ""
@export var impact_sound: AudioStreamPlayer3D # optional: played (as a copy) where it hits
var is_crit := false # set by the weapon, damage already includes the multiplier
var from_player := false # set by the weapon: hits on enemies are reported to the HUD

# tracer: a thin glowing streak behind the bullet, grows from the muzzle up to tracer_length
@export var tracer_length: float = 3.0
@export var tracer_width: float = 0.02
@export var converge_distance: float = 6.0 # the drawn bullet reaches the real path after this many meters

# one mesh and material for all bullets
static var _tracer_mesh: BoxMesh
static var _tracer_material: StandardMaterial3D

var _visual: Node3D # every drawn child is moved under it
var _tracer: MeshInstance3D
var _traveled := 0.0
var _visual_offset := Vector3.ZERO # drawn start - body start, world space
var _converge := 1.0
var _hide_visual := false


# call after placing the bullet, before adding it to the tree
func set_visual_start(visual_origin: Vector3, target_point: Vector3) -> void:
	_visual_offset = visual_origin - transform.origin
	var target_dist := transform.origin.distance_to(target_point)
	_converge = clampf(minf(converge_distance, target_dist), 0.01, converge_distance)
	# the target is closer than the muzzle (up against a wall): the drawn bullet would fly backwards
	_hide_visual = target_dist < _visual_offset.dot(-transform.basis.z) + 0.3

func _ready() -> void:
	_visual = Node3D.new()
	_visual.top_level = true
	for child in get_children():
		if not child is CollisionShape3D:
			child.reparent(_visual, false)
	add_child(_visual)
	_visual.visible = not _hide_visual
	_create_tracer()
	_update_visual()

	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	var collision = move_and_collide(-transform.basis.z * speed * delta)
	_traveled += speed * delta
	_update_visual()

	if collision:
		var hit_object = collision.get_collider()
		print("[BULLET]: hit '", hit_object.name, "'!")

		var health_component = hit_object.get_node_or_null("HealthComponent")
		if not target_obj_name or hit_object.name == target_obj_name:
			if health_component and health_component.has_method("take_damage"):
				health_component.take_damage(damage)
				if from_player:
					GameEvents.enemy_hit.emit(damage, is_crit, health_component.current_health <= 0)

		if impact_sound:
			impact_sound.global_position = collision.get_position()
			OneShotSound.play_copy(impact_sound)
		ImpactEffects.spawn(self, collision.get_position(), collision.get_normal(), health_component != null)
		queue_free()

func _update_visual() -> void:
	var dir := -global_basis.z
	var k := clampf(1.0 - _traveled / _converge, 0.0, 1.0) # 1 at the muzzle, 0 on the real path
	var visual_dir := dir
	if k > 0.0:
		# straight line from the muzzle to the merge point
		visual_dir = (dir - _visual_offset / _converge).normalized()
	_visual.global_transform = Transform3D(_basis_along(visual_dir), global_position + _visual_offset * k)
	_update_tracer()

func _basis_along(forward: Vector3) -> Basis:
	var up := Vector3.UP if absf(forward.y) < 0.99 else Vector3.RIGHT
	return Basis.looking_at(forward, up)

func _create_tracer() -> void:
	if _tracer_mesh == null:
		_tracer_mesh = BoxMesh.new()
		_tracer_mesh.size = Vector3.ONE
		_tracer_material = StandardMaterial3D.new()
		_tracer_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_tracer_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_tracer_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_tracer_material.albedo_color = Color(1.0, 0.75, 0.35, 0.8)

	_tracer = MeshInstance3D.new()
	_tracer.mesh = _tracer_mesh
	_tracer.material_override = _tracer_material
	_tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.add_child(_tracer)

# the drawn bullet flies along -Z, so the streak trails behind it along +Z
func _update_tracer() -> void:
	var length := minf(tracer_length, _traveled)
	_tracer.visible = length > 0.01
	_tracer.scale = Vector3(tracer_width, tracer_width, maxf(length, 0.01))
	_tracer.position = Vector3(0, 0, length * 0.5)
