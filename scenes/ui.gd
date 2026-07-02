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
		# Tambahkan node agar tidak kosong
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
