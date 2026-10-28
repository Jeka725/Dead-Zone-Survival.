extends Node3D
## Dead Zone: Survival — lightweight procedural 3D survival prototype.
## All props are generated from primitives to keep the APK small and offline.
const SAVE_PATH := "user://dead_zone_save.json"
const WORLD_SIZE := 90.0
const WALK_SPEED := 5.2
const SPRINT_SPEED := 7.8
const MOUSE_SENS := 0.0025
var player: CharacterBody3D
var camera: Camera3D
var world_env: WorldEnvironment
var hud: CanvasLayer
var status_label: Label
var hint_label: Label
var inventory_panel: PanelContainer
var inventory_label: Label
var joystick_center := Vector2.ZERO
var joystick_vector := Vector2.ZERO
var joystick_touch := -1
var look_touch := -1
var look_last := Vector2.ZERO
var move_input := Vector2.ZERO
var health := 100.0
var stamina := 100.0
var wood := 0
var stone := 0
var scrap := 0
var ammo := 24
var medkits := 1
var rifle_damage := 34
var enemies: Array[CharacterBody3D] = []
var loot_nodes: Array[Node3D] = []
var enemy_health: Dictionary = {}
var game_time := 0.0
var attack_cooldown := 0.0
var inventory_open := false
var dead := false
var random := RandomNumberGenerator.new()

func _ready() -> void:
	random.randomize()
	_setup_environment()
	_build_world()
	_create_player()
	_create_hud()
	_load_game()
	_update_hud()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.10, 0.17, 0.22)
	sky_mat.sky_horizon_color = Color(0.62, 0.56, 0.42)
	sky_mat.ground_bottom_color = Color(0.07, 0.08, 0.06)
	sky_mat.ground_horizon_color = Color(0.32, 0.31, 0.22)
	env.sky.sky_material = sky_mat
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.52, 0.58, 0.48)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.49, 0.48, 0.39)
	env.fog_density = 0.008
	env.fog_sky_affect = 0.55
	world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-47, -32, 0)
	sun.light_color = Color(1.0, 0.82, 0.62)
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	add_child(sun)

func _mat(color: Color, roughness := 0.9, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m

func _box(parent: Node3D, size: Vector3, pos: Vector3, material: Material, collision := false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	parent.add_child(instance)
	if collision:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		body.position = pos
		body.add_child(shape)
		parent.add_child(body)
	return instance

func _cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, material: Material, sides := 7) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = material
	inst.position = pos
	parent.add_child(inst)
	return inst

func _build_world() -> void:
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(WORLD_SIZE * 2.0, WORLD_SIZE * 2.0)
	var ground_vis := MeshInstance3D.new()
	ground_vis.mesh = ground_mesh
	ground_vis.material_override = _mat(Color(0.24, 0.27, 0.18))
	ground.add_child(ground_vis)
	var ground_shape := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(WORLD_SIZE * 2.0, 0.5, WORLD_SIZE * 2.0)
	ground_shape.shape = floor_shape
	ground_shape.position.y = -0.25
	ground.add_child(ground_shape)
	add_child(ground)
	var dirt := _mat(Color(0.34, 0.30, 0.21))
	var trunk := _mat(Color(0.25, 0.17, 0.11))
	var pine_a := _mat(Color(0.13, 0.22, 0.16))
	var pine_b := _mat(Color(0.20, 0.29, 0.19))
	var rock_mat := _mat(Color(0.35, 0.36, 0.32))
	var rust := _mat(Color(0.30, 0.20, 0.13), 0.75, 0.2)
	var concrete := _mat(Color(0.35, 0.34, 0.29))
	var yellow := _mat(Color(0.68, 0.48, 0.18))
	for i in range(18):
		_box(self, Vector3(4.2, 0.035, 4.4), Vector3(0, 0.015, -40.0 + float(i) * 5.0), dirt)
	for i in range(65):
		var x := random.randf_range(-WORLD_SIZE + 5, WORLD_SIZE - 5)
		var z := random.randf_range(-WORLD_SIZE + 5, WORLD_SIZE - 5)
		if Vector2(x, z).length() < 12.0 or (absf(x) < 3.5 and z < 48 and z > -48):
			continue
		if random.randf() < 0.68:
			var h := random.randf_range(2.8, 5.8)
			_cylinder(self, 0.18, h * 0.45, Vector3(x, h * 0.22, z), trunk, 6)
			var crown := _cylinder(self, random.randf_range(0.8, 1.45), h * 0.62, Vector3(x, h * 0.65, z), pine_a if random.randf() < 0.5 else pine_b, 6)
			crown.mesh.top_radius = 0.05
			crown.mesh.bottom_radius = random.randf_range(0.85, 1.35)
		else:
			var rock := _box(self, Vector3(random.randf_range(0.6, 1.5), random.randf_range(0.4, 1.0), random.randf_range(0.6, 1.4)), Vector3(x, 0.25, z), rock_mat)
			rock.rotation.y = random.randf_range(0, TAU)
	_box(self, Vector3(12, 0.25, 0.35), Vector3(0, 0.7, -10), rust, true)
	_box(self, Vector3(0.35, 1.4, 18), Vector3(-6, 0.7, -1), rust, true)
	_box(self, Vector3(0.35, 1.4, 18), Vector3(6, 0.7, -1), rust, true)
	_box(self, Vector3(5.0, 3.5, 0.3), Vector3(-3.5, 1.75, 7), concrete, true)
	_box(self, Vector3(5.0, 3.5, 0.3), Vector3(3.5, 1.75, 7), concrete, true)
	_box(self, Vector3(12, 0.35, 0.35), Vector3(0, 3.55, 7), rust, true)
	_box(self, Vector3(2.3, 2.4, 0.22), Vector3(0, 1.2, 7), rust, true)
	_box(self, Vector3(3.0, 1.5, 1.8), Vector3(-9, 0.75, 0), rust, true)
	_box(self, Vector3(3.0, 1.5, 1.8), Vector3(9, 0.75, -4), yellow, true)
	for i in range(9):
		_cylinder(self, 0.08, 1.4, Vector3(-9.0 + float(i) * 2.25, 0.7, -10), yellow, 5)
	for i in range(14):
		var p := Vector3(random.randf_range(-18, 18), 0.35, random.randf_range(-20, 18))
		if Vector2(p.x, p.z).length() < 4.0: continue
		var crate := _box(self, Vector3(0.75, 0.7, 0.75), p, rust)
		crate.rotation.y = random.randf_range(0, TAU)
		_add_loot(p + Vector3(0, 0.7, 0), ["wood", "stone", "scrap", "ammo"][random.randi_range(0, 3)])
	for i in range(7):
		var angle := TAU * float(i) / 7.0
		_spawn_mutant(Vector3(cos(angle) * random.randf_range(16, 25), 0, sin(angle) * random.randf_range(16, 25)))

func _create_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0, 0.15, 18)
	player.floor_snap_length = 0.3
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.75
	collision.shape = capsule
	collision.position.y = 0.88
	player.add_child(collision)
	var body_mesh := MeshInstance3D.new()
	var body_capsule := CapsuleMesh.new()
	body_capsule.radius = 0.36
	body_capsule.height = 1.5
	body_mesh.mesh = body_capsule
	body_mesh.material_override = _mat(Color(0.23, 0.28, 0.25))
	body_mesh.position.y = 0.85
	player.add_child(body_mesh)
	camera = Camera3D.new()
	camera.position = Vector3(0, 1.55, 0)
	camera.fov = 78
	player.add_child(camera)
	_box(camera, Vector3(0.16, 0.15, 0.62), Vector3(0.28, -0.28, -0.58), _mat(Color(0.12, 0.13, 0.12), 0.45, 0.55))
	var barrel := _cylinder(camera, 0.035, 0.48, Vector3(0.28, -0.25, -0.98), _mat(Color(0.08, 0.09, 0.08), 0.3, 0.7), 8)
	barrel.rotation.x = PI / 2
	add_child(player)

func _spawn_mutant(pos: Vector3) -> void:
	var enemy := CharacterBody3D.new()
	enemy.name = "Mutant"
	enemy.position = pos
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.48
	shape.height = 1.8
	col.shape = shape
	col.position.y = 0.9
	enemy.add_child(col)
	var torso := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.47
	capsule.height = 1.65
	torso.mesh = capsule
	torso.material_override = _mat(Color(0.26, 0.31, 0.21))
	torso.position.y = 0.9
	enemy.add_child(torso)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.29
	sphere.height = 0.5
	head.mesh = sphere
	head.material_override = _mat(Color(0.37, 0.35, 0.25))
	head.position = Vector3(0, 1.83, -0.05)
	enemy.add_child(head)
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.055
		eye.mesh = eye_mesh
		eye.material_override = _mat(Color(0.9, 0.18, 0.06), 0.2, 0.1)
		eye.position = Vector3(side * 0.12, 1.86, -0.29)
		enemy.add_child(eye)
	add_child(enemy)
	enemies.append(enemy)
	enemy_health[enemy.get_instance_id()] = 100.0

func _add_loot(pos: Vector3, kind: String) -> void:
	var loot := Node3D.new()
	loot.position = pos
	loot.set_meta("kind", kind)
	var color := Color(0.55, 0.39, 0.19)
	if kind == "stone": color = Color(0.48, 0.5, 0.47)
	elif kind == "scrap": color = Color(0.55, 0.57, 0.52)
	elif kind == "ammo": color = Color(0.8, 0.61, 0.2)
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = Vector3(0.28, 0.28, 0.28)
	mesh.mesh = shape
	mesh.material_override = _mat(color, 0.6, 0.25)
	loot.add_child(mesh)
	add_child(loot)
	loot_nodes.append(loot)

func _create_hud() -> void:
	hud = CanvasLayer.new()
	hud.layer = 5
	add_child(hud)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root)
	var top := PanelContainer.new()
	top.position = Vector2(18, 18)
	top.size = Vector2(330, 105)
	top.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.04, 0.035, 0.84)))
	root.add_child(top)
	var top_col := VBoxContainer.new()
	top_col.add_theme_constant_override("separation", 4)
	top.add_child(top_col)
	var title := Label.new()
	title.text = "DEAD ZONE  /  SURVIVAL"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.86, 0.75, 0.48))
	top_col.add_child(title)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 14)
	top_col.add_child(status_label)
	hint_label = Label.new()
	hint_label.text = "Explore  •  Gather  •  Survive"
	hint_label.position = Vector2(18, 132)
	hint_label.add_theme_font_size_override("font_size", 14)
	hint_label.add_theme_color_override("font_color", Color(0.83, 0.84, 0.75))
	root.add_child(hint_label)
	var cross := Label.new()
	cross.text = "+"
	cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	cross.position = Vector2(-8, -17)
	cross.add_theme_font_size_override("font_size", 24)
	cross.add_theme_color_override("font_color", Color(0.93, 0.88, 0.68, 0.85))
	root.add_child(cross)
	_add_button(root, "FIRE", Vector2(-145, -125), Vector2(112, 76), _fire, true)
	_add_button(root, "USE", Vector2(-260, -112), Vector2(94, 60), _interact, true)
	_add_button(root, "BAG", Vector2(-145, -215), Vector2(112, 54), _toggle_inventory, true)
	_add_button(root, "CRAFT", Vector2(-260, -190), Vector2(94, 54), _craft, true)
	_add_button(root, "SAVE", Vector2(-145, -278), Vector2(112, 44), _save_game, true)
	_add_button(root, "MEDKIT", Vector2(-260, -260), Vector2(94, 54), _use_medkit, true)
	inventory_panel = PanelContainer.new()
	inventory_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	inventory_panel.position = Vector2(-220, -150)
	inventory_panel.size = Vector2(440, 300)
	inventory_panel.visible = false
	inventory_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.04, 0.035, 0.95)))
	root.add_child(inventory_panel)
	var inv_col := VBoxContainer.new()
	inv_col.add_theme_constant_override("separation", 10)
	inventory_panel.add_child(inv_col)
	var inv_title := Label.new()
	inv_title.text = "FIELD INVENTORY"
	inv_title.add_theme_font_size_override("font_size", 23)
	inv_title.add_theme_color_override("font_color", Color(0.86, 0.75, 0.48))
	inv_col.add_child(inv_title)
	inventory_label = Label.new()
	inventory_label.add_theme_font_size_override("font_size", 17)
	inv_col.add_child(inventory_label)
	var close := Button.new()
	close.text = "CLOSE  [BAG]"
	close.custom_minimum_size = Vector2(0, 44)
	close.pressed.connect(_toggle_inventory)
	inv_col.add_child(close)
	var help := Label.new()
	help.text = "CRAFT: 3 wood + 2 scrap → medkit"
	help.add_theme_font_size_override("font_size", 14)
	help.add_theme_color_override("font_color", Color(0.7, 0.75, 0.66))
	inv_col.add_child(help)
	var dead_overlay := Label.new()
	dead_overlay.name = "DeadText"
	dead_overlay.text = "YOU ARE DOWN\nTap SAVE or restart the game"
	dead_overlay.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	dead_overlay.position = Vector2(-180, -65)
	dead_overlay.add_theme_font_size_override("font_size", 26)
	dead_overlay.add_theme_color_override("font_color", Color(0.9, 0.25, 0.15))
	dead_overlay.visible = false
	root.add_child(dead_overlay)

func _panel_style(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = Color(0.47, 0.43, 0.30, 0.85)
	s.set_border_width_all(1)
	s.set_corner_radius_all(8)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s

func _add_button(parent: Control, caption: String, offset: Vector2, size: Vector2, callback: Callable, from_right := false) -> void:
	var b := Button.new()
	b.text = caption
	b.size = size
	b.custom_minimum_size = size
	if from_right:
		b.anchor_left = 1.0
		b.anchor_right = 1.0
		b.anchor_top = 1.0
		b.anchor_bottom = 1.0
		b.position = offset
	else:
		b.position = offset
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", Color(0.93, 0.91, 0.82))
	b.add_theme_stylebox_override("normal", _panel_style(Color(0.055, 0.075, 0.06, 0.82)))
	b.add_theme_stylebox_override("hover", _panel_style(Color(0.17, 0.19, 0.12, 0.92)))
	b.pressed.connect(callback)
	parent.add_child(b)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE: _toggle_inventory()
			KEY_E: _interact()
			KEY_F: _fire()
			KEY_C: _craft()
			KEY_I: _toggle_inventory()
			KEY_H: _use_medkit()
			KEY_F5: _save_game()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and not inventory_open:
			_fire()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not inventory_open:
		player.rotate_y(-event.relative.x * MOUSE_SENS)
		camera.rotate_x(-event.relative.y * MOUSE_SENS)
		camera.rotation.x = clampf(camera.rotation.x, -1.25, 1.25)
	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.x < get_viewport().get_visible_rect().size.x * 0.46 and joystick_touch == -1:
				joystick_touch = event.index
				joystick_center = event.position
				joystick_vector = Vector2.ZERO
			elif look_touch == -1 and not inventory_open:
				look_touch = event.index
				look_last = event.position
		else:
			if event.index == joystick_touch:
				joystick_touch = -1
				joystick_vector = Vector2.ZERO
			if event.index == look_touch:
				look_touch = -1
	if event is InputEventScreenDrag:
		if event.index == joystick_touch:
			joystick_vector = (event.position - joystick_center).limit_length(75.0) / 75.0
		elif event.index == look_touch and not inventory_open:
			player.rotate_y(-event.relative.x * 0.004)
			camera.rotate_x(-event.relative.y * 0.004)
			camera.rotation.x = clampf(camera.rotation.x, -1.25, 1.25)

func _physics_process(delta: float) -> void:
	if dead: return
	game_time += delta
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	if joystick_touch != -1:
		move_input = joystick_vector
	else:
		move_input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := (player.transform.basis * Vector3(move_input.x, 0, move_input.y)).normalized()
	var sprinting := Input.is_key_pressed(KEY_SHIFT) and stamina > 1.0
	var speed := SPRINT_SPEED if sprinting else WALK_SPEED
	if sprinting and wish.length() > 0.1:
		stamina = maxf(0.0, stamina - 20.0 * delta)
	else:
		stamina = minf(100.0, stamina + 12.0 * delta)
	player.velocity.x = wish.x * speed
	player.velocity.z = wish.z * speed
	if not player.is_on_floor():
		player.velocity.y -= 18.0 * delta
	else:
		player.velocity.y = -0.4
	player.move_and_slide()
	player.position.x = clampf(player.position.x, -WORLD_SIZE + 2, WORLD_SIZE - 2)
	player.position.z = clampf(player.position.z, -WORLD_SIZE + 2, WORLD_SIZE - 2)
	_update_enemies(delta)
	_update_hud()

func _update_enemies(delta: float) -> void:
	for enemy in enemies.duplicate():
		if not is_instance_valid(enemy):
			enemies.erase(enemy)
			continue
		var dist := enemy.global_position.distance_to(player.global_position)
		if dist < 22.0 and dist > 1.35:
			var direction := player.global_position - enemy.global_position
			direction.y = 0
			direction = direction.normalized()
			enemy.look_at(Vector3(player.global_position.x, enemy.global_position.y, player.global_position.z), Vector3.UP)
			enemy.velocity.x = direction.x * (2.15 if dist < 10 else 1.4)
			enemy.velocity.z = direction.z * (2.15 if dist < 10 else 1.4)
			enemy.velocity.y = -0.4
			enemy.move_and_slide()
		elif dist <= 1.55:
			enemy.velocity = Vector3.ZERO
			if int(game_time * 2.0) % 2 == 0 and attack_cooldown <= 0.0:
				health -= 8.0
				attack_cooldown = 0.6
				hint_label.text = "A mutant hit you!"
				if health <= 0: _die()

func _fire() -> void:
	if dead or inventory_open or attack_cooldown > 0.0: return
	if ammo <= 0:
		hint_label.text = "Out of ammo — search crates"
		return
	ammo -= 1
	attack_cooldown = 0.22
	var from := camera.global_position
	var to := from + (-camera.global_transform.basis.z * 45.0)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var target: Node3D = null
	if not hit.is_empty():
		for enemy in enemies:
			if is_instance_valid(enemy) and (hit.collider == enemy or enemy.is_ancestor_of(hit.collider)):
				target = enemy
				break
	if target == null:
		var best := 45.0
		for enemy in enemies:
			if not is_instance_valid(enemy): continue
			var dist := camera.global_position.distance_to(enemy.global_position + Vector3.UP)
			var aim := (-camera.global_transform.basis.z).dot((enemy.global_position + Vector3.UP - from).normalized())
			if aim > 0.965 and dist < best:
				best = dist
				target = enemy
	if target != null and is_instance_valid(target):
		var id := target.get_instance_id()
		enemy_health[id] = float(enemy_health.get(id, 100.0)) - float(rifle_damage)
		hint_label.text = "HIT CONFIRMED  •  %d%%" % max(0, int(enemy_health[id]))
		if float(enemy_health[id]) <= 0.0: _kill_enemy(target)
	else:
		hint_label.text = "Shot fired"
	_update_hud()

func _kill_enemy(enemy: CharacterBody3D) -> void:
	var pos := enemy.global_position
	enemy_health.erase(enemy.get_instance_id())
	enemies.erase(enemy)
	enemy.queue_free()
	_add_loot(pos + Vector3(0, 0.5, 0), "scrap")
	hint_label.text = "Mutant down — salvage recovered"

func _interact() -> void:
	if dead: return
	var nearest: Node3D
	var best := 3.4
	for item in loot_nodes:
		if not is_instance_valid(item): continue
		var dist := player.global_position.distance_to(item.global_position)
		if dist < best:
			best = dist
			nearest = item
	if nearest != null:
		var kind: String = str(nearest.get_meta("kind", "wood"))
		match kind:
			"wood": wood += 2
			"stone": stone += 2
			"scrap": scrap += 1
			"ammo": ammo += 6
		loot_nodes.erase(nearest)
		nearest.queue_free()
		hint_label.text = "Collected: " + kind.to_upper()
		_update_hud()
		return
	hint_label.text = "Nothing nearby — explore the outpost"

func _craft() -> void:
	if wood >= 3 and scrap >= 2:
		wood -= 3
		scrap -= 2
		medkits += 1
		hint_label.text = "Crafted 1 field medkit"
	else:
		hint_label.text = "Need 3 wood + 2 scrap to craft a medkit"
	_update_hud()

func _use_medkit() -> void:
	if medkits > 0 and health < 100.0:
		medkits -= 1
		health = minf(100.0, health + 45.0)
		hint_label.text = "Medkit used • health restored"
	else:
		hint_label.text = "No medkit or health already full"
	_update_hud()

func _toggle_inventory() -> void:
	inventory_open = not inventory_open
	inventory_panel.visible = inventory_open
	_update_hud()

func _update_hud() -> void:
	if not is_instance_valid(status_label): return
	status_label.text = "HP %03d   STA %03d   AMMO %02d" % [int(health), int(stamina), ammo]
	inventory_label.text = "WOOD      %d\nSTONE     %d\nSCRAP     %d\nAMMO      %d\nMEDKITS   %d\n\nMutants nearby: %d" % [wood, stone, scrap, ammo, medkits, enemies.size()]
	if dead: status_label.text = "SIGNAL LOST  •  RELOAD SAVE"

func _die() -> void:
	dead = true
	var overlay := hud.get_node_or_null("Control/DeadText")
	if overlay: overlay.visible = true
	hint_label.text = "You are down — restart to continue"

func _save_game() -> void:
	var data := {"position": [player.position.x, player.position.y, player.position.z], "health": health, "stamina": stamina, "wood": wood, "stone": stone, "scrap": scrap, "ammo": ammo, "medkits": medkits, "game_time": game_time}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		hint_label.text = "Game saved locally"
	else:
		hint_label.text = "Save failed"
	_update_hud()

func _load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH): return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null: return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY: return
	var data: Dictionary = parsed
	var p: Array = data.get("position", [0, 0.15, 18])
	player.position = Vector3(float(p[0]), float(p[1]), float(p[2]))
	health = float(data.get("health", 100))
	stamina = float(data.get("stamina", 100))
	wood = int(data.get("wood", 0))
	stone = int(data.get("stone", 0))
	scrap = int(data.get("scrap", 0))
	ammo = int(data.get("ammo", 24))
	medkits = int(data.get("medkits", 1))
	game_time = float(data.get("game_time", 0))
	hint_label.text = "Local save restored"

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_game()
