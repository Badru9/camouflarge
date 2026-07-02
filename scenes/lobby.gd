extends Control

@onready var name_input: LineEdit = $Panel/VBoxContainer/NameInput
@onready var ip_input: LineEdit = $Panel/VBoxContainer/IPInput
@onready var player_list: ItemList = $Panel/VBoxContainer/PlayerList
@onready var start_button: Button = $Panel/VBoxContainer/StartButton

func _ready() -> void:
	MultiplayerManager.player_list_changed.connect(_update_player_list)
	_update_player_list()

func _on_host_button_pressed() -> void:
	MultiplayerManager.local_player_name = name_input.text if name_input.text != "" else "Host"
	var err = MultiplayerManager.host_game()
	if err == OK:
		start_button.visible = true
		_update_player_list()

func _on_join_button_pressed() -> void:
	MultiplayerManager.local_player_name = name_input.text if name_input.text != "" else "Client"
	var ip = ip_input.text if ip_input.text != "" else "127.0.0.1"
	var err = MultiplayerManager.join_game(ip)
	if err == OK:
		start_button.visible = false

func _update_player_list() -> void:
	player_list.clear()
	for id in MultiplayerManager.players:
		player_list.add_item(MultiplayerManager.players[id]["name"])

func _on_start_button_pressed() -> void:
	if multiplayer.is_server():
		# Pemicu scene transition otomatis di semua client via RPC
		rpc("start_game_scene")

@rpc("call_local", "reliable")
func start_game_scene() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")
