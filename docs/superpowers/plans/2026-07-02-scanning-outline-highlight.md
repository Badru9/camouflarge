# Scanning Outline Highlight Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Menambahkan efek visual *highlight* (sorotan warna transparan) pada objek 3D ketika didekati dan ditunjuk oleh pemain Prop menggunakan `material_overlay` bawaan Godot 4.

**Architecture:** Modifikasi `prop_transformer.gd` untuk mendeteksi perubahan target raycast. Saat mendeteksi target valid baru, komponen akan memuat material hologram kuning transparan dan memasangnya ke properti `material_overlay` dari `MeshInstance3D` milik objek tersebut. Saat pandangan beralih, overlay dibersihkan kembali ke `null`.

**Tech Stack:** Godot Engine 4.7, GDScript, StandardMaterial3D (material_overlay).

## Global Constraints

- Proyek berjalan pada Godot 4.7.
- Seluruh script diletakkan di bawah folder yang telah ditentukan.

---

### Task 1: Implement Dynamic Highlight Overlay

**Files:**
- Modify: `components/prop_transformer.gd`

**Interfaces:**
- Produces: Logika otomatis untuk memasang/melepas highlight material pada mesh objek target ketika disorot RayCast3D.

- [ ] **Step 1: Modifikasi `components/prop_transformer.gd` untuk menambahkan logika highlight**

Buka `components/prop_transformer.gd` dan tambahkan instansiasi material highlight di `_ready()` serta kelola target sorotan pada `_physics_process()`.

```gdscript
extends Node3D

signal scan_started
signal scan_progressed(percent: float)
signal scan_completed(prop_name: String)
signal scan_cancelled

@export var scan_range: float = 5.0
@export var scan_duration: float = 1.5

var scanned_props: Dictionary = {} 
var current_scan_target: Node3D = null
var scan_timer: float = 0.0
var is_scanning: bool = false

# Menyimpan referensi mesh yang sedang di-highlight
var current_highlighted_mesh: MeshInstance3D = null
var highlight_material: StandardMaterial3D

@onready var raycast: RayCast3D = $"../CameraPivot/RayCast3D"

func _ready() -> void:
	# Raycast dikonfigurasi mengarah ke depan (Z negatif)
	raycast.target_position = Vector3(0, 0, -scan_range)
	raycast.enabled = true
	
	# Buat material highlight (kuning hologram semi-transparan)
	highlight_material = StandardMaterial3D.new()
	highlight_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	highlight_material.albedo_color = Color(1.0, 0.9, 0.1, 0.3) # Kuning transparan
	highlight_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
		
	var target_mesh: MeshInstance3D = null
	var valid_collider: Node3D = null
	
	# Cek deteksi tabrakan raycast ke depan
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		if collider and collider.is_in_group("InteractableProps"):
			valid_collider = collider
			target_mesh = collider.get_node_or_null("MeshInstance3D")
			
	# Update highlight visual
	_handle_highlight(target_mesh)
			
	if valid_collider:
		if Input.is_key_pressed(KEY_F): # Tahan tombol F untuk scan
			if not is_scanning:
				_start_scan(valid_collider)
			else:
				_update_scan(delta)
			return
				
	# Batalkan scan jika tidak menekan F atau tidak menabrak target
	if is_scanning:
		_cancel_scan()

func _handle_highlight(new_mesh: MeshInstance3D) -> void:
	if current_highlighted_mesh == new_mesh:
		return
		
	# Bersihkan highlight lama jika ada
	if current_highlighted_mesh and is_instance_valid(current_highlighted_mesh):
		current_highlighted_mesh.material_overlay = null
		
	# Terapkan highlight baru
	if new_mesh:
		new_mesh.material_overlay = highlight_material
		
	current_highlighted_mesh = new_mesh

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
	
# Bersihkan highlight saat node dihancurkan/keluar scene
func _exit_tree() -> void:
	if current_highlighted_mesh and is_instance_valid(current_highlighted_mesh):
		current_highlighted_mesh.material_overlay = null
```

- [ ] **Step 2: Commit perubahan highlight**

```bash
git add components/prop_transformer.gd
git commit -m "feat: add real-time material overlay highlight on raycast targets"
```
