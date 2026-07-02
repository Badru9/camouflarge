extends Node

@onready var viewport1: SubViewport = $GridContainer/ViewportContainer1/Viewport1
@onready var viewport2: SubViewport = $GridContainer/ViewportContainer2/Viewport2

func _ready() -> void:
	# Pastikan Viewport 2 membagikan World3D yang sama dengan Viewport 1
	viewport2.world_3d = viewport1.world_3d
	
	# Instantiate player 1 di Viewport 1
	var player1 = preload("res://scenes/player.tscn").instantiate()
	player1.player_id = 1
	player1.name = "Player1"
	player1.global_position = Vector3(-2, 1, 0)
	viewport1.get_node("Map").add_child(player1)
	
	# Instantiate player 2 di Viewport 2
	var player2 = preload("res://scenes/player.tscn").instantiate()
	player2.player_id = 2
	player2.name = "Player2"
	player2.global_position = Vector3(2, 1, 0)
	viewport1.get_node("Map").add_child(player2)
	
	# Set target camera untuk masing-masing viewport
	viewport1.get_camera_3d().reparent(player1.get_node("CameraPivot"))
	viewport1.get_camera_3d().position = Vector3.ZERO
	viewport1.get_camera_3d().rotation = Vector3.ZERO
	
	viewport2.get_camera_3d().reparent(player2.get_node("CameraPivot"))
	viewport2.get_camera_3d().position = Vector3.ZERO
	viewport2.get_camera_3d().rotation = Vector3.ZERO
