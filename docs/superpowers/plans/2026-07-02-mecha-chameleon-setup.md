# Mecha Chameleon Setup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Menyiapkan struktur direktori dasar proyek, konfigurasi Input Map untuk multiplayer lokal (Player 1 & Player 2), dan membuat scene utama `main.tscn` dengan sistem Split-Screen Viewport awal.

**Architecture:** Menggunakan pengaturan scene utama dengan `GridContainer` yang menampung dua `SubViewportContainer` untuk membuat split-screen P1 dan P2 secara lokal. Masing-masing viewport akan memuat instance `player.tscn` dengan input mapping dinamis berdasarkan `player_id`.

**Tech Stack:** Godot Engine 4.7, GDScript.

## Global Constraints

- Proyek berjalan pada Godot 4.7.
- Sistem fisika menggunakan Jolt Physics (sudah terkonfigurasi).
- Seluruh script logic diletakkan di bawah folder `components/`, `common/`, atau `scenes/` sesuai rancangan spesifikasi.

---

### Task 1: Setup Input Map & Project Configuration

**Files:**
- Modify: `project.godot`

**Interfaces:**
- Produces: Input mapping actions (`p1_move_forward`, `p1_move_back`, `p1_move_left`, `p1_move_right`, `p1_interact`, `p1_toggle_camera`, `p2_move_forward`, `p2_move_back`, `p2_move_left`, `p2_move_right`, `p2_interact`, `p2_toggle_camera`) yang dapat dibaca lewat `Input.is_action_pressed()`.

- [ ] **Step 1: Modifikasi project.godot untuk menambahkan Input Map**

Ubah file `project.godot` untuk menambahkan definisi input map dasar untuk Keyboard Player 1 (WASD + Space/E/V) dan Player 2 (IJKL + Enter/O/U).

```ini
[input]

p1_move_forward={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":87,"key_label":0,"unicode":0,"echo":false,"script":null)
]
}
p1_move_back={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":83,"key_label":0,"unicode":0,"echo":false,"script":null)
]
}
p1_move_left={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":65,"key_label":0,"unicode":0,"echo":false,"script":null)
]
}
p1_move_right={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":68,"key_label":0,"unicode":0,"echo":false,"script":null)
]
}
p1_interact={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":69,"key_label":0,"unicode":0,"echo":false,"script":null)
]
}
p1_toggle_camera={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":86,"key_label":0,"unicode":0,"echo":false,"script":null)
]
}
p2_move_forward={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":73,"key_label":0,"unicode":0,"echo":false,"script":null)
]
}
p2_move_back={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":75,"key_label":0,"unicode":0,"echo":false,"script":null)
]
}
p2_move_left={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":74,"key_label":0,"unicode":0,"echo":false,"script":null)
]
}
p2_move_right={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":76,"key_label":0,"unicode":0,"echo":false,"script":null)
]
}
p2_interact={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":79,"key_label":0,"unicode":0,"echo":false,"script":null)
]
}
p2_toggle_camera={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":85,"key_label":0,"unicode":0,"echo":false,"script":null)
]
}
```

- [ ] **Step 2: Jalankan verifikasi pembacaan file project.godot**

Pastikan file `project.godot` tersimpan dengan benar dan sintaksisnya tidak rusak.

- [ ] **Step 3: Commit konfigurasi**

```bash
git add project.godot
git commit -m "config: setup split-screen input mapping for P1 and P2"
```

---

### Task 2: Create Base Player Scene & Movement Script

**Files:**
- Create: `scenes/player.tscn`
- Create: `scenes/player.gd`

**Interfaces:**
- Consumes: Input mapping dari Task 1.
- Produces: `CharacterBody3D` player node yang bisa bergerak maju/mundur/kiri/kanan dengan input dinamis bergantung pada `player_id`.

- [ ] **Step 1: Buat script basic player `scenes/player.gd`**

```gdscript
extends CharacterBody3D

@export var player_id: int = 1
@export var speed: float = 5.0
@export var jump_velocity: float = 4.5

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _physics_process(delta: float) -> void:
	# Tambahkan gravitasi
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Dapatkan string input aksi yang dinamis berdasarkan player_id
	var move_forward = "p%d_move_forward" % player_id
	var move_back = "p%d_move_back" % player_id
	var move_left = "p%d_move_left" % player_id
	var move_right = "p%d_move_right" % player_id

	# Baca input vector
	var input_dir := Vector2.ZERO
	if Input.is_action_pressed(move_left):
		input_dir.x -= 1.0
	if Input.is_action_pressed(move_right):
		input_dir.x += 1.0
	if Input.is_action_pressed(move_forward):
		input_dir.y -= 1.0
	if Input.is_action_pressed(move_back):
		input_dir.y += 1.0

	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()
```

- [ ] **Step 2: Buat scene `scenes/player.tscn`**

Buat file scene player dengan representasi Mesh sementara (Capsule) dan CollisionShape3D.

```text
[gd_scene load_steps=4 format=3 uid="uid://cplayer123"]

[ext_resource type="Script" path="res://scenes/player.gd" id="1_script"]

[sub_resource type="CapsuleShape3D" id="CapsuleShape3D_1"]
radius = 0.5
height = 2.0

[sub_resource type="CapsuleMesh" id="CapsuleMesh_1"]
radius = 0.5
height = 2.0

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
```

- [ ] **Step 3: Commit scenes player**

```bash
git add scenes/player.gd scenes/player.tscn
git commit -m "feat: implement basic player scene and input-dynamic movement"
```

---

### Task 3: Setup Viewport Split-Screen Scene

**Files:**
- Create: `scenes/main.tscn`
- Create: `scenes/main.gd`
- Create: `scenes/map.tscn`

**Interfaces:**
- Consumes: Player scene dari Task 2.
- Produces: Tampilan split screen 2 viewport berisi world 3D dasar (Floor mesh & 2 player).

- [ ] **Step 1: Buat prototype map sederhana `scenes/map.tscn`**

```text
[gd_scene load_steps=4 format=3 uid="uid://cmap123"]

[sub_resource type="BoxShape3D" id="BoxShape3D_floor"]
size = Vector3(50, 1, 50)

[sub_resource type="BoxMesh" id="BoxMesh_floor"]
size = Vector3(50, 1, 50)

[sub_resource type="Environment" id="Environment_1"]
background_mode = 1
background_color = Color(0.2, 0.2, 0.2, 1.0)
ambient_light_color = Color(0.8, 0.8, 0.8, 1.0)

[node name="Map" type="Node3D"]

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("Environment_1")

[node name="DirectionalLight3D" type="DirectionalLight3D" parent="."]
transform = Transform3D(0.866025, -0.353553, 0.353553, 0, 0.707107, 0.707107, -0.5, -0.612372, 0.612372, 0, 10, 0)

[node name="StaticBody3D_Floor" type="StaticBody3D" parent="."]

[node name="CollisionShape3D" type="CollisionShape3D" parent="StaticBody3D_Floor"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.5, 0)
shape = SubResource("BoxShape3D_floor")

[node name="MeshInstance3D" type="MeshInstance3D" parent="StaticBody3D_Floor"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.5, 0)
mesh = SubResource("BoxMesh_floor")
```

- [ ] **Step 2: Buat script `scenes/main.gd` untuk inisialisasi split screen**

```gdscript
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
```

- [ ] **Step 3: Buat scene `scenes/main.tscn`**

```text
[gd_scene load_steps=3 format=3 uid="uid://cmain123"]

[ext_resource type="Script" path="res://scenes/main.gd" id="1_main_script"]
[ext_resource type="PackedScene" uid="uid://cmap123" path="res://scenes/map.tscn" id="2_map_scene"]

[node name="Main" type="Node"]
script = ExtResource("1_main_script")

[node name="GridContainer" type="GridContainer" parent="."]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme_override_constants/h_separation = 4
columns = 2

[node name="ViewportContainer1" type="SubViewportContainer" parent="GridContainer"]
layout_mode = 2
size_flags_horizontal = 3
size_flags_vertical = 3
stretch = true

[node name="Viewport1" type="SubViewport" parent="GridContainer/ViewportContainer1"]
handle_input_locally = false
size = Vector2i(574, 648)
render_target_update_mode = 4

[node name="Map" parent="GridContainer/ViewportContainer1/Viewport1" instance=ExtResource("2_map_scene")]

[node name="Camera3D" type="Camera3D" parent="GridContainer/ViewportContainer1/Viewport1"]

[node name="ViewportContainer2" type="SubViewportContainer" parent="GridContainer"]
layout_mode = 2
size_flags_horizontal = 3
size_flags_vertical = 3
stretch = true

[node name="Viewport2" type="SubViewport" parent="GridContainer/ViewportContainer2"]
handle_input_locally = false
size = Vector2i(574, 648)
render_target_update_mode = 4

[node name="Camera3D" type="Camera3D" parent="GridContainer/ViewportContainer2"]
```

- [ ] **Step 4: Atur main scene di project.godot**

```ini
[application]
run/main_scene="res://scenes/main.tscn"
```

- [ ] **Step 5: Commit main scenes**

```bash
git add scenes/main.tscn scenes/main.gd scenes/map.tscn
git commit -m "feat: add split-screen viewports, world sharing, and player spawning"
```
