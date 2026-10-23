extends Node3D
## Vertical slice: forest ambush, then capture the hill fort. All placeholder shapes.
var stage := 0
var remaining := 0
var capture := 0.0
var player
var cannon: Node3D
var cannon_t := 6.0
var flag_zone: Area3D
var enemies := Node3D.new()

func _ready() -> void:
	InputSetup.setup()
	add_child(Hud.new())
	_env()
	_ground()
	for i in 120: _tree(Vector3(randf_range(-70, 70), 0, randf_range(-70, 40)))
	for i in 60: _bush(Vector3(randf_range(-60, 60), 0, randf_range(-60, 30)))
	_fort(Vector3(0, 0, -95))
	add_child(enemies)
	player = _make_player(Vector3(0, 1, 30))
	player.died.connect(_on_died)
	_start_ambush()

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX; return m

func _env() -> void:
	var we := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.55, 0.65, 0.55)
	e.fog_enabled = true; e.fog_light_color = Color(0.5, 0.6, 0.5); e.fog_density = 0.02
	e.ambient_light_color = Color(0.6, 0.6, 0.5); e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	we.environment = e; add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-50, 30, 0); sun.shadow_enabled = true; add_child(sun)

func _box(size: Vector3, pos: Vector3, col: Color, parent: Node = self) -> StaticBody3D:
	var b := StaticBody3D.new(); b.position = pos
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; mi.material_override = _mat(col)
	var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = size; cs.shape = sh
	b.add_child(mi); b.add_child(cs); parent.add_child(b); return b

func _ground() -> void:
	_box(Vector3(200, 1, 260), Vector3(0, -0.5, -30), Color(0.3, 0.4, 0.2))
	# hill under the fort, stepped so it is walkable
	for i in 6: _box(Vector3(60 - i * 7, 1, 50 - i * 6), Vector3(0, i * 1.0 + 0.5, -95), Color(0.4, 0.35, 0.2))

func _tree(p: Vector3) -> void:
	if p.distance_to(Vector3(0, 0, 30)) < 6: return
	var t := _box(Vector3(0.8, 9, 0.8), p + Vector3(0, 4.5, 0), Color(0.3, 0.2, 0.1))
	var mi := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 3.5; sm.height = 5; sm.radial_segments = 8; sm.rings = 4
	mi.mesh = sm; mi.material_override = _mat(Color(0.15, 0.35, 0.12)); mi.position.y = 5; t.add_child(mi)

func _bush(p: Vector3) -> void:
	## hiding spot: player inside is much harder to see
	var a := Area3D.new(); a.position = p + Vector3(0, 0.8, 0)
	var mi := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 1.6; sm.height = 2.0; sm.radial_segments = 6; sm.rings = 3
	mi.mesh = sm; mi.material_override = _mat(Color(0.2, 0.45, 0.15)); a.add_child(mi)
	var cs := CollisionShape3D.new(); var sh := SphereShape3D.new(); sh.radius = 1.6; cs.shape = sh; a.add_child(cs)
	a.body_entered.connect(_foliage.bind(1))
	a.body_exited.connect(_foliage.bind(-1))
	add_child(a)

func _foliage(b: Node, d: int) -> void:
	if b.is_in_group("player"): b.in_foliage += d

func _fort(c: Vector3) -> void:
	var y := 6.0; var w := Color(0.85, 0.82, 0.75)
	_box(Vector3(24, 4, 1), c + Vector3(0, y + 2, -12), w)
	_box(Vector3(1, 4, 24), c + Vector3(-12, y + 2, 0), w)
	_box(Vector3(1, 4, 24), c + Vector3(12, y + 2, 0), w)
	_box(Vector3(9, 4, 1), c + Vector3(-7.5, y + 2, 12), w)   # gate gap in the middle
	_box(Vector3(9, 4, 1), c + Vector3(7.5, y + 2, 12), w)
	_box(Vector3(4, 3, 4), c + Vector3(0, y + 1.5, 9), w)     # cannon platform
	cannon = Node3D.new(); cannon.position = c + Vector3(0, y + 3.5, 9); add_child(cannon)
	var barrel := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.25; cm.bottom_radius = 0.35; cm.height = 2.5
	barrel.mesh = cm; barrel.material_override = _mat(Color(0.1, 0.1, 0.1)); barrel.rotation_degrees.x = 90; cannon.add_child(barrel)
	var pole := _box(Vector3(0.2, 6, 0.2), c + Vector3(0, y + 3, -4), Color(0.4, 0.3, 0.2))
	var flag := MeshInstance3D.new(); var fm := BoxMesh.new(); fm.size = Vector3(2, 1.2, 0.05); flag.mesh = fm
	flag.material_override = _mat(Color(0.8, 0.1, 0.1)); flag.position = Vector3(1, 2.4, 0); flag.name = "Flag"; pole.add_child(flag)
	flag_zone = Area3D.new(); flag_zone.position = c + Vector3(0, y + 1, -4)
	var cs := CollisionShape3D.new(); var sh := SphereShape3D.new(); sh.radius = 3; cs.shape = sh; flag_zone.add_child(cs); add_child(flag_zone)

func _make_player(p: Vector3):
	var b := CharacterBody3D.new(); b.set_script(load("res://scripts/player.gd")); b.position = p
	var cs := CollisionShape3D.new(); var sh := CapsuleShape3D.new(); cs.shape = sh; cs.position.y = 1; b.add_child(cs)
	var cam := Camera3D.new(); cam.name = "Cam"; cam.position.y = 1.6; b.add_child(cam)
	var r := RayCast3D.new(); r.name = "Ray"; r.target_position = Vector3(0, 0, -120); cam.add_child(r)
	add_child(b); return b

func _make_enemy(p: Vector3, post := false) -> void:
	var b := CharacterBody3D.new(); b.set_script(load("res://scripts/enemy.gd")); b.position = p
	var cs := CollisionShape3D.new(); var sh := CapsuleShape3D.new(); cs.shape = sh; cs.position.y = 1; b.add_child(cs)
	var mi := MeshInstance3D.new(); var cm := CapsuleMesh.new(); mi.mesh = cm; mi.position.y = 1; mi.material_override = _mat(Color(0.75, 0.1, 0.1)); b.add_child(mi)
	var hat := MeshInstance3D.new(); var hm := CylinderMesh.new(); hm.top_radius = 0.25; hm.bottom_radius = 0.25; hm.height = 0.4; hat.mesh = hm
	hat.position.y = 2.2; hat.material_override = _mat(Color.BLACK); b.add_child(hat)
	var e := RayCast3D.new(); e.name = "Eye"; e.position.y = 1.6; b.add_child(e)
	b.static_post = post
	enemies.add_child(b); remaining += 1

func _start_ambush() -> void:
	stage = 0
	Hud.objective("Ambush the British column in the forest (stay in the bushes, crouch)")
	for i in 5: _make_enemy(Vector3(randf_range(-15, 15), 1, randf_range(-40, -20)))

func _start_fort() -> void:
	stage = 1
	Hud.objective("Take the hill fort: clear the defenders and silence the cannon")
	var c := Vector3(0, 7, -95)
	for off in [Vector3(-6, 0, 6), Vector3(6, 0, 6), Vector3(0, 0, -8), Vector3(-8, 0, -6)]:
		_make_enemy(c + off, true)

func enemy_down() -> void:
	remaining -= 1
	if remaining > 0: Hud.msg("Enemy down. %d left" % remaining); return
	if stage == 0: Hud.msg("Column broken!"); _start_fort()
	elif stage == 1: stage = 2; Hud.objective("Stand at the flag to capture the fort")

func _process(dt: float) -> void:
	if stage == 1 and cannon:
		var to: Vector3 = player.global_position - cannon.global_position
		cannon.look_at(player.global_position)
		cannon_t -= dt
		if cannon_t <= 0 and to.length() < 70:
			cannon_t = [12.0, 8.0, 5.0][Game.difficulty]
			Hud.msg("CANNON FIRE! Take cover behind trees!")
			var q := PhysicsRayQueryParameters3D.create(cannon.global_position, player.global_position + Vector3.UP)
			var hit := get_world_3d().direct_space_state.intersect_ray(q)
			if hit and hit.collider == player: player.hurt(45)
	if stage == 2 and player in flag_zone.get_overlapping_bodies():
		capture += dt; Hud.msg("Capturing... %d%%" % (capture / 5.0 * 100))
		if capture >= 5.0:
			stage = 3; Hud.objective("FORT CAPTURED. Mission complete!")
			find_child("Flag", true, false).material_override = _mat(Color(0.9, 0.75, 0.1))

func _on_died() -> void:
	Hud.objective("You fell. Restarting from checkpoint...")
	await get_tree().create_timer(2.0).timeout
	player.hp = 100; player.position = Vector3(0, 1, 30) if stage == 0 else Vector3(0, 1, -50)
