extends Resource
class_name UpgradeData

# One upgrade card. Every .tres in res://Upgrades/ is a card in the pool;
# its file name is the id, so renaming a file loses that upgrade in an existing save.
# Every stack adds `flat` to the base stat, then multiplies it by `mult`.

@export var title: String
@export_multiline var description: String
@export var icon: Texture2D
@export_enum("move_speed", "jump", "max_stamina", "stamina_regen", "stamina_drain",
	"max_health", "fire_rate", "damage", "mag_size", "reserve_ammo", "reload_speed") var stat: String
@export var flat: float = 0.0
@export var mult: float = 1.0
@export var max_stacks: int = 5
@export var weight: float = 1.0 # chance to be offered, relative to the other cards

var id: String # set by RunState from the file name
