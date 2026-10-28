extends Node3D
## Offline low-poly survival prototype. World art is generated from primitive meshes.

const SAVE_PATH := "user://dead_zone_save.json"
const WORLD_SIZE := 90.0
const WALK_SPEED := 4.8
const SPRINT_SPEED := 7.4
const LOOK_SENS := 0.004

var player: CharacterBody3D
var camera: Camera3D
var status_label: Label
var hint_label: Label
var inventory_panel: PanelContainer
var inventory_label: Label
var joystick_center := Vector2.ZERO
var joystick_vector := Vector2.ZERO
var joystick_touch := -1
var look_touch := -1
var move_input := Vector2.ZERO
var health := 100.0
var stamina := 100.0
var wood := 0
var stone := 0
var scrap := 0
var food := 2
var medkits := 1
var mutants: Array[CharacterBody3D] = []
var mutant_hp: Dictionary = {}
var pickups: Array[Node3D] = []
var elapsed := 0.0
var attack_timer := 0.0
var inventory_open := false
var is_dead := false
var random := RandomNumberGenerator.new()

func _ready() -> void:
	random.randomize()
	_setup_input()
	_setup_environment()
	_build_world()
	_create_player()
	_create_hud()
	_load_game()
	_update_hud()

func _setup_input() -> void:
	for action in ["move_left", "move_right", "move_forward", "move_back"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	var keys := {"move_left": KEY_A, "move_right": KEY_D, "move_forward": KEY_W, "move_back": KEY_S}
	for action in keys:
		var event := InputEventKey.new()
		event.physical_keycode = keys[action]
		InputMap.action_add_event(action, event)

func _material(color: Color, roughness := 0.9, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m

func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.07, 0.13, 0.17)
	sky_mat.sky_horizon_color = Color(0.55, 0.48, 0.36)
	sky_mat.ground_bottom_color = Color(0.06, 0.07, 0.05)
	sky_mat.ground_horizon_color = Color(0.29, 0.28, 0.20)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.50, 0.56, 0.47)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.44, 0.45, 0.36)
	env.fog_density = 0.007
	env.fog_sky_affect = 0.5
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -28, 0)
	sun.light_color = Color(1.0, 0.83, 0.64)
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	add_child(sun)

func _add_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, collision := false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = mat
	visual.position = pos
	parent.add_child(visual)
	if collision:
		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		col.shape = shape
		body.position = pos
		body.add_child(col)
		parent.add_child(body)
	return visual

func _add_cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, mat: Material, sides := 7) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = mat
	visual.position = pos
	parent.add_child(visual)
	return visual

func _build_world() -> void:
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	var plane := MeshInstance3D.new()
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = Vector2(WORLD_SIZE * 2, WORLD_SIZE * 2)
	plane.mesh = plane_mesh
	plane.material_override = _material(Color(0.22, 0.26, 0.17))
	ground.add_child(plane)
	var floor_col := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(WORLD_SIZE * 2, 0.5, WORLD_SIZE * 2)
	floor_col.shape = floor_shape
	floor_col.position.y = -0.25
	ground.add_child(floor_col)
	add_child(ground)

	var dirt := _material(Color(0.34, 0.30, 0.21))
	var bark := _material(Color(0.24, 0.16, 0.10))
	var pine1 := _material(Color(0.10, 0.20, 0.14))
	var pine2 := _material(Color(0.18, 0.27, 0.17))
	var stone_mat := _material(Color(0.34, 0.35, 0.31))
	var rust := _material(Color(0.32, 0.21, 0.13), 0.8, 0.15)
	var concrete := _material(Color(0.34, 0.33, 0.28))
	var ochre := _material(Color(0.64, 0.45, 0.18))
	for i in range(18):
		_add_box(self, Vector3(4.2, 0.03, 4.4), Vector3(0, 0.01, -40.0 + i * 5.0), dirt)
	for i in range(75):
		var x: float = random.randf_range(-WORLD_SIZE + 5, WORLD_SIZE - 5)
		var z: float = random.randf_range(-WORLD_SIZE + 5, WORLD_SIZE - 5)
		if Vector2(x, z).length() < 12.0 or (absf(x) < 3.4 and z > -45 and z < 45):
			continue
		if random.randf() < 0.72:
			var h: float = random.randf_range(2.8, 5.6)
			_add_cylinder(self, 0.17, h * 0.45, Vector3(x, h * 0.22, z), bark, 6)
			var crown := _add_cylinder(self, random.randf_range(0.85, 1.35), h * 0.62, Vector3(x, h * 0.65, z), pine1 if random.randf() < 0.5 else pine2, 6)
			crown.mesh.top_radius = 0.04
		else:
			var rock := _add_box(self, Vector3(random.randf_range(0.6, 1.4), random.randf_range(0.35, 0.8), random.randf_range(0.6, 1.4)), Vector3(x, 0.2, z), stone_mat)
			rock.rotation.y = random.randf_range(0.0, TAU)
	# Abandoned checkpoint and salvage yard.
	_add_box(self, Vector3(12, 0.25, 0.35), Vector3(0, 0.7, -10), rust, true)
	_add_box(self, Vector3(0.35, 1.4, 18), Vector3(-6, 0.7, -1), rust, true)
	_add_box(self, Vector3(0.35, 1.4, 18), Vector3(6, 0.7, -1), rust, true)
	_add_box(self, Vector3(5, 3.5, 0.3), Vector3(-3.5, 1.75, 7), concrete, true)
	_add_box(self, Vector3(5, 3.5, 0.3), Vector3(3.5, 1.75, 7), concrete, true)
	_add_box(self, Vector3(12, 0.35, 0.35), Vector3(0, 3.55, 7), rust, true)
	_add_box(self, Vector3(2.3, 2.4, 0.22), Vector3(0, 1.2, 7), rust, true)
	_add_box(self, Vector3(3, 1.5, 1.8), Vector3(-9, 0.75, 0), rust, true)
	_add_box(self, Vector3(3, 1.5, 1.8), Vector3(9, 0.75, -4), ochre, true)
	for i in range(9):
		_add_cylinder(self, 0.08, 1.4, Vector3(-9.0 + i * 2.25, 0.7, -10), ochre, 5)
	for i in range(16):
		var p := Vector3(random.randf_range(-18, 18), 0.35, random.randf_range(-20, 18))
		if Vector2(p.x, p.z).length() < 4.0:
			continue
		_add_box(self, Vector3(0.75, 0.7, 0.75), p, rust)
		_add_pickup(p + Vector3(0, 0.7, 0), ["wood", "stone", "scrap", "food"][random.randi_range(0, 3)])
	for i in range(6):
		var angle: float = TAU * float(i) / 6.0
		_spawn_mutant(Vector3(cos(angle) * random.randf_range(17, 25), 0, sin(angle) * random.randf_range(17, 25)))

func _create_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0, 0.15, 18)
	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.36
	capsule.height = 1.7
	col.shape = capsule
	col.position.y = 0.85
	player.add_child(col)
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.34
	body_mesh.height = 1.45
	body.mesh = body_mesh
	body.material_override = _material(Color(0.23, 0.29, 0.25))
	body.position.y = 0.85
	player.add_child(body)
	camera = Camera3D.new()
	camera.position = Vector3(0, 1.5, 0)
	camera.fov = 78
	player.add_child(camera)
	add_child(player)

func _spawn_mutant(pos: Vector3) -> void:
	var enemy := CharacterBody3D.new()
	enemy.name = "Mutant"
	enemy.position = pos
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.42
	shape.height = 1.75
	col.shape = shape
	col.position.y = 0.88
	enemy.add_child(col)
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.42
	body_mesh.height = 1.6
	body.mesh = body_mesh
	body.material_override = _material(Color(0.25, 0.31, 0.20))
	body.position.y = 0.88
	enemy.add_child(body)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.27
	head_mesh.height = 0.48
	head.mesh = head_mesh
	head.material_override = _material(Color(0.38, 0.35, 0.24))
	head.position = Vector3(0, 1.78, -0.04)
	enemy.add_child(head)
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.05
		eye.mesh = eye_mesh
		eye.material_override = _material(Color(0.88, 0.20, 0.07), 0.25)
		eye.position = Vector3(side * 0.11, 1.8, -0.28)
		enemy.add_child(eye)
	add_child(enemy)
	mutants.append(enemy)

func _add_pickup(pos: Vector3, kind: String) -> void:
	var pickup := Node3D.new()
	pickup.position = pos
	pickup.set_meta("kind", kind)
	var color := Color(0.55, 0.38, 0.18)
	match kind:
		"stone": color = Color(0.48, 0.5, 0.47)
		"scrap": color = Color(0.55, 0.57, 0.52)
		"food": color = Color(0.63, 0.39, 0.19)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.28, 0.28, 0.28)
	mesh.mesh = box
	mesh.material_override = _material(color, 0.65, 0.15)
	pickup.add_child(mesh)
	add_child(pickup)
	pickups.append(pickup)

func _create_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var top := PanelContainer.new()
	top.position = Vector2(16, 16)
	top.size = Vector2(350, 96)
	top.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.04, 0.035, 0.86)))
	root.add_child(top)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	top.add_child(column)
	var title := Label.new()
	title.text = "DEAD ZONE  /  SURVIVAL"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.88, 0.75, 0.47))
	column.add_child(title)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 14)
	column.add_child(status_label)
	hint_label = Label.new()
	hint_label.text = "Explore • Collect • Stay alive"
	hint_label.position = Vector2(18, 120)
	hint_label.add_theme_font_size_override("font_size", 15)
	hint_label.add_theme_color_override("font_color", Color(0.88, 0.87, 0.77))
	root.add_child(hint_label)
	var cross := Label.new()
	cross.text = "+"
	cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	cross.position = Vector2(-7, -16)
	cross.add_theme_font_size_override("font_size", 24)
	cross.add_theme_color_override("font_color", Color(0.94, 0.89, 0.7, 0.8))
	root.add_child(cross)
	_add_button(root, "DASH", Vector2(-140, -120), Vector2(110, 66), _dash)
	_add_button(root, "COLLECT", Vector2(-260, -115), Vector2(108, 56), _collect)
	_add_button(root, "BAG", Vector2(-140, -194), Vector2(110, 50), _toggle_inventory)
	_add_button(root, "CRAFT", Vector2(-260, -182), Vector2(108, 50), _craft)
	_add_button(root, "SAVE", Vector2(-140, -252), Vector2(110, 42), _save_game)
	_add_button(root, "EAT", Vector2(-260, -240), Vector2(108, 50), _eat)
	inventory_panel = PanelContainer.new()
	inventory_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	inventory_panel.position = Vector2(-220, -145)
	inventory_panel.size = Vector2(440, 290)
	inventory_panel.visible = false
	inventory_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.04, 0.035, 0.96)))
	root.add_child(inventory_panel)
	var inv_column := VBoxContainer.new()
	inv_column.add_theme_constant_override("separation", 9)
	inventory_panel.add_child(inv_column)
	var inv_title := Label.new()
	inv_title.text = "FIELD INVENTORY"
	inv_title.add_theme_font_size_override("font_size", 23)
	inv_title.add_theme_color_override("font_color", Color(0.88, 0.75, 0.47))
	inv_column.add_child(inv_title)
	inventory_label = Label.new()
	inventory_label.add_theme_font_size_override("font_size", 17)
	inv_column.add_child(inventory_label)
	var close := Button.new()
	close.text = "CLOSE BAG"
	close.custom_minimum_size = Vector2(0, 42)
	close.pressed.connect(_toggle_inventory)
	inv_column.add_child(close)
	var help := Label.new()
	help.text = "CRAFT: 3 wood + 2 scrap → medkit"
	help.add_theme_font_size_override("font_size", 14)
	inv_column.add_child(help)
	var dead_label := Label.new()
	dead_label.name = "DeadText"
	dead_label.text = "YOU ARE DOWN\nLoad your last save"
	dead_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	dead_label.position = Vector2(-150, -55)
	dead_label.add_theme_font_size_override("font_size", 25)
	dead_label.add_theme_color_override("font_color", Color(0.9, 0.25, 0.15))
	dead_label.visible = false
	root.add_child(dead_label)

func _panel_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.48, 0.43, 0.3, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _add_button(parent: Control, text_value: String, offset: Vector2, size: Vector2, callback: Callable) -> void:
	var button := Button.new()
	button.text = text_value
	button.size = size
	button.custom_minimum_size = size
	button.anchor_left = 1.0
	button.anchor_right = 1.0
	button.anchor_top = 1.0
	button.anchor_bottom = 1.0
	button.position = offset
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color(0.93, 0.91, 0.82))
	button.add_theme_stylebox_override("normal", _panel_style(Color(0.055, 0.075, 0.06, 0.84)))
	button.add_theme_stylebox_override("hover", _panel_style(Color(0.17, 0.19, 0.12, 0.94)))
	button.pressed.connect(callback)
	parent.add_child(button)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE, KEY_I: _toggle_inventory()
			KEY_E: _collect()
			KEY_C: _craft()
			KEY_H: _eat()
			KEY_F5: _save_game()
			KEY_SHIFT: _dash()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not inventory_open:
		player.rotate_y(-event.relative.x * 0.0025)
		camera.rotate_x(-event.relative.y * 0.0025)
		camera.rotation.x = clampf(camera.rotation.x, -1.2, 1.2)
	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.x < get_viewport().get_visible_rect().size.x * 0.46 and joystick_touch == -1:
				joystick_touch = event.index
				joystick_center = event.position
				joystick_vector = Vector2.ZERO
			elif look_touch == -1 and not inventory_open:
				look_touch = event.index
		else:
			if event.index == joystick_touch:
				joystick_touch = -1
				joystick_vector = Vector2.ZERO
			if event.index == look_touch:
				look_touch = -1
	if event is InputEventScreenDrag:
		if event.index == joystick_touch:
			joystick_vector = (event.position - joystick_center).limit_length(70.0) / 70.0
		elif event.index == look_touch and not inventory_open:
			player.rotate_y(-event.relative.x * LOOK_SENS)
			camera.rotate_x(-event.relative.y * LOOK_SENS)
			camera.rotation.x = clampf(camera.rotation.x, -1.2, 1.2)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	elapsed += delta
	attack_timer = maxf(0.0, attack_timer - delta)
	move_input = joystick_vector if joystick_touch != -1 else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish: Vector3 = (player.transform.basis * Vector3(move_input.x, 0, move_input.y)).normalized()
	var sprinting: bool = Input.is_key_pressed(KEY_SHIFT) and stamina > 1.0
	var speed: float = SPRINT_SPEED if sprinting else WALK_SPEED
	if sprinting and wish.length() > 0.1:
		stamina = maxf(0.0, stamina - 22.0 * delta)
	else:
		stamina = minf(100.0, stamina + 13.0 * delta)
	player.velocity.x = wish.x * speed
	player.velocity.z = wish.z * speed
	player.velocity.y = -0.4 if player.is_on_floor() else player.velocity.y - 18.0 * delta
	player.move_and_slide()
	player.position.x = clampf(player.position.x, -WORLD_SIZE + 2, WORLD_SIZE - 2)
	player.position.z = clampf(player.position.z, -WORLD_SIZE + 2, WORLD_SIZE - 2)
	_update_mutants(delta)
	_update_hud()

func _update_mutants(delta: float) -> void:
	for enemy: CharacterBody3D in mutants.duplicate():
		if not is_instance_valid(enemy):
			mutants.erase(enemy)
			continue
		var distance_to_player: float = enemy.global_position.distance_to(player.global_position)
		if distance_to_player < 24.0 and distance_to_player > 1.5:
			var direction: Vector3 = player.global_position - enemy.global_position
			direction.y = 0.0
			direction = direction.normalized()
			enemy.look_at(Vector3(player.global_position.x, enemy.global_position.y, player.global_position.z), Vector3.UP)
			enemy.velocity.x = direction.x * 1.75
			enemy.velocity.z = direction.z * 1.75
			enemy.velocity.y = -0.4
			enemy.move_and_slide()
		elif distance_to_player <= 1.5 and attack_timer <= 0.0:
			health -= 7.0
			attack_timer = 0.8
			hint_label.text = "A mutant is too close — DASH away!"
			if health <= 0.0:
				_die()

func _dash() -> void:
	if is_dead or stamina < 18.0:
		hint_label.text = "Too tired to dash"
		return
	var direction: Vector3 = -camera.global_transform.basis.z
	direction.y = 0.0
	direction = direction.normalized()
	player.velocity.x = direction.x * 12.0
	player.velocity.z = direction.z * 12.0
	stamina = maxf(0.0, stamina - 18.0)
	hint_label.text = "Quick dash!"

func _collect() -> void:
	if is_dead:
		return
	var nearest: Node3D = null
	var nearest_distance: float = 3.6
	for item: Node3D in pickups:
		if not is_instance_valid(item):
			continue
		var d: float = player.global_position.distance_to(item.global_position)
		if d < nearest_distance:
			nearest_distance = d
			nearest = item
	if nearest == null:
		hint_label.text = "No supplies close by — explore the outpost"
		return
	var kind: String = str(nearest.get_meta("kind", "wood"))
	match kind:
		"wood": wood += 2
		"stone": stone += 2
		"scrap": scrap += 1
		"food": food += 1
	pickups.erase(nearest)
	nearest.queue_free()
	hint_label.text = "Collected: " + kind.to_upper()
	_update_hud()

func _craft() -> void:
	if wood >= 3 and scrap >= 2:
		wood -= 3
		scrap -= 2
		medkits += 1
		hint_label.text = "Crafted a field medkit"
	else:
		hint_label.text = "Need 3 wood + 2 scrap to craft a medkit"
	_update_hud()

func _eat() -> void:
	if food > 0 and health < 100.0:
		food -= 1
		health = minf(100.0, health + 18.0)
		hint_label.text = "Food eaten • health restored"
	elif medkits > 0 and health < 100.0:
		medkits -= 1
		health = minf(100.0, health + 42.0)
		hint_label.text = "Medkit used • health restored"
	else:
		hint_label.text = "No food or medkits needed right now"
	_update_hud()

func _toggle_inventory() -> void:
	inventory_open = not inventory_open
	inventory_panel.visible = inventory_open
	_update_hud()

func _update_hud() -> void:
	if not is_instance_valid(status_label):
		return
	status_label.text = "HP %03d   STA %03d   FOOD %02d" % [int(health), int(stamina), food]
	inventory_label.text = "WOOD      %d\nSTONE     %d\nSCRAP     %d\nFOOD      %d\nMEDKITS   %d\n\nMutants nearby: %d" % [wood, stone, scrap, food, medkits, mutants.size()]
	if is_dead:
		status_label.text = "SIGNAL LOST  •  LOAD SAVE"

func _die() -> void:
	is_dead = true
	var overlay := get_node_or_null("CanvasLayer/Control/DeadText")
	if overlay:
		overlay.visible = true
	hint_label.text = "You are down — load your last save"

func _save_game() -> void:
	if not is_instance_valid(player):
		return
	var data := {"position": [player.position.x, player.position.y, player.position.z], "health": health, "stamina": stamina, "wood": wood, "stone": stone, "scrap": scrap, "food": food, "medkits": medkits, "elapsed": elapsed}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		hint_label.text = "Saved on this device"
	else:
		hint_label.text = "Save failed"
	_update_hud()

func _load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	var pos: Array = data.get("position", [0, 0.15, 18])
	player.position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	health = float(data.get("health", 100.0))
	stamina = float(data.get("stamina", 100.0))
	wood = int(data.get("wood", 0))
	stone = int(data.get("stone", 0))
	scrap = int(data.get("scrap", 0))
	food = int(data.get("food", 2))
	medkits = int(data.get("medkits", 1))
	elapsed = float(data.get("elapsed", 0.0))
	hint_label.text = "Local save restored"

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_game()
