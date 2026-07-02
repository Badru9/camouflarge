# Mecha Chameleon Multiplayer Lobby Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mengubah arsitektur game dari split-screen lokal menjadi online P2P multiplayer berbasis ENet, lengkap dengan UI Lobby (Host/Join) dan sinkronisasi posisi player via jaringan.

**Architecture:** Menggunakan Autoload `multiplayer_manager.gd` untuk mengelola koneksi. Scene `lobby.tscn` digunakan sebagai gerbang koneksi sebelum berganti ke `main.tscn` (arena game). Di arena game, `MultiplayerSpawner` akan menangani pembuatan player secara otomatis, dan `MultiplayerSynchronizer` di dalam player scene akan menyelaraskan posisi, rotasi, dan visual player.

**Tech Stack:** Godot Engine 4.7, ENetMultiplayerPeer, MultiplayerSynchronizer, MultiplayerSpawner.

## Global Constraints

- Proyek berjalan pada Godot 4.7.
- Seluruh script logic diletakkan di bawah folder `components/`, `common/`, atau `scenes/` sesuai rancangan spesifikasi.
- Semua properti yang disinkronkan via `MultiplayerSynchronizer` harus didefinisikan secara eksplisit.

---

### Task 1: Create Multiplayer Manager Autoload

**Files:**
- Create: `common/multiplayer_manager.gd`
- Modify: `project.godot`

**Interfaces:**
- Produces: Autoload `MultiplayerManager` dengan fungsi `host_game()`, `join_game()`, variabel `players`, dan sinyal `player_list_changed`.

- [ ] **Step 1: Buat script `common/multiplayer_manager.gd`**

```gdscript
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
```

- [ ] **Step 2: Daftarkan `MultiplayerManager` sebagai Autoload di `project.godot`**

Tambahkan baris berikut di bawah bagian `[autoload]` dalam file `project.godot`:

```ini
[autoload]

MultiplayerManager="*res://common/multiplayer_manager.gd"
```

- [ ] **Step 3: Commit perubahan Autoload**

```bash
git add common/multiplayer_manager.gd project.godot
git commit -m "feat: add MultiplayerManager autoload for ENet P2P connection"
```

---

### Task 2: Implement Lobby UI

**Files:**
- Create: `scenes/lobby.tscn`
- Create: `scenes/lobby.gd`
- Modify: `project.godot`

**Interfaces:**
- Consumes: `MultiplayerManager` Autoload dari Task 1.
- Produces: Scene menu utama untuk Host, Join, melihat Player List, dan Start Game.

- [ ] **Step 1: Buat script `scenes/lobby.gd`**

```gdscript
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
		# Pemicu scene transition otomatis di semua client via scene packer
		rpc("start_game_scene")

@rpc("call_local", "reliable")
func start_game_scene() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")
```

- [ ] **Step 2: Buat scene `scenes/lobby.tscn`**

Buat node UI dasar untuk menu Lobby.

```text
[gd_scene load_steps=2 format=3 uid="uid://clobby123"]

[ext_resource type="Script" path="res://scenes/lobby.gd" id="1_lobby_script"]

[node name="Lobby" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_lobby_script")

[node name="Panel" type="Panel" parent="."]
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -200.0
offset_top = -250.0
offset_right = 200.0
offset_bottom = 250.0
grow_horizontal = 2
grow_vertical = 2

[node name="VBoxContainer" type="VBoxContainer" parent="Panel"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 20.0
offset_top = 20.0
offset_right = -20.0
offset_bottom = -20.0
grow_horizontal = 2
grow_vertical = 2
theme_override_constants/separation = 12

[node name="Label" type="Label" parent="Panel/VBoxContainer"]
layout_mode = 2
text = "MECHA CHAMELEON LOBBY"
horizontal_alignment = 1

[node name="NameInput" type="LineEdit" parent="Panel/VBoxContainer"]
layout_mode = 2
placeholder_text = "Masukkan Nama..."

[node name="IPInput" type="LineEdit" parent="Panel/VBoxContainer"]
layout_mode = 2
text = "127.0.0.1"
placeholder_text = "IP Server (untuk Join)..."

[node name="HBoxContainer" type="HBoxContainer" parent="Panel/VBoxContainer"]
layout_mode = 2
theme_override_constants/separation = 20

[node name="HostButton" type="Button" parent="Panel/VBoxContainer/HBoxContainer"]
layout_mode = 2
size_flags_horizontal = 3
text = "Host Game"

[node name="JoinButton" type="Button" parent="Panel/VBoxContainer/HBoxContainer"]
layout_mode = 2
size_flags_horizontal = 3
text = "Join Game"

[node name="PlayerListLabel" type="Label" parent="Panel/VBoxContainer"]
layout_mode = 2
text = "Pemain Terkoneksi:"

[node name="PlayerList" type="ItemList" parent="Panel/VBoxContainer"]
layout_mode = 2
size_flags_vertical = 3

[node name="StartButton" type="Button" parent="Panel/VBoxContainer"]
visible = false
layout_mode = 2
text = "Mulai Permainan (Host)"

[connection signal="pressed" from="Panel/VBoxContainer/HBoxContainer/HostButton" to="." method="_on_host_button_pressed"]
[connection signal="pressed" from="Panel/VBoxContainer/HBoxContainer/JoinButton" to="." method="_on_join_button_pressed"]
[connection signal="pressed" from="Panel/VBoxContainer/StartButton" to="." method="_on_start_button_pressed"]
```

- [ ] **Step 3: Ubah main scene default ke Lobby**

Di `project.godot`, set main scene ke `res://scenes/lobby.tscn`.

```ini
[application]
run/main_scene="res://scenes/lobby.tscn"
```

- [ ] **Step 4: Commit UI Lobby**

```bash
git add scenes/lobby.tscn scenes/lobby.gd project.godot
git commit -m "feat: implement Lobby UI for Host and Join operations"
```

---

### Task 3: Refactor Player for Single Control & Sync

**Files:**
- Modify: `scenes/player.tscn`
- Modify: `scenes/player.gd`

**Interfaces:**
- Produces: `Player` node yang dikontrol mouse/WASD lokal dengan properti sinkronisasi jaringan via `MultiplayerSynchronizer`.

- [ ] **Step 1: Refactor `scenes/player.gd` untuk mouse look dan multiplayer authority**

```gdscript
extends CharacterBody3D

@export var speed: float = 5.0
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.003

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D

func _enter_tree() -> void:
	# Jadikan nama node sesuai dengan peer id multiplayer agar mudah disinkronkan
	set_multiplayer_authority(name.to_int())

func _ready() -> void:
	if is_multiplayer_authority():
		camera.make_current()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		camera.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
		
	# Mouse look
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, -deg_to_rad(70), deg_to_rad(70))
		
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	# Tambahkan gravitasi
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Hanya multiplayer authority yang memproses input lokal
	if not is_multiplayer_authority():
		return

	# Handle Jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity

	# Baca input pergerakan
	var input_dir = Input.get_vector("p1_move_left", "p1_move_right", "p1_move_forward", "p1_move_back")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()
```

- [ ] **Step 2: Modifikasi `scenes/player.tscn` dengan `MultiplayerSynchronizer`**

Ganti isi `scenes/player.tscn` untuk menambahkan komponen sinkronisasi properti `position` dan `rotation` (dan `velocity` / `camera_pivot` rotation).

```text
[gd_scene load_steps=6 format=3 uid="uid://cplayer123"]

[ext_resource type="Script" path="res://scenes/player.gd" id="1_script"]

[sub_resource type="CapsuleShape3D" id="CapsuleShape3D_1"]
radius = 0.5
height = 2.0

[sub_resource type="CapsuleMesh" id="CapsuleMesh_1"]
radius = 0.5
height = 2.0

[sub_resource type="SceneReplicationConfig" id="SceneReplicationConfig_1"]
properties/0/path = NodePath(".:position")
properties/0/spawn = true
properties/0/replication_mode = 1
properties/1/path = NodePath(".:rotation")
properties/1/spawn = true
properties/1/replication_mode = 1
properties/2/path = NodePath("CameraPivot:rotation")
properties/2/spawn = true
properties/2/replication_mode = 1

[node name="Player" type="CharacterBody3D"]
script = ExtResource("1_script")

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0)
shape = SubResource("CapsuleShape3D_1")

[node name="MeshInstance3D" type="MeshInstance3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0)
mesh = SubResource("CapsuleMesh_1")

[node name="CameraPivot" type="Node3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.5, 0)

[node name="Camera3D" type="Camera3D" parent="CameraPivot"]

[node name="MultiplayerSynchronizer" type="MultiplayerSynchronizer" parent="."]
replication_config = SubResource("SceneReplicationConfig_1")
```

- [ ] **Step 3: Commit perbaikan Player**

```bash
git add scenes/player.gd scenes/player.tscn
git commit -m "feat: implement mouse look, multiplayer authority, and property replication"
```

---

### Task 4: Refactor Main Scene for Dynamic Spawning

**Files:**
- Modify: `scenes/main.tscn`
- Modify: `scenes/main.gd`

**Interfaces:**
- Consumes: `Player` scene dengan MultiplayerSynchronizer dari Task 3.
- Produces: Arena utama yang otomatis men-spawn instance player baru untuk setiap client yang terhubung.

- [ ] **Step 1: Tulis ulang `scenes/main.gd` untuk Spawning Multiplayer**

```gdscript
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
```

- [ ] **Step 2: Update `scenes/main.tscn` dengan `MultiplayerSpawner`**

Ganti isi `scenes/main.tscn` untuk menghapus GridContainer/Viewport split-screen dan menggantinya dengan satu Node 3D biasa yang memiliki `MultiplayerSpawner`.

```text
[gd_scene load_steps=3 format=3 uid="uid://cmain123"]

[ext_resource type="Script" path="res://scenes/main.gd" id="1_main_script"]
[ext_resource type="PackedScene" uid="uid://cmap123" path="res://scenes/map.tscn" id="2_map_scene"]

[node name="Main" type="Node3D"]
script = ExtResource("1_main_script")

[node name="Map" parent="." instance=ExtResource("2_map_scene")]

[node name="MultiplayerSpawner" type="MultiplayerSpawner" parent="."]
_spawnable_scenes = PackedStringArray("res://scenes/player.tscn")
spawn_path = NodePath("..")
```

- [ ] **Step 3: Commit perubahan Main Scene**

```bash
git add scenes/main.tscn scenes/main.gd
git commit -m "feat: rewrite main scene to support MultiplayerSpawner dynamic replication"
```
