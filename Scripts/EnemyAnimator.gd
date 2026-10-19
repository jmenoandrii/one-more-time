extends Node
class_name EnemyAnimator

# Plays Mixamo animations on a rigged enemy model.
# Every animation comes from its own FBX imported "As Animation Library" (skeleton only, no mesh);
# their tracks are relative to the imported scene root, so the AnimationPlayer drives the model root,
# and the model must have the same rig (e.g. auto-rigged on Mixamo: bones "mixamorig:...").
# A model without a Skeleton3D (a static mesh) just isn't animated — is_active() is false.

@export var model: Node3D # root of the instanced model scene
@export var idle: AnimationLibrary
@export var walk: AnimationLibrary
@export var attacks: Array[AnimationLibrary] = []
# named one-off animations played on purpose, not picked at random (e.g. the boss's "throw")
@export var specials: Dictionary[StringName, AnimationLibrary] = {}
@export var blend_time: float = 0.2
@export var walk_anim_speed: float = 2.0 # movement speed (m/s) at which the walk plays at normal speed

var _player: AnimationPlayer
var _skeleton: Skeleton3D
var _idle_name := &""
var _walk_name := &""
var _attack_names: Array[StringName] = []
var _special_names: Dictionary[StringName, StringName] = {} # special -> full animation name
var _last_attack := -1
var attack_speed := 1.0 # attacks play this many times faster (EnemyScaling)

func _ready() -> void:
	var skeletons: Array = model.find_children("*", "Skeleton3D", true, false) if model else []
	if skeletons.is_empty():
		push_warning("%s: the model has no skeleton, animations are off" % get_parent().name)
		return
	_skeleton = skeletons[0]

	_player = AnimationPlayer.new()
	_player.name = "EnemyAnimationPlayer"
	model.add_child(_player)
	_player.root_node = _player.get_path_to(model)

	_idle_name = _add(&"idle", idle, true)
	_walk_name = _add(&"walk", walk, true)
	for i in attacks.size():
		var anim_name := _add(StringName("attack_%d" % i), attacks[i], false)
		if anim_name != &"":
			_attack_names.append(anim_name)
	for special in specials:
		var anim_name := _add(StringName("special_%s" % special), specials[special], false)
		if anim_name != &"":
			_special_names[special] = anim_name
	play_idle()

func is_active() -> bool:
	return _player != null

func can_attack() -> bool:
	return _player != null and not _attack_names.is_empty()

func has_special(special: StringName) -> bool:
	return _special_names.has(special)

# returns its length in seconds, 0 if there is no such special
func play_special(special: StringName) -> float:
	if not has_special(special):
		return 0.0
	_player.speed_scale = 1.0
	_player.play(_special_names[special], 0.1)
	return _player.current_animation_length

func play_idle() -> void:
	# no idle clip: stand still on the first frame of the walk
	if _idle_name == &"" and _walk_name != &"":
		_play(_walk_name, 0.0)
		return
	_play(_idle_name, 1.0)

func play_walk(move_speed: float) -> void:
	_play(_walk_name, move_speed / walk_anim_speed)

# a random attack, not the same as the last one; returns its length in seconds
func play_random_attack() -> float:
	if not can_attack():
		return 0.0
	var i := randi() % _attack_names.size()
	if i == _last_attack and _attack_names.size() > 1:
		i = (i + 1) % _attack_names.size()
	_last_attack = i

	_player.speed_scale = attack_speed
	_player.play(_attack_names[i], 0.1)
	return _player.current_animation_length / attack_speed

# bone index by the end of its name ("RightHand" finds "mixamorig_RightHand"), -1 if none
func find_bone(name_suffix: String) -> int:
	if _skeleton == null:
		return -1
	for i in _skeleton.get_bone_count():
		if _skeleton.get_bone_name(i).ends_with(name_suffix):
			return i
	return -1

# where the bone is right now (animated pose), world space
func get_bone_position(bone: int) -> Vector3:
	return _skeleton.global_transform * _skeleton.get_bone_global_pose(bone).origin

func _play(anim_name: StringName, speed: float) -> void:
	if _player == null or anim_name == &"":
		return
	_player.speed_scale = speed
	if _player.current_animation != anim_name:
		_player.play(anim_name, blend_time)

# adds the library and returns the full name of its first animation ("walk/mixamo.com")
func _add(lib_name: StringName, lib: AnimationLibrary, loop: bool) -> StringName:
	if lib == null or lib.get_animation_list().is_empty():
		return &""
	_player.add_animation_library(lib_name, lib)
	var anim_name: StringName = lib.get_animation_list()[0]
	if loop:
		lib.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	return StringName("%s/%s" % [lib_name, anim_name])
