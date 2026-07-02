extends CharacterBody3D

@export var speed: float = 5.0
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.003

@export var current_prop_name: String = "":
	set(val):
		current_prop_name = val
		_on_prop_name_changed(val)

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
		
		# Instantiate UI HUD
		var ui = preload("res://scenes/ui.tscn").instantiate()
		add_child(ui)
		ui.setup_ui($PropTransformer)
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
	# Cari objek temp sebelumnya dan hapus jika ada
	for child in get_children():
		if child.name.begins_with("TempProp_"):
			child.queue_free()
			
	if prop_name == "":
		# Kembalikan ke wujud capsule asli
		$MeshInstance3D.visible = true
		$CollisionShape3D.disabled = false
		return
		
	# Sembunyikan mesh capsule asli
	$MeshInstance3D.visible = false
	
	# Cari data objek prop yang sesuai di PropTransformer (client mengambil dari dictionary catalog)
	var transformer = $PropTransformer
	if transformer and transformer.scanned_props.has(prop_name):
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
