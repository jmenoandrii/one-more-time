extends Resource
class_name EnemyScaling

# How much stronger the goblins get with the upgrades the player has bought this run.
# Every curve: x = upgrades bought (RunState.get_upgrade_count()), y = a multiplier;
# past the last point the last value holds. The values live in Data/enemy_scaling.tres.

const PATH := "res://Data/enemy_scaling.tres"

@export var attack_speed: Curve # punches / throws per time: their animations, aiming and pauses
@export var move_speed: Curve
@export var damage: Curve

static var _scaling: EnemyScaling

# the multiplier of one curve for the run as it is now; 1 without the file or the curve
static func factor(curve_name: StringName) -> float:
	if _scaling == null:
		_scaling = load(PATH) as EnemyScaling
	if _scaling == null:
		return 1.0
	var curve := _scaling.get(curve_name) as Curve
	if curve == null:
		return 1.0
	return curve.sample(RunState.get_upgrade_count())
