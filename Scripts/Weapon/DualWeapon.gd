extends Weapon
class_name DualWeapon

# Two revolvers as one weapon: shared magazine, shots alternate right -> left -> right...
# Expects children Right and Left (pivots with the offset / mirror, each holding an instanced model)
# and BulletPos / BulletPosLeft. The models' animations move the model root, so the placement must
# live on the pivots, not on the models.
# Reload needs no extra code: both models report every click, so each click loads two rounds.

@export var left_animation_player: AnimationPlayer
@export var left_shoot_sound: AudioStreamPlayer3D
@export var gun_fire_rate: float = 0.5 # cooldown of each revolver; fire_rate is only the gap between any two shots
@export var recoil_side_yaw: float = 0.06 # extra kick outward, toward the side that fired

@onready var bullet_pos_left: Marker3D = $BulletPosLeft
@onready var right_model: Node3D = $Right
@onready var left_model: Node3D = $Left

var _next_is_left := false
var _last_side := 1.0 # 1 = right fired, -1 = left fired
var _gun_ready_at_ms := [0, 0] # per revolver: 0 = right, 1 = left

# recoil per revolver (applied to the Right / Left pivots), so only the gun that fired kicks
var _pivots: Array[Node3D] = []
var _pivot_rest: Array[Transform3D] = []
var _side_target_rot := [Vector3.ZERO, Vector3.ZERO]
var _side_target_pos := [Vector3.ZERO, Vector3.ZERO]
var _side_rot := [Vector3.ZERO, Vector3.ZERO]
var _side_pos := [Vector3.ZERO, Vector3.ZERO]


func _ready() -> void:
	# pick each gun's nodes explicitly: the base fallback would just take the first ones it finds
	if animation_player == null:
		animation_player = _find_in(right_model, "AnimationPlayer") as AnimationPlayer
	if shoot_sound == null:
		shoot_sound = right_model.find_child("ShootSound", true, false) as AudioStreamPlayer3D
	if reload_sound == null:
		reload_sound = right_model.find_child("ReloadSound", true, false) as AudioStreamPlayer3D
	if left_animation_player == null:
		left_animation_player = _find_in(left_model, "AnimationPlayer") as AnimationPlayer
	if left_shoot_sound == null:
		left_shoot_sound = left_model.find_child("ShootSound", true, false) as AudioStreamPlayer3D

	super()
	_connect_model(left_animation_player)
	gun_fire_rate /= RunState.get_stat("fire_rate", 1.0)
	
	_pivots = [right_model, left_model]
	_pivot_rest = [right_model.transform, left_model.transform]

func _process(delta: float) -> void:
	super(delta) # the shared recoil stays zero, the pair itself stays at rest
	
	var back := 1.0 - exp(-recoil_return_speed * delta)
	var chase := 1.0 - exp(-recoil_snappiness * delta)
	for i in 2:
		_side_target_rot[i] = _side_target_rot[i].lerp(Vector3.ZERO, back)
		_side_target_pos[i] = _side_target_pos[i].lerp(Vector3.ZERO, back)
		_side_rot[i] = _side_rot[i].lerp(_side_target_rot[i], chase)
		_side_pos[i] = _side_pos[i].lerp(_side_target_pos[i], chase)
		var rest: Transform3D = _pivot_rest[i]
		_pivots[i].transform = Transform3D(Basis.from_euler(_side_rot[i]) * rest.basis, rest.origin + _side_pos[i])

func _is_ready_to_fire() -> bool:
	# strict alternation: the shot waits for the revolver whose turn it is
	var side := 1 if _next_is_left else 0
	return Time.get_ticks_msec() >= _gun_ready_at_ms[side]

func _fire(target_point: Vector3) -> void:
	if _next_is_left:
		_play_shoot_animation(left_animation_player)
		if left_shoot_sound:
			left_shoot_sound.play()
		_spawn_bullet(bullet_pos_left, target_point)
		_last_side = -1.0
	else:
		_play_shoot_animation(animation_player)
		if shoot_sound:
			shoot_sound.play()
		_spawn_bullet(bullet_pos, target_point)
		_last_side = 1.0

	var side := 1 if _next_is_left else 0
	_gun_ready_at_ms[side] = Time.get_ticks_msec() + int(gun_fire_rate * 1000.0)
	_next_is_left = not _next_is_left

func _add_recoil() -> void:
	# only the revolver that fired kicks; same ranges as the base recoil, plus a push outward
	var side := 0 if _last_side > 0.0 else 1
	_side_target_rot[side] += Vector3(
		randf_range(recoil_pitch.x, recoil_pitch.y),
		randf_range(-recoil_yaw, recoil_yaw) - recoil_side_yaw * _last_side,
		randf_range(-recoil_roll, recoil_roll))
	_side_target_rot[side].x = min(_side_target_rot[side].x, recoil_max_pitch)
	
	var kick := randf_range(recoil_kick.x, recoil_kick.y)
	_side_target_pos[side] += Vector3(0, kick * 0.3, kick)

# everything except the shot plays on both guns at once
func _anim_play(anim: StringName, blend: float = -1.0, speed: float = 1.0) -> void:
	super(anim, blend, speed)
	if left_animation_player:
		left_animation_player.play(anim, blend, speed)

func _anim_stop() -> void:
	super()
	if left_animation_player:
		left_animation_player.stop()

func _anim_advance(delta: float) -> void:
	super(delta)
	if left_animation_player:
		left_animation_player.advance(delta)

func _anim_set_speed_scale(value: float) -> void:
	super(value)
	if left_animation_player:
		left_animation_player.speed_scale = value

# [right, left]: the revolver that fires next holds the odd round
func get_cylinder_rounds() -> Array[int]:
	var next := ceili(current_ammo / 2.0)
	var other := current_ammo - next
	if _next_is_left:
		return [other, next]
	return [next, other]

func _find_in(root: Node, type: String) -> Node:
	var found := root.find_children("*", type, true, false)
	return found[0] if not found.is_empty() else null
