extends MultiMeshInstance3D
class_name ShellCasings

# Spent casings for the whole level in one MultiMesh: one draw call and no physics bodies.
# Every casing flies on simple ballistics and bounces on the floor height found by a single
# raycast at spawn. The pool is a ring: when it's full, the oldest casing is reused.
# Created on the first spawn() under the current scene, so it goes away with the level.

const SHELL_SCENE := preload("res://Models/bullet.glb") # its "shell" mesh is the casing
const SHELL_MATERIAL := preload("res://Materials/Gun/bullet.tres")
const MAX_SHELLS := 48
const SHELL_SCALE := 0.04
const GRAVITY := 9.8
const LIFETIME := 10.0
const FADE_TIME := 0.5 # shrinks away at the end of its life
const BOUNCE := 0.35 # vertical speed kept on a bounce
const FRICTION := 0.5 # horizontal speed kept on a bounce
const SPIN_DAMPING := 0.6 # spin kept on a bounce
const REST_SPEED := 0.6 # slower than this on impact -> lies down and stops
const FLOOR_MASK := 1 # what the casings land on
const FLOOR_SEARCH := 20.0 # how far down the floor is looked for, m

static var _instance: ShellCasings

var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _spin := PackedVector3Array() # angular velocity, rad/s
var _basis: Array[Basis] = []
var _floor_y := PackedFloat32Array()
var _age := PackedFloat32Array()
var _alive := PackedByteArray()
var _resting := PackedByteArray()
var _alive_count := 0
var _next := 0
var _shell_offset: Transform3D # centers the casing mesh on its origin, long axis along Z
var _radius := 0.0

static func spawn(from: Node, origin: Vector3, velocity: Vector3, exclude: Array[RID] = []) -> void:
	if not is_instance_valid(_instance) or not _instance.is_inside_tree():
		_instance = ShellCasings.new()
		var parent := from.get_tree().current_scene
		if parent == null:
			parent = from.get_tree().root
		parent.add_child(_instance)
	_instance._spawn(origin, velocity, exclude)

func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material_override = SHELL_MATERIAL

	var src := SHELL_SCENE.instantiate()
	var shell := src.find_child("shell", true, false) as MeshInstance3D
	var mesh_aabb := shell.mesh.get_aabb()
	var center := shell.transform * mesh_aabb.get_center()
	_shell_offset = Transform3D(Basis.from_scale(Vector3.ONE * SHELL_SCALE)) \
		* Transform3D(Basis(), -center) * shell.transform
	_radius = (_shell_offset.basis * Vector3(mesh_aabb.size.x, 0, 0)).length() * 0.5

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = shell.mesh
	mm.instance_count = MAX_SHELLS
	# never culled: saves recalculating the bounds every frame, and it's only one draw call
	mm.custom_aabb = AABB(Vector3.ONE * -10000.0, Vector3.ONE * 20000.0)
	multimesh = mm
	src.free()

	_pos.resize(MAX_SHELLS)
	_vel.resize(MAX_SHELLS)
	_spin.resize(MAX_SHELLS)
	_basis.resize(MAX_SHELLS)
	_floor_y.resize(MAX_SHELLS)
	_age.resize(MAX_SHELLS)
	_alive.resize(MAX_SHELLS)
	_resting.resize(MAX_SHELLS)
	for i in MAX_SHELLS:
		_hide(i)

func _spawn(origin: Vector3, velocity: Vector3, exclude: Array[RID]) -> void:
	var i := _next
	_next = (_next + 1) % MAX_SHELLS
	if not _alive[i]:
		_alive_count += 1

	_pos[i] = origin
	_vel[i] = velocity
	_spin[i] = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 15.0
	_basis[i] = Basis.from_euler(Vector3(randf() * TAU, randf() * TAU, randf() * TAU))
	_age[i] = 0.0
	_alive[i] = 1
	_resting[i] = 0

	# the only physics query per casing: where its floor is
	var query := PhysicsRayQueryParameters3D.create(origin, origin + Vector3.DOWN * FLOOR_SEARCH, FLOOR_MASK, exclude)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	_floor_y[i] = hit.position.y if not hit.is_empty() else origin.y - FLOOR_SEARCH

func _process(delta: float) -> void:
	if _alive_count == 0:
		return

	for i in MAX_SHELLS:
		if not _alive[i]:
			continue

		_age[i] += delta
		if _age[i] >= LIFETIME:
			_alive[i] = 0
			_alive_count -= 1
			_hide(i)
			continue

		var fading := _age[i] > LIFETIME - FADE_TIME
		if _resting[i] and not fading:
			continue # lying still: its transform is already set

		if not _resting[i]:
			_fly(i, delta)

		var size := 1.0
		if fading:
			size = (LIFETIME - _age[i]) / FADE_TIME
		multimesh.set_instance_transform(i, Transform3D(_basis[i].scaled(Vector3.ONE * size), _pos[i]) * _shell_offset)

func _fly(i: int, delta: float) -> void:
	var vel := _vel[i]
	vel.y -= GRAVITY * delta
	var pos := _pos[i] + vel * delta
	_basis[i] = (Basis.from_euler(_spin[i] * delta) * _basis[i]).orthonormalized()

	var floor_y := _floor_y[i] + _radius
	if pos.y <= floor_y:
		pos.y = floor_y
		if absf(vel.y) < REST_SPEED:
			_lie_down(i)
			vel = Vector3.ZERO
		else:
			vel = Vector3(vel.x * FRICTION, -vel.y * BOUNCE, vel.z * FRICTION)
			_spin[i] *= SPIN_DAMPING

	_vel[i] = vel
	_pos[i] = pos

# flat on the floor, keeping the direction it was pointing
func _lie_down(i: int) -> void:
	_resting[i] = 1
	var long_axis := _basis[i].z
	var flat := Vector3(long_axis.x, 0, long_axis.z)
	flat = flat.normalized() if flat.length_squared() > 0.0001 else Vector3.FORWARD
	_basis[i] = Basis(Vector3.UP.cross(flat), Vector3.UP, flat)

func _hide(i: int) -> void:
	multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
