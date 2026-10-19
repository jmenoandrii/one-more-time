extends CharacterBody3D
class_name Boss

# The final boss: a big goblin. Walks at the player and punches; from phase2_health on it is faster
# and also throws stones (from its palm) when the player keeps away.
# Reports its health to the boss bar (GameEvents), its death wins the run.

@export var speed: float = 3.0
@export var melee_damage: float = 25.0
@export var attack_range: float = 3.0 # starts a punch when the player is this close, m
@export var attack_hit_time: float = 0.5 # the hit lands at this part of the punch, 0..1
@export var attack_cooldown: float = 0.6

@export_group("Phase 2")
@export var phase2_health: float = 0.5 # part of the health left when it starts
@export var phase2_speed: float = 4.5
@export var stone_scene: PackedScene
@export var stone_damage: float = 20.0
@export var throw_min_distance: float = 6.0 # throws only at a player this far or more
@export var throw_cooldown: float = 3.5
@export var throw_release_time: float = 0.78 # s into the throw animation: the stone leaves the palm
@export var hand_bone: String = "RightHand" # end of the bone name; the forearm is "<side>ForeArm"
@export var palm_offset: float = 0.2 # past the wrist, toward the fingers, m

@onready var health_component: HealthComponent = $HealthComponent
@onready var animator: EnemyAnimator = $EnemyAnimator
@onready var throw_pos: Marker3D = $ThrowPos

@onready var goblin_sound: AudioStream
@onready var goblin_attack: AudioStreamPlayer3D = $AttackBoss
#@onready var goblin_ambient: GoblinGrowl = $GoblinAmbient
@onready var goblin_hurt: AudioStreamPlayer3D = get_node_or_null("GoblinHurt")
@onready var stone_break: AudioStream
@onready var boss_goblin_sounds: AudioStreamPlayer = $BossGoblinSounds
@onready var boss_hurt: AudioStreamPlayer3D = $BossHurt
@onready var boss_death: AudioStreamPlayer3D = $BossDeath

enum Action { NONE, PUNCH, THROW }
var player: Node3D
var _action := Action.NONE
var _action_time := 0.0
var _action_length := 0.0
var _action_done := false # the punch has landed / the stone is out
var _attack_cooldown_left := 0.0
var _throw_cooldown_left := 2.0
var _phase2 := false
var _dead := false
var _held_stone: Node3D
var _hand := -1
var _forearm := -1

func _ready() -> void:
	add_to_group("enemy") # e.g. the player's death camera looks at the nearest enemy
	player = get_tree().get_first_node_in_group("player")
	health_component.health_changed.connect(_on_health_changed)
	health_component.died.connect(_die)
	_on_health_changed(health_component.current_health, health_component.max_health)

	_hand = animator.find_bone(hand_bone)
	_forearm = animator.find_bone(hand_bone.replace("Hand", "ForeArm"))
	_create_held_stone()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	velocity.x = 0
	velocity.z = 0

	if not _dead and player and not player.is_player_dead:
		_attack_cooldown_left = maxf(_attack_cooldown_left - delta, 0.0)
		_throw_cooldown_left = maxf(_throw_cooldown_left - delta, 0.0)
		_face(player)

		if _action != Action.NONE:
			_update_action(delta)
		else:
			var distance := _flat_distance()
			if distance <= attack_range and _attack_cooldown_left <= 0.0 and animator.can_attack():
				_start(Action.PUNCH, animator.play_random_attack())
			elif _phase2 and distance >= throw_min_distance and _throw_cooldown_left <= 0.0 \
					and animator.has_special(&"throw"):
				_start(Action.THROW, animator.play_special(&"throw"))
				_held_stone.visible = true
			elif distance > attack_range * 0.9:
				var direction := (player.global_position - global_position)
				direction.y = 0
				direction = direction.normalized() * (phase2_speed if _phase2 else speed)
				velocity.x = direction.x
				velocity.z = direction.z

	move_and_slide()
	_update_locomotion()

func _process(_delta: float) -> void:
	if _held_stone and _held_stone.visible:
		_held_stone.global_position = _get_palm_position()

func _start(action: Action, length: float) -> void:
	_action = action
	_action_length = length
	_action_time = 0.0
	_action_done = false

func _update_action(delta: float) -> void:
	_action_time += delta
	
	match _action:
		
		Action.PUNCH:
			
			if not _action_done and _action_time >= _action_length * attack_hit_time:
				_action_done = true
				if _flat_distance() <= attack_range * 1.3:
					var health := player.get_node_or_null("HealthComponent") as HealthComponent
					if health:
						health.take_damage(melee_damage)
						
			if _action_time >= _action_length:
				goblin_attack.play()
				_action = Action.NONE
				_attack_cooldown_left = attack_cooldown
				
		Action.THROW:
			if not _action_done and _action_time >= throw_release_time:
				_action_done = true
				_throw_stone()
			if _action_time >= _action_length:
				_action = Action.NONE
				_throw_cooldown_left = throw_cooldown

func _throw_stone() -> void:
	_held_stone.visible = false
	if stone_scene == null:
		return
	var from := _get_palm_position()
	var target := player.global_position + Vector3(0, 1.0, 0)
	var stone = stone_scene.instantiate()
	stone.set(&"damage", stone_damage)
	stone.add_collision_exception_with(self) # the palm can be inside the boss's own box
	stone.transform = Transform3D(Basis.looking_at(target - from, Vector3.UP), from)
	get_tree().root.add_child(stone)

func _on_health_changed(current: float, maximum: float) -> void:
	boss_hurt.play()
	if not _phase2 and current <= maximum * phase2_health:
		_phase2 = true
	GameEvents.boss_health_changed.emit(current, maximum)
	

func _die() -> void:
	OneShotSound.play_copy(boss_death)
	if _dead:
		return
	_dead = true
	

	GameEvents.boss_defeated.emit()
	queue_free()

func _update_locomotion() -> void:
	if _action != Action.NONE:
		return
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if horizontal_speed > 0.1:
		animator.play_walk(horizontal_speed)
	else:
		animator.play_idle()

func _face(target: Node3D) -> void:
	var look_pos := Vector3(target.global_position.x, global_position.y, target.global_position.z)
	if global_position.distance_squared_to(look_pos) > 0.01:
		look_at(look_pos, Vector3.UP)

func _flat_distance() -> float:
	var offset := player.global_position - global_position
	offset.y = 0
	return offset.length()

func _get_palm_position() -> Vector3:
	if _hand < 0:
		return throw_pos.global_position
	var hand := animator.get_bone_position(_hand)
	if _forearm < 0:
		return hand
	var forearm := animator.get_bone_position(_forearm)
	return hand + (hand - forearm).normalized() * palm_offset

# the stone's meshes without its body, shown in the palm during the throw
func _create_held_stone() -> void:
	_held_stone = Node3D.new()
	_held_stone.top_level = true
	_held_stone.visible = false
	add_child(_held_stone)
	if stone_scene == null:
		return
	var stone := stone_scene.instantiate()
	for child in stone.get_children():
		if child is VisualInstance3D:
			child.owner = null # it leaves its scene: the old owner would be wrong
			child.reparent(_held_stone, false)
	stone.free()
