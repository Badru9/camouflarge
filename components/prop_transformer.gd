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

@onready var raycast: RayCast3D = $"../CameraPivot/RayCast3D"

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
