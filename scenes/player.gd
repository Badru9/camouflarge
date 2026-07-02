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

	# Rotasi horizontal sederhana dengan keyboard
	var rotation_dir := 0.0
	if player_id == 1:
		if Input.is_key_pressed(KEY_Q):
			rotation_dir += 1.0
		if Input.is_key_pressed(KEY_R):
			rotation_dir -= 1.0
	elif player_id == 2:
		if Input.is_key_pressed(KEY_Y):
			rotation_dir += 1.0
		if Input.is_key_pressed(KEY_P):
			rotation_dir -= 1.0
	
	rotate_y(rotation_dir * 2.5 * delta)

	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()
