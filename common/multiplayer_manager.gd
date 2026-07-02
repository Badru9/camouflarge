extends Node

signal player_list_changed

const DEFAULT_PORT = 8910
var players: Dictionary = {} # Format: { peer_id: { "name": String } }
var local_player_name: String = "Player"

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func host_game() -> Error:
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(DEFAULT_PORT, 8)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	
	# Daftarkan server/host diri sendiri
	register_player(1, local_player_name)
	return OK

func join_game(ip: String) -> Error:
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip, DEFAULT_PORT)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	return OK

func register_player(id: int, new_name: String) -> void:
	players[id] = { "name": new_name }
	player_list_changed.emit()

func _on_peer_connected(id: int) -> void:
	# Kirim nama lokal ke peer yang baru tersambung
	rpc_id(id, "receive_player_info", multiplayer.get_unique_id(), local_player_name)

func _on_peer_disconnected(id: int) -> void:
	players.erase(id)
	player_list_changed.emit()

func _on_connected_to_server() -> void:
	var my_id = multiplayer.get_unique_id()
	register_player(my_id, local_player_name)

func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = null

func _on_server_disconnected() -> void:
	players.clear()
	multiplayer.multiplayer_peer = null
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")

@rpc("any_peer", "reliable")
func receive_player_info(id: int, new_name: String) -> void:
	register_player(id, new_name)
