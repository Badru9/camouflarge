# Prop Transformation & Radial UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mengimplementasikan mekanik scanning objek 3D di peta, menu pemilihan radial (Radial Menu UI) saat menekan tombol `Tab`, dan sinkronisasi wujud baru via jaringan (Server-Client).

**Architecture:** Pemain Prop menggunakan RayCast3D untuk men-scan objek ber-group `"InteractableProps"`. Setelah di-scan, data disimpan lokal. Menekan tombol `Tab` memunculkan UI custom melingkar (`Control` node) untuk memilih wujud. Memilih sektor lingkaran memicu RPC ke server untuk mengganti model mesh dan shape collision player, yang disebarkan ke semua client via `MultiplayerSynchronizer`.

**Tech Stack:** Godot Engine 4.7, GDScript, Control UI, high-level RPC.

## Global Constraints

- Proyek berjalan pada Godot 4.7.
- Seluruh script logic diletakkan di bawah folder `components/`, `common/`, atau `scenes/` sesuai rancangan spesifikasi.
- Semua properti mesh/collision dinamis harus disinkronkan secara andal di server dan client.

---

### Task 1: Scanning Mechanic & Scanned Catalog

**Files:**
- Create: `components/prop_transformer.gd`
- Modify: `scenes/player.tscn`
- Modify: `scenes/player.gd`

**Interfaces:**
- Produces: Komponen `PropTransformer` yang menempel pada `Player` dan mendeteksi target scan serta mencatat wujud yang sukses di-scan.

- [ ] **Step 1: Buat script komponen `components/prop_transformer.gd`**

```gdscript
extends Node3D

signal scan_started
signal scan_progressed(percent: float)
signal scan_completed(prop_name: String)
signal scan_cancelled

@export var scan_range: float = 5.0
@export var scan_duration: float = 1.5

var scanned_props: Dictionary = {} # Format: { prop_name: { "mesh_path": String, "shape_data": CollisionShape3D } }
var current_scan_target: Node3D = null
var scan_timer: float = 0.0
var is_scanning: bool = false

@onready var raycast: RayCast3D = $RayCast3D

func _ready() -> void:
	# Raycast dikonfigurasi mengarah ke depan (Z negatif)
	raycast.target_position = Vector3(0, 0, -scan_range)
	raycast.enabled = true

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
		
	# Deteksi tabrakan raycast ke depan
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		if collider and collider.is_in_group("InteractableProps"):
			if Input.is_key_pressed(KEY_F): # Tahan tombol F untuk scan
				if not is_scanning:
					_start_scan(collider)
				else:
					_update_scan(delta)
				return
				
	# Batalkan scan jika tidak menekan F atau raycast tidak menabrak target
	if is_scanning:
		_cancel_scan()

func _start_scan(target: Node3D) -> void:
	is_scanning = true
	current_scan_target = target
	scan_timer = 0.0
	scan_started.emit()

func _update_scan(delta: float) -> void:
	scan_timer += delta
	var progress = clamp(scan_timer / scan_duration, 0.0, 1.0)
	scan_progressed.emit(progress)
	
	if progress >= 1.0:
		_complete_scan()

func _complete_scan() -> void:
	is_scanning = false
	var prop_name = current_scan_target.name
	
	# Ambil data mesh dan collision dari target
	var mesh_instance = current_scan_target.get_node_or_null("MeshInstance3D")
	var collision_shape = current_scan_target.get_node_or_null("CollisionShape3D")
	
	if mesh_instance and collision_shape:
		scanned_props[prop_name] = {
			"mesh": mesh_instance.mesh,
			"shape": collision_shape.shape,
			"height_offset": collision_shape.position.y
		}
		scan_completed.emit(prop_name)
		
	current_scan_target = null

func _cancel_scan() -> void:
	is_scanning = false
	current_scan_target = null
	scan_timer = 0.0
	scan_cancelled.emit()
```

- [ ] **Step 2: Pasang komponen `PropTransformer` ke `scenes/player.tscn`**

Modifikasi file `scenes/player.tscn` untuk menyisipkan node `PropTransformer` di bawah root Player, lengkap dengan node `RayCast3D` sebagai anak dari `CameraPivot`.

```text
[node name="PropTransformer" type="Node3D" parent="."]
script = ExtResource("2_prop_transformer")

[node name="RayCast3D" type="RayCast3D" parent="CameraPivot"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0)
```

(Sertakan ekstensi script baru `2_prop_transformer` di bagian atas file `.tscn` dengan path `res://components/prop_transformer.gd`).

- [ ] **Step 3: Hubungkan tombol dan kontrol di `scenes/player.gd`**

Pastikan `PropTransformer` hanya aktif untuk pemain dengan role `PROP` dan multiplayer authority.

- [ ] **Step 4: Commit konfigurasi scanning**

```bash
git add components/prop_transformer.gd scenes/player.tscn scenes/player.gd
git commit -m "feat: implement PropTransformer component for prop scanning logic"
```

---

### Task 2: Create HUD & Radial Menu UI

**Files:**
- Create: `scenes/ui.tscn`
- Create: `scenes/ui.gd`
- Modify: `scenes/player.tscn`
- Modify: `scenes/player.gd`

**Interfaces:**
- Consumes: Katalog `scanned_props` dari `PropTransformer` (Task 1).
- Produces: HUD CanvasLayer dengan *scanning progress indicator* dan *radial selection overlay*.

- [ ] **Step 1: Buat script `scenes/ui.gd` untuk mengontrol Radial UI**

```gdscript
extends CanvasLayer

@onready var scan_label: Label = $HUD/ScanLabel
@onready var scan_progress: ProgressBar = $HUD/ScanProgress
@onready var radial_menu: Control = $RadialMenu
@onready var radial_items: Control = $RadialMenu/Items

var prop_transformer = null
var is_menu_open: bool = false
var hovered_index: int = -1

func _ready() -> void:
	radial_menu.visible = false
	scan_progress.visible = false
	scan_label.visible = false

func setup_ui(transformer) -> void:
	prop_transformer = transformer
	prop_transformer.scan_started.connect(_on_scan_started)
	prop_transformer.scan_progressed.connect(_on_scan_progressed)
	prop_transformer.scan_completed.connect(_on_scan_completed)
	prop_transformer.scan_cancelled.connect(_on_scan_cancelled)

func _process(_delta: float) -> void:
	if not prop_transformer:
		return
		
	# Buka menu radial saat tombol Tab ditekan
	if Input.is_key_pressed(KEY_TAB):
		if not is_menu_open:
			_open_radial_menu()
		_update_radial_hover()
	else:
		if is_menu_open:
			_close_radial_menu_and_select()

func _on_scan_started() -> void:
	scan_label.visible = true
	scan_label.text = "Scanning..."
	scan_progress.visible = true
	scan_progress.value = 0.0

func _on_scan_progressed(percent: float) -> void:
	scan_progress.value = percent * 100.0

func _on_scan_completed(prop_name: String) -> void:
	scan_label.text = "Scan Sukses: " + prop_name
	await get_tree().create_timer(1.0).timeout
	if not prop_transformer.is_scanning:
		scan_label.visible = false
		scan_progress.visible = false

func _on_scan_cancelled() -> void:
	scan_label.visible = false
	scan_progress.visible = false

func _open_radial_menu() -> void:
	is_menu_open = true
	radial_menu.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_radial_items()

func _build_radial_items() -> void:
	# Bersihkan item lama
	for child in radial_items.get_children():
		child.queue_free()
		
	var props = prop_transformer.scanned_props.keys()
	if props.size() == 0:
		var label = Label.new()
		label.text = "Belum ada objek yang di-scan"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		radial_items.add_child(label)
		return
		
	var angle_step = 2.0 * PI / props.size()
	for i in range(props.size()):
		var angle = i * angle_step - PI / 2.0
		var pos = Vector2(cos(angle), sin(angle)) * 120.0
		
		var btn = Button.new()
		btn.text = props[i]
		btn.position = pos - Vector2(50, 15)
		btn.size = Vector2(100, 30)
		btn.mouse_filter = Control.MOUSE_FILTER_IGNORE # Deteksi hover dihitung manual
		radial_items.add_child(btn)

func _update_radial_hover() -> void:
	var props = prop_transformer.scanned_props.keys()
	if props.size() == 0:
		hovered_index = -1
		return
		
	var center = get_viewport().get_visible_rect().size / 2.0
	var mouse_pos = get_viewport().get_mouse_position()
	var dir = mouse_pos - center
	
	if dir.length() < 40.0: # Terlalu dekat ke tengah
		hovered_index = -1
		return
		
	var angle = atan2(dir.y, dir.x) + PI/2.0
	if angle < 0:
		angle += 2.0 * PI
		
	var angle_step = 2.0 * PI / props.size()
	hovered_index = int(angle / angle_step) % props.size()
	
	# Beri visual highlight ke tombol yang disorot
	for i in range(radial_items.get_child_count()):
		var child = radial_items.get_child(i)
		if child is Button:
			if i == hovered_index:
				child.modulate = Color(0.2, 0.8, 0.2)
			else:
				child.modulate = Color(1, 1, 1)

func _close_radial_menu_and_select() -> void:
	is_menu_open = false
	radial_menu.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	if hovered_index != -1:
		var props = prop_transformer.scanned_props.keys()
		var selected_prop = props[hovered_index]
		
		# Pemicu fungsi transformasi player
		prop_transformer.get_parent().request_transformation(selected_prop)
	
	hovered_index = -1
```

- [ ] **Step 2: Buat scene CanvasLayer `scenes/ui.tscn`**

Tentukan node structure untuk HUD dan RadialMenu overlay.

```text
[gd_scene load_steps=2 format=3 uid="uid://cui123"]

[ext_resource type="Script" path="res://scenes/ui.gd" id="1_ui_script"]

[node name="UI" type="CanvasLayer"]
script = ExtResource("1_ui_script")

[node name="HUD" type="Control" parent="."]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2

[node name="ScanLabel" type="Label" parent="HUD"]
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -100.0
offset_top = 40.0
offset_right = 100.0
offset_bottom = 63.0
grow_horizontal = 2
grow_vertical = 2
text = "Scanning..."
horizontal_alignment = 1

[node name="ScanProgress" type="ProgressBar" parent="HUD"]
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -100.0
offset_top = 70.0
offset_right = 100.0
offset_bottom = 97.0
grow_horizontal = 2
grow_vertical = 2

[node name="RadialMenu" type="Control" parent="."]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2

[node name="Bg" type="ColorRect" parent="RadialMenu"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
color = Color(0, 0, 0, 0.4)

[node name="Center" type="Control" parent="RadialMenu"]
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
grow_horizontal = 2
grow_vertical = 2

[node name="Items" type="Control" parent="RadialMenu"]
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
grow_horizontal = 2
grow_vertical = 2
```

- [ ] **Step 3: Hubungkan UI ke `scenes/player.tscn` & `scenes/player.gd`**

Instantiate `ui.tscn` di bawah player scene secara lokal jika player tersebut dikontrol oleh multiplayer authority lokal:

```gdscript
# Di dalam scenes/player.gd
func _ready() -> void:
	if is_multiplayer_authority():
		camera.make_current()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
		# Instantiate UI HUD
		var ui = preload("res://scenes/ui.tscn").instantiate()
		add_child(ui)
		ui.setup_ui($PropTransformer)
	else:
		camera.visible = false
```

- [ ] **Step 4: Commit HUD & Radial UI**

```bash
git add scenes/ui.gd scenes/ui.tscn scenes/player.gd
git commit -m "feat: implement HUD scanning progress and circular Radial Menu UI"
```

---

### Task 3: Network Transformation & Shape Sync

**Files:**
- Modify: `scenes/player.gd`
- Modify: `scenes/player.tscn`

**Interfaces:**
- Produces: Sinkronisasi wujud mesh dan collision shape antar client di jaringan via RPC dan variabel tersinkronisasi `current_prop_name`.

- [ ] **Step 1: Hubungkan logika RPC di `scenes/player.gd`**

Tambahkan fungsi RPC untuk mengajukan perubahan bentuk ke server dan menyebarkannya.

```gdscript
# Tambahkan variabel tersinkronisasi di bagian atas player.gd
@export var current_prop_name: String = "":
	set(val):
		current_prop_name = val
		_on_prop_name_changed(val)

# Panggil dari UI klien lokal
func request_transformation(prop_name: String) -> void:
	rpc_id(1, "server_request_transformation", prop_name)

@rpc("any_peer", "reliable")
func server_request_transformation(prop_name: String) -> void:
	if not multiplayer.is_server():
		return
		
	# Set variabel di server agar disinkronkan oleh MultiplayerSynchronizer
	current_prop_name = prop_name

# Menerima update nama prop untuk memperbarui mesh & collision lokal
func _on_prop_name_changed(prop_name: String) -> void:
	if prop_name == "":
		# Kembalikan ke wujud capsule asli
		$MeshInstance3D.visible = true
		$CollisionShape3D.disabled = false
		for child in get_children():
			if child.name.begins_with("TempProp_"):
				child.queue_free()
		return
		
	# Sembunyikan mesh capsule asli
	$MeshInstance3D.visible = false
	
	# Cari data objek prop yang sesuai di PropTransformer (client mengambil dari dictionary catalog)
	var transformer = $PropTransformer
	if transformer and transformer.scanned_props.has(prop_name):
		# Hapus objek temp sebelumnya jika ada
		for child in get_children():
			if child.name.begins_with("TempProp_"):
				child.queue_free()
				
		var prop_data = transformer.scanned_props[prop_name]
		
		# Buat visual mesh baru
		var temp_mesh = MeshInstance3D.new()
		temp_mesh.name = "TempProp_Mesh"
		temp_mesh.mesh = prop_data["mesh"]
		temp_mesh.position = Vector3(0, prop_data["height_offset"], 0)
		add_child(temp_mesh)
		
		# Ganti collision shape agar pas dengan objek baru
		$CollisionShape3D.shape = prop_data["shape"]
		$CollisionShape3D.position = Vector3(0, prop_data["height_offset"], 0)
```

- [ ] **Step 2: Daftarkan `current_prop_name` di `MultiplayerSynchronizer` (`player.tscn`)**

Modifikasi file `scenes/player.tscn` untuk mendaftarkan properti `current_prop_name` agar direplikasi secara otomatis di jaringan oleh `SceneReplicationConfig`.

```text
properties/3/path = NodePath(".:current_prop_name")
properties/3/spawn = true
properties/3/replication_mode = 1
```

- [ ] **Step 3: Commit sinkronisasi wujud**

```bash
git add scenes/player.gd scenes/player.tscn
git commit -m "feat: implement network synchronization for player meshes and shapes"
```
