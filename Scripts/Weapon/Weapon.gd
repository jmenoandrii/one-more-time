extends Node3D
class_name Weapon

signal ammo_updated(current: int, maximum: int)
signal reserve_ammo_changed(amount: int) # reserve left, sent on every round loaded during a reload

@export var weapon_name: String
@export var pickup_name: String # which pickup gives this weapon; empty = weapon_name
@export var bullet_scene: PackedScene
@export var fire_rate: float = 0.5 # in sec
@export var max_ammo: int = 6
@export var damage: float = 25.0 # per bullet
@export var animation_player: AnimationPlayer
@export var shoot_animation: StringName = &"fire"
@export var reload_animation: StringName = &"reload"
@export var reload_close_marker: StringName = &"close" # marker in the reload animation: fast-forward to it once no more rounds are needed
@export var reload_fast_forward_speed: float = 4.0
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

# draw: when switched to, the weapon pops up from below on a spring (with a little overshoot)
@export_group("Draw")
@export var draw_depth: float = 0.35 # how far below the rest position it starts, m
@export var draw_tilt: float = 1.5 # muzzle down while low, rad per meter of depth
@export var draw_stiffness: float = 150.0 # spring strength: higher = faster
@export var draw_damping: float = 12.0 # lower = bouncier

# inspect: while held, the weapon moves to this pose (camera space) and plays the idle animation
@export_group("Inspect")
@export var can_inspect: bool = true
@export var inspect_animation: StringName = &"inspect"
@export var idle_animation: StringName = &"idle" # rest pose, used to blend out of the inspect
@export var inspect_offset: Vector3 = Vector3(-0.25, 0.08, 0.1) # left, up, closer
@export var inspect_rotation: Vector3 = Vector3(0.15, 0.7, 0.3) # muzzle up, turn side to the camera, tilt
@export var inspect_blend_speed: float = 8.0

var current_ammo: int
var reload_speed: float = 1.0 # speed of the reload animation, from the run's upgrades
var can_shoot: bool = true
var is_reloading: bool = false
var is_inspecting: bool = false
var is_equipping: bool = false
var _reload_reserve: int = 0 # reserve ammo that the current reload can still take rounds from
var _reload_close_time: float = -1.0 # >= 0 while fast-forwarding the reload to this time
var _inspect_weight := 0.0
var _draw_offset := 0.0 # < 0 while the weapon is below its rest position
var _draw_velocity := 0.0
var shooter: PhysicsBody3D # body that holds the weapon, bullets ignore it

var _rest_transform: Transform3D
var _recoil_target_rot := Vector3.ZERO
var _recoil_target_pos := Vector3.ZERO
var _recoil_rot := Vector3.ZERO
var _recoil_pos := Vector3.ZERO

@onready var bullet_pos: Marker3D = $BulletPos
@export var shoot_sound: AudioStreamPlayer3D
@export var reload_sound: AudioStreamPlayer3D # click, played for every round loaded during a reload
@export var reload_sound_offset: float = 0.6 # the click in the sound file starts here

func _ready() -> void:
	_apply_upgrades()
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
	if reload_sound == null:
		reload_sound = find_child("ReloadSound", true, false) as AudioStreamPlayer3D

	_connect_model(animation_player)
	
	is_owned = owned_at_start
	
	var node := get_parent()
	while node != null and not node is PhysicsBody3D:
		node = node.get_parent()
	shooter = node

# "fire_rate" upgrades are shots per second, so the delay between shots is divided by them
func _apply_upgrades() -> void:
	fire_rate /= RunState.get_stat("fire_rate", 1.0)
	max_ammo = int(RunState.get_stat("mag_size", max_ammo))
	damage = RunState.get_stat("damage", damage)
	reload_speed = RunState.get_stat("reload_speed", 1.0)

func _process(delta: float) -> void:
	_update_reload_fast_forward()
	
	# target decays back to rest, the weapon chases the target -> sharp kick, smooth return
	_recoil_target_rot = _recoil_target_rot.lerp(Vector3.ZERO, 1.0 - exp(-recoil_return_speed * delta))
	_recoil_target_pos = _recoil_target_pos.lerp(Vector3.ZERO, 1.0 - exp(-recoil_return_speed * delta))
	_recoil_rot = _recoil_rot.lerp(_recoil_target_rot, 1.0 - exp(-recoil_snappiness * delta))
	_recoil_pos = _recoil_pos.lerp(_recoil_target_pos, 1.0 - exp(-recoil_snappiness * delta))

	_inspect_weight = lerpf(_inspect_weight, 1.0 if is_inspecting else 0.0, 1.0 - exp(-inspect_blend_speed * delta))

	# draw spring (semi-implicit Euler): pulls the offset to 0 and overshoots a bit
	_draw_velocity += (-draw_stiffness * _draw_offset - draw_damping * _draw_velocity) * delta
	_draw_offset += _draw_velocity * delta

	var rot := _recoil_rot + inspect_rotation * _inspect_weight + Vector3(_draw_offset * draw_tilt, 0, 0)
	var pos := _recoil_pos + inspect_offset * _inspect_weight + Vector3(0, _draw_offset, 0)

	# rotate around the weapon's own origin, but along the camera axes
	transform = Transform3D(Basis.from_euler(rot) * _rest_transform.basis, _rest_transform.origin + pos)

func shoot(target_point: Vector3) -> void:
	# shot accessibility check
	if not can_shoot or is_reloading or is_inspecting or is_equipping or current_ammo <= 0:
		return
	if is_drawing():
		return
	if not _is_ready_to_fire():
		return
		
	# shooting
	can_shoot = false
	_update_ammo(current_ammo - 1)
	_fire(target_point)
	_add_recoil()
	
	# timer
	await get_tree().create_timer(fire_rate).timeout
	can_shoot = true

# extra readiness check; DualWeapon uses it for a cooldown per revolver
func _is_ready_to_fire() -> bool:
	return true

# one shot: animation, sound, bullet; DualWeapon overrides it to alternate the barrels
func _fire(target_point: Vector3) -> void:
	_play_shoot_animation(animation_player)
	if shoot_sound:
		shoot_sound.play() # pitch/volume variation comes from the AudioStreamRandomizer stream
	_spawn_bullet(bullet_pos, target_point)

func _spawn_bullet(muzzle: Node3D, target_point: Vector3) -> void:
	var instance: PhysicsBody3D = bullet_scene.instantiate()
	
	# place the bullet before adding it to the tree,
	# otherwise it appears at (0, 0, 0) for a moment — inside the player
	var from := muzzle.global_position
	instance.transform = Transform3D(Basis.looking_at(target_point - from, Vector3.UP), from)
	if shooter:
		instance.add_collision_exception_with(shooter)
	instance.set(&"damage", damage)

	get_tree().root.add_child(instance)

func _play_shoot_animation(player: AnimationPlayer) -> void:
	if player == null:
		return
	
	# restart from the beginning even if the previous shot is still playing;
	# keep_state = true, otherwise stop() rewinds the last animation (e.g. equip) to its first frame
	player.stop(true)
	player.play(shoot_animation, -1, randf_range(shoot_speed_min, shoot_speed_max))

# animation helpers: everything except the shot goes through them, so DualWeapon can mirror it on both guns
func _anim_play(anim: StringName, blend: float = -1.0, speed: float = 1.0) -> void:
	animation_player.play(anim, blend, speed)

func _anim_stop() -> void:
	animation_player.stop()

func _anim_advance(delta: float) -> void:
	animation_player.advance(delta)

func _anim_set_speed_scale(value: float) -> void:
	animation_player.speed_scale = value

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
	
	_reload_reserve = reserve_ammo
	
	if animation_player and animation_player.has_animation(reload_animation):
		is_reloading = true
		is_inspecting = false
		# the animation calls load_reload_round() on every cylinder click
		# custom speed, separate from speed_scale, which the fast-forward changes
		_anim_play(reload_animation, 0.2, reload_speed)
		await animation_player.animation_finished
	
	# top up whatever the animation didn't load (e.g. a weapon without per-click calls)
	var missing: int = min(max_ammo - current_ammo, _reload_reserve)
	if missing > 0:
		_load_rounds(missing)
	
	is_reloading = false
	return _reload_reserve

# called from the reload animation (method track) on every click: +1 round
func load_reload_round() -> void:
	if not is_reloading or current_ammo >= max_ammo or _reload_reserve <= 0:
		return
	
	_load_rounds(1)
	# the click sounds only when a round actually goes in, so a fast-forward stays silent
	if reload_sound:
		reload_sound.play(reload_sound_offset)
	
	if current_ammo == max_ammo or _reload_reserve == 0:
		_start_reload_fast_forward()

# shortens the reload: play the rest up to the close marker faster instead of jumping,
# so everything that moves during the reload stays continuous
func _start_reload_fast_forward() -> void:
	var anim := animation_player.get_animation(reload_animation)
	if not anim.has_marker(reload_close_marker):
		return
	
	var close_time := anim.get_marker_time(reload_close_marker)
	if animation_player.current_animation_position < close_time:
		_reload_close_time = close_time
		_anim_set_speed_scale(reload_fast_forward_speed)

func _update_reload_fast_forward() -> void:
	if _reload_close_time < 0.0:
		return
	
	var reached := animation_player.current_animation != reload_animation \
		or animation_player.current_animation_position >= _reload_close_time
	if not is_reloading or reached:
		_anim_set_speed_scale(1.0)
		_reload_close_time = -1.0

func _load_rounds(amount: int) -> void:
	_reload_reserve -= amount
	_update_ammo(current_ammo + amount)
	reserve_ammo_changed.emit(_reload_reserve)

func play_equip() -> void:
	if animation_player == null or not animation_player.has_animation(equip_animation):
		return
	
	is_equipping = true
	is_inspecting = false
	_anim_play(equip_animation)
	_anim_advance(0) # apply the first frame now, so the weapon doesn't flash at rest
	await animation_player.animation_finished
	is_equipping = false

func play_draw() -> void:
	_draw_offset = -draw_depth
	_draw_velocity = 0.0

# still coming up from below (the overshoot above the rest position doesn't count)
func is_drawing() -> bool:
	return _draw_offset < -0.05

func set_inspecting(value: bool) -> void:
	value = value and can_inspect and not is_reloading and not is_equipping
	if value == is_inspecting:
		return
	is_inspecting = value

	if animation_player == null or not animation_player.has_animation(inspect_animation):
		return
	if is_inspecting:
		_anim_play(inspect_animation, 0.3)
	elif animation_player.current_animation == inspect_animation:
		# blend back to the rest pose instead of snapping
		if animation_player.has_animation(idle_animation):
			_anim_play(idle_animation, 0.3)
		else:
			_anim_stop()

# the model's reload animation reports every round through its WeaponModel root
func _connect_model(player: AnimationPlayer) -> void:
	if player == null:
		return
	var model := player.get_node_or_null(player.root_node)
	if model and model.has_signal("round_loaded"):
		model.round_loaded.connect(load_reload_round)

func _update_ammo(ammo: int) -> void:
	current_ammo = ammo
	ammo_updated.emit(current_ammo, max_ammo)
