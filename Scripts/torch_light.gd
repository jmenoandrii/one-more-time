extends OmniLight3D

# A torch: warm light that flickers (a few sine waves of different speeds, a random start per torch).

@export var flicker: float = 0.18 # how much the energy wobbles, part of the base energy
@export var speed: float = 7.0

var _base_energy: float
var _time := 0.0

func _ready() -> void:
	_base_energy = light_energy
	_time = randf() * 100.0

func _process(delta: float) -> void:
	_time += delta * speed
	var wave := sin(_time) * 0.5 + sin(_time * 2.7 + 1.3) * 0.3 + sin(_time * 5.3 + 0.7) * 0.2
	light_energy = _base_energy * (1.0 + flicker * wave)
