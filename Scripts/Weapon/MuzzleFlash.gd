extends Node3D
class_name MuzzleFlash

# Flash at a muzzle: a camera-facing star quad and a short light, both fading out in `duration`.
# Created once per muzzle and only switched on per shot; does nothing while hidden.

const SHADER := preload("res://Shaders/muzzle_flash.gdshader")

var size: float = 0.35 # quad size, m
var duration: float = 0.06 # s
var light_energy: float = 3.0
var light_range: float = 4.0
var light_color := Color(1.0, 0.6, 0.25)

var _quad: MeshInstance3D
var _light: OmniLight3D
var _material: ShaderMaterial
var _time := 0.0

func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = SHADER

	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE
	_quad = MeshInstance3D.new()
	_quad.mesh = mesh
	_quad.material_override = _material
	_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_quad)

	_light = OmniLight3D.new()
	_light.light_color = light_color
	_light.omni_range = light_range
	_light.shadow_enabled = false
	add_child(_light)

	_set_lit(false)

func flash() -> void:
	_time = 0.0
	_quad.scale = Vector3.ONE * size * randf_range(0.8, 1.2)
	_material.set_shader_parameter(&"angle", randf() * TAU)
	_material.set_shader_parameter(&"rays", float(randi_range(5, 7)))
	_apply(1.0)
	_set_lit(true)

func _process(delta: float) -> void:
	_time += delta
	var k := 1.0 - _time / duration
	if k <= 0.0:
		_set_lit(false)
		return
	_apply(k)

func _apply(k: float) -> void:
	_material.set_shader_parameter(&"intensity", k)
	_light.light_energy = light_energy * k

func _set_lit(value: bool) -> void:
	_quad.visible = value
	_light.visible = value
	set_process(value)
