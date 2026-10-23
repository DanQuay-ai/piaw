class_name Main extends Node3D
## Mission 1 (Nsamankow, 1824 - prototype): break the column in the forest, then take the hill fort.
static var inst: Main
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

func _ready() -> void:
	inst = self
	InputSetup.setup()
	Audio.init(self)
	hud = Hud.new(); add_child(hud)
	hud.play_pressed.connect(_start)
	hud.restart_pressed.connect(func(): get_tree().paused = false; get_tree().reload_current_scene())
	world = World.new(); add_child(world); world.build()
	_fort()
	add_child(enemies)
	_villagers()
	player = _make_player(Vector3(World.SPAWN.x, world.height(World.SPAWN.x, World.SPAWN.y) + 1.0, World.SPAWN.y))
	player.died.connect(_on_died)
	checkpoint = player.position
	get_tree().paused = true  # wait in menu

func _start() -> void:
	hud.show_game()
	if stage == 0 and remaining == 0:
		_start_ambush()
		Audio.say("narr_intro", 0.0)
		await get_tree().create_timer(11.0).timeout
		Audio.say("yenko", 0.0)

# ---------------------------------------------------------------- fort
func _fort() -> void:
	var c := Vector3(World.FORT.x, world.fort_top, World.FORT.y)
	var body := StaticBody3D.new(); add_child(body)
	var walls := [
		[Vector3(30, 5, 1.2), Vector3(0, 2.5, -15)], [Vector3(1.2, 5, 30), Vector3(-15, 2.5, 0)], [Vector3(1.2, 5, 30), Vector3(15, 2.5, 0)],
		[Vector3(11, 5, 1.2), Vector3(-9.5, 2.5, 15)], [Vector3(11, 5, 1.2), Vector3(9.5, 2.5, 15)],
		[Vector3(5, 7, 5), Vector3(-15, 3.5, -15)], [Vector3(5, 7, 5), Vector3(15, 3.5, -15)],
		[Vector3(5, 7, 5), Vector3(-15, 3.5, 15)], [Vector3(5, 7, 5), Vector3(15, 3.5, 15)],
		[Vector3(5, 3, 5), Vector3(0, 1.5, 9)], [Vector3(10, 4, 6), Vector3(0, 2, -9)],
	]
	for w in walls:
		var sz: Vector3 = w[0] + Vector3(0, 3, 0)  # 3 m foundation into the hill
		var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = sz; mi.mesh = bm
		var m: ShaderMaterial = Buildings.wall_mat.duplicate(); m.set_shader_parameter("half_h", sz.y / 2.0); m.set_shader_parameter("dado", 4.0)
		mi.material_override = m; mi.position = c + w[1] - Vector3(0, 1.5, 0); add_child(mi)
		var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = sz; cs.shape = sh; cs.position = mi.position; body.add_child(cs)
	for x in [-15, 15]:
		for z in [-15, 15]:
			_cannon_mesh(c + Vector3(x, 7.2, z), atan2(float(x), float(z)))
	cannon = _cannon_mesh(c + Vector3(0, 3.6, 9), 0.0)
	var pole := MeshInstance3D.new(); var pm := CylinderMesh.new(); pm.top_radius = 0.06; pm.bottom_radius = 0.08; pm.height = 9
	pole.mesh = pm; pole.material_override = Props.bark; pole.position = c + Vector3(0, 4.5, -2); add_child(pole)
	flag = MeshInstance3D.new(); var fm := BoxMesh.new(); fm.size = Vector3(2.4, 1.5, 0.04); flag.mesh = fm
	var fmat := StandardMaterial3D.new(); fmat.albedo_color = Color(0.75, 0.1, 0.12); flag.material_override = fmat
	flag.position = c + Vector3(1.25, 8.2, -2); add_child(flag)
	flag_zone = Area3D.new(); flag_zone.position = c + Vector3(0, 1, -2)
	var zs := CollisionShape3D.new(); var sp := SphereShape3D.new(); sp.radius = 3.5; zs.shape = sp; flag_zone.add_child(zs); add_child(flag_zone)

func _cannon_mesh(pos: Vector3, yaw: float) -> Node3D:
	var n := Node3D.new(); n.position = pos; n.rotation.y = yaw; add_child(n)
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
	if remaining > 0:
		Hud.msg("%d left" % remaining); return
	if stage == 0: Hud.msg("The column breaks and flees!"); _start_fort()
	elif stage == 1:
		stage = 2; Hud.objective("The walls are yours. Stand at the flag to raise the Asante colours.")
		objective_pos = flag_zone.global_position

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
func _start_ambush() -> void:
	stage = 0
	Hud.objective("Nsamankow, 1824. A British column marches up the red road. Hide in the bush and break it.")
	var kinds := ["british_redcoat", "west_india_regt", "british_redcoat", "west_india_regt", "british_redcoat", "british_redcoat"]
	for i in kinds.size():
		var z := 40.0 - i * 4.0
		_make_enemy(Vector3(world.path_x(z) + randf_range(-2, 2), 0, z), kinds[i])
	objective_pos = Vector3(world.path_x(30), 0, 30)

func _start_fort() -> void:
	stage = 1
	alarm_raised = false
	checkpoint = Vector3(world.path_x(-40), world.height(world.path_x(-40), -40) + 1, -40)
	Hud.objective("Take the hill fort. Silence the cannon crews and clear the walls.")
	Audio.say("yenko", 0.0)
	var c := Vector3(World.FORT.x, world.fort_top, World.FORT.y)
	objective_pos = c
	var posts := [[Vector3(-4, 3.2, 9), "british_redcoat"], [Vector3(4, 3.2, 9), "west_india_regt"], [Vector3(-8, 0.1, 4), "british_redcoat"],
		[Vector3(8, 0.1, -4), "west_india_regt"], [Vector3(-15, 7.1, -15), "british_redcoat"], [Vector3(15, 7.1, 15), "british_redcoat"]]
	for p in posts: _make_enemy(c + p[0] + Vector3(0, 0.5, 0), p[1], true)

func _process(dt: float) -> void:
	if get_tree().paused or not player: return
	if not gorilla_out: gorilla_charge = min(1.0, gorilla_charge + dt / 80.0)
	if stage == 0 and remaining > 0:  # objective marker follows the column
		for e in get_tree().get_nodes_in_group("enemy"): objective_pos = e.global_position; break
	if stage == 1 and cannon:
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
	if stage == 2 and player in flag_zone.get_overlapping_bodies():
		capture += dt; Hud.msg("Raising the colours... %d%%" % int(capture / 5.0 * 100))
		if capture >= 5.0:
			stage = 3
			flag.material_override.albedo_color = Color(0.85, 0.66, 0.12)
			Hud.objective("Fort taken.")
			Audio.play("talking_drum", null, 0, 0.0)
			Audio.say("asaaka", 0.0)
			await get_tree().create_timer(2.5).timeout
			hud.show_end("PIAW!  FORT TAKEN")

func _on_died() -> void:
	Audio.say("wasei", 0.0)
	Hud.objective("You fell. Back to the last checkpoint...")
	await get_tree().create_timer(1.5).timeout
	player.hp = 100; player.position = checkpoint; player.velocity = Vector3.ZERO
