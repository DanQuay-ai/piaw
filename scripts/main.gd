class_name Main extends Node3D
## Runs a mission from Missions: map layout + stages (kill / waves / reach / capture / end).
static var inst: Main
static var mission_id := "nsamankow"
static var autostart := false
var mdef: Dictionary
var stages: Array
var waves_left: Array = []
var wave_target := Vector3.ZERO
var wave_t := 0.0
var hud: Hud
var world: World
var stage := 0
var remaining := 0
var capture := 0.0
var player
var cannon: Node3D
var cannon_t := 6.0
var flag_zone: Area3D
var flag: MeshInstance3D
var enemies := Node3D.new()
var checkpoint := Vector3.ZERO
var objective_pos := Vector3.ZERO
var gorilla_charge := 0.35   # 0..1, whistle when full
var gorilla_out := false
var alarm_raised := false
var kills := 0
var score := 0
var map_tex: ImageTexture

func _ready() -> void:
	inst = self
	InputSetup.setup()
	Settings.load_cfg()
	Audio.init(self)
	add_child(PadBridge.new())
	Audio.play_music("menu")
	var grade := CanvasLayer.new(); grade.layer = 1; grade.set_script(load("res://scripts/grading.gd")); add_child(grade)
	hud = Hud.new(); add_child(hud)
	hud.play_pressed.connect(_start)
	hud.restart_pressed.connect(func(): get_tree().paused = false; get_tree().reload_current_scene())
	mdef = Missions.get_def(mission_id); stages = mdef.stages
	World.configure(mdef.map)
	world = World.new(); add_child(world); world.build()
	if World.HAS_FORT: _fort(mdef.map.get("fort_style", "hill"), float(mdef.map.get("fort_yaw", 0.0)))
	add_child(enemies)
	if World.HAS_VILLAGE: _villagers()
	map_tex = ImageTexture.create_from_image(world.map_image(160))
	var sy: float = world.height(World.SPAWN.x, World.SPAWN.y) + 1.0
	if mdef.get("start_in_fort", false): sy = world.fort_top + 1.0
	player = _make_player(Vector3(World.SPAWN.x, sy, World.SPAWN.y))
	player.died.connect(_on_died)
	checkpoint = player.position
	get_tree().paused = true  # wait in menu
	if autostart:
		autostart = false
		hud.menus.show_screen("")
		_start.call_deferred()

func _start() -> void:
	hud.show_game()
	Audio.play_music("battle", -10.0); Audio.ambience(true)
	if stage == 0 and remaining == 0:
		_begin_stage(0)
		Audio.say(mdef.narr, 0.0)
		await get_tree().create_timer(10.0).timeout
		Audio.say("yenko", 0.0)

# ---------------------------------------------------------------- fort
func _fort(style: String, yaw: float) -> void:
	var c := Vector3(World.FORT.x, world.fort_top, World.FORT.y)
	var root := Node3D.new(); root.position = c; root.rotation.y = yaw; add_child(root)
	var body := StaticBody3D.new(); root.add_child(body)
	var walls := []
	var dado := 4.0
	if style == "castle":  # Christiansborg: big white sea castle with towers
		dado = 3.5
		walls = [
			[Vector3(40, 8, 1.6), Vector3(0, 4, -20)], [Vector3(1.6, 8, 40), Vector3(-20, 4, 0)], [Vector3(1.6, 8, 40), Vector3(20, 4, 0)],
			[Vector3(16, 8, 1.6), Vector3(-12, 4, 20)], [Vector3(16, 8, 1.6), Vector3(12, 4, 20)],
			[Vector3(7, 12, 7), Vector3(-20, 6, -20)], [Vector3(7, 12, 7), Vector3(20, 6, -20)], [Vector3(7, 11, 7), Vector3(-20, 5.5, 20)], [Vector3(7, 11, 7), Vector3(20, 5.5, 20)],
			[Vector3(18, 6, 8), Vector3(0, 3, -14)], [Vector3(6, 2, 6), Vector3(-14, 1, 8)], [Vector3(6, 2, 6), Vector3(14, 1, 8)],
		]
	else:
		walls = [
			[Vector3(30, 5, 1.2), Vector3(0, 2.5, -15)], [Vector3(1.2, 5, 30), Vector3(-15, 2.5, 0)], [Vector3(1.2, 5, 30), Vector3(15, 2.5, 0)],
			[Vector3(11, 5, 1.2), Vector3(-9.5, 2.5, 15)], [Vector3(11, 5, 1.2), Vector3(9.5, 2.5, 15)],
			[Vector3(5, 7, 5), Vector3(-15, 3.5, -15)], [Vector3(5, 7, 5), Vector3(15, 3.5, -15)],
			[Vector3(5, 7, 5), Vector3(-15, 3.5, 15)], [Vector3(5, 7, 5), Vector3(15, 3.5, 15)],
			[Vector3(5, 3, 5), Vector3(0, 1.5, 9)], [Vector3(10, 4, 6), Vector3(0, 2, -9)],
		]
	for w in walls:
		var sz: Vector3 = w[0] + Vector3(0, 3, 0)  # 3 m foundation into the ground
		var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = sz; mi.mesh = bm
		var mat: ShaderMaterial = Buildings.wall_mat.duplicate(); mat.set_shader_parameter("half_h", sz.y / 2.0); mat.set_shader_parameter("dado", dado); mat.set_shader_parameter("tint", 0.78 if style == "castle" else 0.9)
		mi.material_override = mat; mi.position = w[1] - Vector3(0, 1.5, 0); root.add_child(mi)
		var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = sz; cs.shape = sh; cs.position = mi.position; body.add_child(cs)
	var tower_h := 12.2 if style == "castle" else 7.2
	var tx := 20 if style == "castle" else 15
	for x in [-tx, tx]:
		for z in [-tx, tx]:
			_cannon_mesh(root, Vector3(x, tower_h, z), atan2(float(x), float(z)))
	cannon = _cannon_mesh(root, Vector3(0, 3.6, 9) if style != "castle" else Vector3(-14, 2.6, 8), 0.0)
	var pole := MeshInstance3D.new(); var pm := CylinderMesh.new(); pm.top_radius = 0.06; pm.bottom_radius = 0.08; pm.height = 9
	pole.mesh = pm; pole.material_override = Props.bark; pole.position = Vector3(0, 4.5, -2); root.add_child(pole)
	flag = MeshInstance3D.new(); var fm := BoxMesh.new(); fm.size = Vector3(2.4, 1.5, 0.04); flag.mesh = fm
	var fmat := StandardMaterial3D.new(); fmat.albedo_color = Color(0.75, 0.1, 0.12) if style != "castle" else Color(0.75, 0.1, 0.12); flag.material_override = fmat
	flag.position = Vector3(1.25, 8.2, -2); root.add_child(flag)
	flag_zone = Area3D.new(); flag_zone.position = Vector3(0, 1, -2); root.add_child(flag_zone)
	var zs := CollisionShape3D.new(); var sp := SphereShape3D.new(); sp.radius = 3.5; zs.shape = sp; flag_zone.add_child(zs)
	fort_root = root

var fort_root: Node3D

func _cannon_mesh(parent: Node3D, pos: Vector3, yaw: float) -> Node3D:
	var n := Node3D.new(); n.position = pos; n.rotation.y = yaw; parent.add_child(n)
	var iron := StandardMaterial3D.new(); iron.albedo_color = Color(0.12, 0.12, 0.13); iron.metallic = 0.7; iron.roughness = 0.45
	var b := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.2; cm.bottom_radius = 0.32; cm.height = 2.6; cm.radial_segments = 10
	b.mesh = cm; b.material_override = iron; b.rotation.x = PI / 2; b.position.z = 0.6; n.add_child(b)
	var carriage := MeshInstance3D.new(); var cb := BoxMesh.new(); cb.size = Vector3(0.9, 0.5, 1.6); carriage.mesh = cb
	carriage.material_override = Props.bark; carriage.position = Vector3(0, -0.45, -0.1); n.add_child(carriage)
	for s in [-0.55, 0.55]:
		var w := MeshInstance3D.new(); var wm := CylinderMesh.new(); wm.top_radius = 0.45; wm.bottom_radius = 0.45; wm.height = 0.12
		w.mesh = wm; w.material_override = Props.bark; w.rotation.z = PI / 2; w.position = Vector3(s, -0.55, 0.0); n.add_child(w)
	return n

# ---------------------------------------------------------------- actors
func _make_player(p: Vector3):
	var b := CharacterBody3D.new(); b.set_script(load("res://scripts/player.gd")); b.position = p
	var cs := CollisionShape3D.new(); var sh := CapsuleShape3D.new(); sh.radius = 0.4; cs.shape = sh; cs.position.y = 1; b.add_child(cs)
	var cam := Camera3D.new(); cam.name = "Cam"; cam.position.y = 1.6; cam.near = 0.03; cam.far = 400; b.add_child(cam)
	add_child(b); return b

func _make_enemy(p: Vector3, kind: String, post := false) -> Node:
	var b := CharacterBody3D.new(); b.set_script(load("res://scripts/enemy.gd"))
	b.position = Vector3(p.x, world.height(p.x, p.z) + 0.6, p.z) if p.y == 0.0 else p
	b.kind = kind
	var cs := CollisionShape3D.new(); var sh := CapsuleShape3D.new(); sh.radius = 0.4; cs.shape = sh; cs.position.y = 1; b.add_child(cs)
	var e := RayCast3D.new(); e.name = "Eye"; e.position.y = 1.6; b.add_child(e)
	b.static_post = post
	enemies.add_child(b); remaining += 1
	return b

func _villagers() -> void:
	var ids := ["asante_musketeer", "asante_ankobia", "fante_asafo", "asante_batakari"]
	var c := Vector3(World.VILLAGE.x, world.village_h, World.VILLAGE.y)
	for i in ids.size():
		if not Characters.exists(ids[i]): continue
		var n := Node3D.new(); n.set_script(load("res://scripts/villager.gd"))
		n.position = c + Vector3(randf_range(-2, 2), 0, -18 + i * 10); add_child(n)
		n.setup(ids[i], c)

# ---------------------------------------------------------------- events
func noise_at(pos: Vector3, radius: float) -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.global_position.distance_to(pos) < radius: e.alert(pos + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6)))

func on_alert(e) -> void:
	for o in get_tree().get_nodes_in_group("enemy"):
		if o != e and o.global_position.distance_to(e.global_position) < 25.0 and not o.alerted: o.alert(e.global_position)
	if not alarm_raised:
		alarm_raised = true
		Audio.say("ajei", 0.0)
		await get_tree().create_timer(1.2).timeout
		Audio.say("off_ambush", 0.0)
		await get_tree().create_timer(2.6).timeout
		Audio.say("obroni", 0.0)

func enemy_down(_e, melee: bool) -> void:
	remaining -= 1; kills += 1
	gorilla_charge = min(1.0, gorilla_charge + 0.18)
	Audio.say("masa_ku_no" if melee and randf() < 0.6 else "asaaka", 3.0)
	Hud.kill_feed(("AFENA" if melee else player.gun_stats().name) + "  >  " + ("REDCOAT" if _e.kind == "british_redcoat" else ("WEST INDIA REGT" if _e.kind == "west_india_regt" else "SOLDIER")))
	if remaining > 0 or not waves_left.is_empty():
		Hud.msg("%d left" % remaining if remaining > 0 else "Wave broken! More are coming..."); return
	Hud.msg("PIAW!"); _next_stage()

func enemy_name(e) -> String:
	if mdef.names.has(e.kind): return mdef.names[e.kind]
	match e.kind:
		"british_redcoat": return "British soldier"
		"west_india_regt": return "West India Regiment soldier"
		"dutch_soldier": return "Dutch soldier"
	return "soldier"

func score_hit(_e, text: String, pts: int, killed: bool, headshot: bool) -> void:
	score += pts
	Hud.popup(text, pts, headshot, killed)

func whistle() -> void:
	if gorilla_out: Hud.msg("The gorilla is already loose"); return
	if gorilla_charge < 1.0: Hud.msg("The forest isn't ready yet  (%d%%)" % int(gorilla_charge * 100)); return
	gorilla_charge = 0.0; gorilla_out = true
	Audio.play("whistle", null, 0, 0.0)
	Hud.msg("You whistle into the bush...")
	await get_tree().create_timer(1.3).timeout
	var g := Node3D.new(); g.set_script(load("res://scripts/gorilla.gd"))
	var back: Vector3 = player.global_basis.z * 14.0 + player.global_basis.x * randf_range(-6, 6)
	var p: Vector3 = player.global_position + back
	g.position = Vector3(p.x, world.height(p.x, p.z), p.z)
	add_child(g)
	g.tree_exited.connect(func(): gorilla_out = false)

# ---------------------------------------------------------------- mission flow
func _fort_c() -> Vector3:
	return fort_root.global_position if fort_root else Vector3(World.FORT.x, world.fort_top, World.FORT.y)

func _next_stage() -> void:
	_begin_stage(stage + 1)

func _begin_stage(i: int) -> void:
	stage = i
	alarm_raised = false
	if i >= stages.size():
		_finish(); return
	var s: Dictionary = stages[i]
	Hud.objective(s.text)
	if i > 0: Audio.say("yenko", 0.0); checkpoint = player.global_position + Vector3.UP
	match s.type:
		"kill":
			if s.has("column"):
				for k in s.column.size():
					var z: float = 40.0 - k * 4.0
					_make_enemy(Vector3(world.path_x(z) + randf_range(-2, 2), 0, z), s.column[k])
			if s.has("posts"):
				for p in s.posts:
					var lp: Vector3 = fort_root.global_transform * p[0] if fort_root else _fort_c() + p[0]
					_make_enemy(lp + Vector3(0, 0.5, 0) if p[0].y != 0.0 else Vector3(lp.x, world.fort_top + 0.6, lp.z), p[1], true)
			if s.has("posts_abs"):
				for p in s.posts_abs: _make_enemy(p[0], p[1], true)
		"waves":
			waves_left = s.waves.duplicate(true)
			match s.target:
				"fort": wave_target = _fort_c()
				"village": wave_target = Vector3(World.VILLAGE.x, world.village_h, World.VILLAGE.y)
				_: wave_target = Vector3(world.path_x(-50), world.height(world.path_x(-50), -50), -50)
			objective_pos = wave_target
			wave_t = 2.0
		"reach":
			objective_pos = s.pos
		"capture":
			capture = 0.0
			objective_pos = flag_zone.global_position
		"end":
			_finish()

func _spawn_wave() -> void:
	var w: Array = waves_left.pop_front()
	for p in w:
		var e = _make_enemy(p[0], p[1])
		e.alerted = true; e.investigate = wave_target + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6))
	Hud.msg("Wave incoming!  (%d more after this)" % waves_left.size())
	Audio.say("off_bayonet", 0.0)

func _finish() -> void:
	stage = 99
	Hud.objective("Mission complete.")
	if flag: flag.material_override.albedo_color = Color(0.85, 0.66, 0.12)
	Audio.play("talking_drum", null, 0, 0.0)
	Audio.say("asaaka", 0.0)
	await get_tree().create_timer(2.5).timeout
	hud.show_end("PIAW!  %s" % mdef.title)

func _process(dt: float) -> void:
	if get_tree().paused or not player: return
	if not gorilla_out: gorilla_charge = min(1.0, gorilla_charge + dt / 80.0)
	if stage >= stages.size(): return
	var s: Dictionary = stages[stage]
	if s.type == "kill" and remaining > 0:  # marker follows the nearest enemy
		var bd := INF
		for e in get_tree().get_nodes_in_group("enemy"):
			var d: float = e.global_position.distance_to(player.global_position)
			if d < bd: bd = d; objective_pos = e.global_position
	if s.type == "waves":
		if remaining == 0 and not waves_left.is_empty():
			wave_t -= dt
			if wave_t <= 0: _spawn_wave(); wave_t = 6.0
		elif remaining == 0 and waves_left.is_empty(): _next_stage(); return
	if s.type == "reach":
		var d2 := Vector2(player.global_position.x - s.pos.x, player.global_position.z - s.pos.z).length()
		if d2 < s.radius: Hud.msg("PIAW!"); _next_stage(); return
	if s.get("cannon", false) and cannon:
		cannon.look_at(player.global_position)
		cannon_t -= dt
		if cannon_t <= 0 and cannon.global_position.distance_to(player.global_position) < 80:
			cannon_t = [12.0, 8.0, 5.5][Game.difficulty]
			var muzzle: Vector3 = cannon.global_position - cannon.global_basis.z * 1.6
			Fx.smoke(self, muzzle, 3.0); Fx.flash(self, muzzle)
			Audio.play("cannon", muzzle, 6)
			Hud.msg("CANNON! Get behind a tree!")
			var q := PhysicsRayQueryParameters3D.create(muzzle, player.global_position + Vector3.UP)
			var hit := get_world_3d().direct_space_state.intersect_ray(q)
			if hit and hit.collider == player: player.hurt(45)
	if s.type == "capture" and player in flag_zone.get_overlapping_bodies():
		capture += dt; Hud.msg("Raising the colours... %d%%" % int(capture / 5.0 * 100))
		if capture >= 5.0: _next_stage()

func _on_died() -> void:
	Audio.say("wasei", 0.0)
	Hud.objective("You fell. Back to the last checkpoint...")
	await get_tree().create_timer(1.5).timeout
	player.hp = 100; player.position = checkpoint; player.velocity = Vector3.ZERO
