extends Node3D

@onready var map_node = $Map

func _ready() -> void:
	if not multiplayer.is_server():
		return
		
	# Sambungkan event join/leave baru jika ada pemain yang menyusul saat game berjalan
	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(remove_player)
	
	# Spawn player untuk semua yang ada di lobby saat ini
	for id in MultiplayerManager.players:
		add_player(id)

func add_player(id: int) -> void:
	var player = preload("res://scenes/player.tscn").instantiate()
	player.name = str(id)
	
	# Tentukan posisi spawn acak atau berdasarkan id
	var spawn_offset = randf_range(-4.0, 4.0)
	player.position = Vector3(spawn_offset, 1.0, spawn_offset - 4.0)
	
	add_child(player, true)

func remove_player(id: int) -> void:
	if has_node(str(id)):
		get_node(str(id)).queue_free()
