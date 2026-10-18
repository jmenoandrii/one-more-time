extends Node3D
class_name ImpactEffects

# Bullet hits for the whole level: a small pool of one-shot particle systems reused in a ring,
# so a hit only moves one system and restarts it — nothing is created during the fight.
# Walls: sparks along the velocity + a dust puff. Flesh (anything with a HealthComponent): blood drops.
# Every system keeps its materials for life: swapping them on a live particle system leaves the
# renderer without a uniform set for a frame ("draw_list_bind_uniform_set: uniform_set is null").
# prepare() builds the pool at level start, so the particle shaders compile before the first shot.

const POOL_SIZE := 8

static var _instance: ImpactEffects

var _sparks: Array[GPUParticles3D] = []
var _dust: Array[GPUParticles3D] = []
var _blood: Array[GPUParticles3D] = []
var _next_wall := 0
var _next_flesh := 0

var _spark_process: ParticleProcessMaterial
var _blood_process: ParticleProcessMaterial
var _spark_mesh: QuadMesh
var _blood_mesh: QuadMesh
var _dust_process: ParticleProcessMaterial
var _dust_mesh: QuadMesh

static func prepare(from: Node) -> void:
	_get_pool(from)

static func spawn(from: Node, hit_pos: Vector3, normal: Vector3, flesh: bool) -> void:
	var pool := _get_pool(from)
	if pool.is_inside_tree():
		pool._emit(hit_pos, normal, flesh)

static func _get_pool(from: Node) -> ImpactEffects:
	if not is_instance_valid(_instance):
		_instance = ImpactEffects.new()
		var parent := from.get_tree().current_scene
		if parent == null:
			parent = from.get_tree().root
		# during the level's own _ready the parent is still busy setting up its children
		if parent.is_node_ready():
			parent.add_child(_instance)
		else:
			parent.add_child.call_deferred(_instance)
	return _instance

func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_build_resources()
	for i in POOL_SIZE:
		_sparks.append(_make_system(10, 0.35, _spark_process, _spark_mesh, true))
		_dust.append(_make_system(4, 0.7, _dust_process, _dust_mesh, false))
		_blood.append(_make_system(10, 0.6, _blood_process, _blood_mesh, false))

func _emit(hit_pos: Vector3, normal: Vector3, flesh: bool) -> void:
	var xform := Transform3D(_basis_from_normal(normal), hit_pos + normal * 0.02)

	if flesh:
		var b := _next_flesh
		_next_flesh = (_next_flesh + 1) % POOL_SIZE
		_restart_at(_blood[b], xform)
		return

	var i := _next_wall
	_next_wall = (_next_wall + 1) % POOL_SIZE
	_restart_at(_sparks[i], xform)
	_restart_at(_dust[i], xform)

func _restart_at(system: GPUParticles3D, xform: Transform3D) -> void:
	system.global_transform = xform
	system.restart()

# fully set up before entering the tree; align_to_velocity: streaks stretched along their velocity
func _make_system(amount: int, lifetime: float, process: ParticleProcessMaterial, mesh: Mesh, align_to_velocity: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.process_material = process
	p.draw_pass_1 = mesh
	if align_to_velocity:
		p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = true
	p.explosiveness = 1.0
	p.emitting = false
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p

# local Y = the surface normal: the particles shoot out of the wall
func _basis_from_normal(normal: Vector3) -> Basis:
	var y := normal.normalized()
	var helper := Vector3.UP if absf(y.y) < 0.99 else Vector3.RIGHT
	var x := helper.cross(y).normalized()
	return Basis(x, y, x.cross(y))

func _build_resources() -> void:
	# sparks: fast, bright, falling, fading from white-yellow to orange
	_spark_process = ParticleProcessMaterial.new()
	_spark_process.direction = Vector3.UP
	_spark_process.spread = 50.0
	_spark_process.initial_velocity_min = 3.0
	_spark_process.initial_velocity_max = 7.0
	_spark_process.gravity = Vector3(0, -12, 0)
	_spark_process.damping_min = 2.0
	_spark_process.damping_max = 4.0
	_spark_process.scale_min = 0.6
	_spark_process.scale_max = 1.2
	_spark_process.particle_flag_align_y = true
	_spark_process.color_ramp = _ramp(Color(1, 0.95, 0.7, 1), Color(1, 0.4, 0.05, 0))

	_spark_mesh = QuadMesh.new()
	_spark_mesh.size = Vector2(0.015, 0.12)
	_spark_mesh.material = _particle_material(true, false)

	# blood: slower heavy drops
	_blood_process = ParticleProcessMaterial.new()
	_blood_process.direction = Vector3.UP
	_blood_process.spread = 60.0
	_blood_process.initial_velocity_min = 1.0
	_blood_process.initial_velocity_max = 3.0
	_blood_process.gravity = Vector3(0, -9.8, 0)
	_blood_process.scale_min = 0.5
	_blood_process.scale_max = 1.2
	_blood_process.color_ramp = _ramp(Color(0.55, 0.02, 0.02, 1), Color(0.3, 0.0, 0.0, 0))

	_blood_mesh = QuadMesh.new()
	_blood_mesh.size = Vector2(0.06, 0.06)
	_blood_mesh.material = _particle_material(false, true)

	_dust_process = _make_dust_process()
	_dust_mesh = _make_dust_mesh()

func _make_dust_process() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3.UP
	m.spread = 30.0
	m.initial_velocity_min = 0.3
	m.initial_velocity_max = 0.8
	m.gravity = Vector3(0, 0.2, 0)
	m.damping_min = 1.0
	m.damping_max = 2.0
	m.angle_min = 0.0
	m.angle_max = 360.0
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.4))
	grow.add_point(Vector2(1, 1.0))
	var grow_tex := CurveTexture.new()
	grow_tex.curve = grow
	m.scale_curve = grow_tex
	m.color_ramp = _ramp(Color(0.6, 0.57, 0.52, 0.6), Color(0.6, 0.57, 0.52, 0))
	return m

func _make_dust_mesh() -> QuadMesh:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.25, 0.25)
	var mat := _particle_material(false, true)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var soft := GradientTexture2D.new()
	soft.gradient = gradient
	soft.fill = GradientTexture2D.FILL_RADIAL
	soft.fill_from = Vector2(0.5, 0.5)
	soft.fill_to = Vector2(0.5, 0.0)
	soft.width = 32
	soft.height = 32
	mat.albedo_texture = soft
	mesh.material = mat
	return mesh

func _particle_material(additive: bool, billboard: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if additive:
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	if billboard:
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	return mat

func _ramp(from: Color, to: Color) -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.set_color(0, from)
	gradient.set_color(1, to)
	var tex := GradientTexture1D.new()
	tex.gradient = gradient
	return tex
