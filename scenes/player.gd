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
