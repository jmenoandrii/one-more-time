extends Node3D

signal ammo_updated(current: int, maximum: int)

@export var weapon_name: String
@export var bullet_scene: PackedScene
@export var fire_rate: float = 0.5 # in sec
@export var max_ammo: int = 6
@export var animation_player: AnimationPlayer
@export var shoot_animation: StringName = &"fire"
@export var reload_animation: StringName = &"reload"
@export var equip_animation: StringName = &"equip"
@export var shoot_speed_min: float = 0.9 # random speed of the shoot animation,
@export var shoot_speed_max: float = 1.15 # so shots don't look identical
@export var owned_at_start: bool = false
var is_owned: bool

# procedural recoil: every shot gets random values from these ranges
# (angles in radians, distances in meters, in camera space)
@export_group("Recoil")
@export var recoil_pitch: Vector2 = Vector2(0.3, 0.45) # muzzle up, min..max
@export var recoil_yaw: float = 0.08 # left/right, random ±
@export var recoil_roll: float = 0.12 # tilt, random ±
@export var recoil_kick: Vector2 = Vector2(0.1, 0.15) # back toward the camera, min..max
@export var recoil_max_pitch: float = 0.8 # cap when shots stack up
@export var recoil_snappiness: float = 35.0 # how fast the weapon reaches the kick
@export var recoil_return_speed: float = 10.0 # how fast it comes back

# inspect: while held, the weapon moves to this pose (camera space) and plays the idle animation
@export_group("Inspect")
@export var inspect_animation: StringName = &"inspect"
@export var idle_animation: StringName = &"idle" # rest pose, used to blend out of the inspect
@export var inspect_offset: Vector3 = Vector3(-0.25, 0.08, 0.1) # left, up, closer
@export var inspect_rotation: Vector3 = Vector3(0.15, 0.7, 0.3) # muzzle up, turn side to the camera, tilt
@export var inspect_blend_speed: float = 8.0

var current_ammo: int
var can_shoot: bool = true
var is_reloading: bool = false
var is_inspecting: bool = false
var is_equipping: bool = false
var _inspect_weight := 0.0
var shooter: PhysicsBody3D # body that holds the weapon, bullets ignore it

var _rest_transform: Transform3D
var _recoil_target_rot := Vector3.ZERO
var _recoil_target_pos := Vector3.ZERO
var _recoil_rot := Vector3.ZERO
var _recoil_pos := Vector3.ZERO

@onready var bullet_pos: Marker3D = $BulletPos
@export var shoot_sound: AudioStreamPlayer3D

func _ready() -> void:
	current_ammo = max_ammo
	_rest_transform = transform

	# fallback: use the first AnimationPlayer inside the weapon (incl. instanced model scenes)
	if animation_player == null:
		var players := find_children("*", "AnimationPlayer", true, false)
		if not players.is_empty():
			animation_player = players[0]

	# fallback: a child named ShootSound (incl. inside the instanced model scene)
	if shoot_sound == null:
		shoot_sound = find_child("ShootSound", true, false) as AudioStreamPlayer3D

	is_owned = owned_at_start
	
	var node := get_parent()
	while node != null and not node is PhysicsBody3D:
		node = node.get_parent()
	shooter = node

func _process(delta: float) -> void:
	# target decays back to rest, the weapon chases the target -> sharp kick, smooth return
	_recoil_target_rot = _recoil_target_rot.lerp(Vector3.ZERO, 1.0 - exp(-recoil_return_speed * delta))
	_recoil_target_pos = _recoil_target_pos.lerp(Vector3.ZERO, 1.0 - exp(-recoil_return_speed * delta))
	_recoil_rot = _recoil_rot.lerp(_recoil_target_rot, 1.0 - exp(-recoil_snappiness * delta))
	_recoil_pos = _recoil_pos.lerp(_recoil_target_pos, 1.0 - exp(-recoil_snappiness * delta))

	_inspect_weight = lerpf(_inspect_weight, 1.0 if is_inspecting else 0.0, 1.0 - exp(-inspect_blend_speed * delta))

	var rot := _recoil_rot + inspect_rotation * _inspect_weight
	var pos := _recoil_pos + inspect_offset * _inspect_weight

	# rotate around the weapon's own origin, but along the camera axes
	transform = Transform3D(Basis.from_euler(rot) * _rest_transform.basis, _rest_transform.origin + pos)

func shoot(target_point: Vector3) -> void:
	# shot accessibility check
	if not can_shoot or is_reloading or is_inspecting or is_equipping or current_ammo <= 0:
		return
		
	# shooting
	can_shoot = false
	_update_ammo(current_ammo - 1)
	_play_shoot_animation()
	_add_recoil()
	
	if shoot_sound:
		shoot_sound.play() # pitch/volume variation comes from the AudioStreamRandomizer stream

	var instance: PhysicsBody3D = bullet_scene.instantiate()
	
	var from := bullet_pos.global_position
	instance.transform = Transform3D(Basis.looking_at(target_point - from, Vector3.UP), from)
	if shooter:
		instance.add_collision_exception_with(shooter)
	
	get_tree().root.add_child(instance)
	
	# timer
	await get_tree().create_timer(fire_rate).timeout
	can_shoot = true

func _play_shoot_animation() -> void:
	if animation_player == null:
		return
	
	# restart from the beginning even if the previous shot is still playing;
	# keep_state = true, otherwise stop() rewinds the last animation (e.g. equip) to its first frame
	animation_player.stop(true)
	animation_player.play(shoot_animation, -1, randf_range(shoot_speed_min, shoot_speed_max))

func _add_recoil() -> void:
	# added on top of the current recoil, so fast shots stack up
	_recoil_target_rot += Vector3(
		randf_range(recoil_pitch.x, recoil_pitch.y),
		randf_range(-recoil_yaw, recoil_yaw),
		randf_range(-recoil_roll, recoil_roll))
	_recoil_target_rot.x = min(_recoil_target_rot.x, recoil_max_pitch)

	var kick := randf_range(recoil_kick.x, recoil_kick.y)
	_recoil_target_pos += Vector3(0, kick * 0.3, kick)

func reload(reserve_ammo: int) -> int:
	if is_reloading or is_equipping or current_ammo == max_ammo or reserve_ammo <= 0:
		return reserve_ammo
	
	var needed_ammo = max_ammo - current_ammo
  
	if animation_player and animation_player.has_animation(reload_animation):
		is_reloading = true
		is_inspecting = false
		animation_player.play(reload_animation, 0.2)

		await animation_player.animation_finished
		is_reloading = false
	
	if reserve_ammo >= needed_ammo:
		_update_ammo(current_ammo + needed_ammo)
		reserve_ammo -= needed_ammo
	else:
		_update_ammo(current_ammo + reserve_ammo)
		reserve_ammo = 0
		
	return reserve_ammo

func play_equip() -> void:
	if animation_player == null or not animation_player.has_animation(equip_animation):
		return
	
	is_equipping = true
	is_inspecting = false
	animation_player.play(equip_animation)
	animation_player.advance(0) # apply the first frame now, so the weapon doesn't flash at rest
	await animation_player.animation_finished
	is_equipping = false

func set_inspecting(value: bool) -> void:
	value = value and not is_reloading and not is_equipping
	if value == is_inspecting:
		return
	is_inspecting = value

	if animation_player == null or not animation_player.has_animation(inspect_animation):
		return
	if is_inspecting:
		animation_player.play(inspect_animation, 0.3)
	elif animation_player.current_animation == inspect_animation:
		# blend back to the rest pose instead of snapping
		if animation_player.has_animation(idle_animation):
			animation_player.play(idle_animation, 0.3)
		else:
			animation_player.stop()

func _update_ammo(ammo: int) -> void:
	current_ammo = ammo
	ammo_updated.emit(current_ammo, max_ammo)
