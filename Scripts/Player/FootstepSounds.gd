extends Node


# Called when the node enters the scene tree for the first time.
var tilemaps: Array[TileMapLayer] = []
const footstep_sounds = {
	"dirt": [
		preload("res://Sounds/Foot/Dirt/Footstep Dirt 1.ogg"),
		preload("res://Sounds/Foot/Dirt/Footstep Dirt 2.ogg"),
		preload("res://Sounds/Foot/Dirt/Footstep Dirt 3.ogg"),
		preload("res://Sounds/Foot/Dirt/Footstep Dirt 4.ogg")
	],
	"grass": [
		preload("res://Sounds/Foot/Grass/Footstep Grass 1.ogg"),
		preload("res://Sounds/Foot/Grass/Footstep Grass 2.ogg"),
		preload("res://Sounds/Foot/Grass/Footstep Grass 3.ogg"),
		preload("res://Sounds/Foot/Grass/Footstep Grass 4.ogg"),
		preload("res://Sounds/Foot/Grass/Footstep Grass 5.ogg"),
		preload("res://Sounds/Foot/Grass/Footstep Grass 6.ogg")
	],
}

func play_footstep(position: Vector2):
	var tile_data = []
	for tilemap in tilemaps:
		var tile_position = tilemap.local_to_map(position)
		var data = tilemap.get_cell_tile_data(position)
