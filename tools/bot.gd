extends SceneTree
## Autoplay test: walks the mission route with real physics (no teleport), clears enemies near it,
## and reports whether the mission can be finished.  godot --headless --fixed-fps 60 --path . -s tools/bot.gd
var f := 0
var wps := []
var wi := 0
var best_d := INF
var stall := 0.0
var t := 0.0
var m
func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
func _physics_process(dt: float) -> bool:
	f += 1
	m = Main.inst
	if f == 5:
		m.hud.show_game(); m._start_ambush(); m.player.god = true
		var W = World.inst
		for z in range(90, -80, -6): wps.append(Vector3(W.path_x(z), 0, z))
		var c := Vector3(World.FORT.x, 0, World.FORT.y)
		wps += [c + Vector3(0, 0, 24), c + Vector3(0, 0, 14), c + Vector3(-7, 0, 9), c + Vector3(-6, 0, 0), m.flag_zone.global_position]
		print("BOT start ", m.player.global_position)
	if f < 6: return false
	t += dt
	var p = m.player
	# clear enemies that are close (stands in for a firefight)
	for e in m.get_tree().get_nodes_in_group("enemy"):
		if e.global_position.distance_to(p.global_position) < 22.0: e.die(false)
	if m.stage == 3 or m.hud.menus.current == "end":
		print("BOT SUCCESS mission complete in %.0fs game time, score %d" % [t, m.score]); return true
	if wi >= wps.size():
		p.bot_input = Vector2.ZERO
		if m.stage == 2: return false  # standing on the flag
		if fmod(t, 5.0) < dt: print("BOT waiting stage=%d remaining=%d" % [m.stage, m.remaining])
		if t > 400: print("BOT FAIL timeout at end, stage ", m.stage); return true
		return false
	var target: Vector3 = wps[wi]
	var d := Vector2(target.x - p.global_position.x, target.z - p.global_position.z)
	if d.length() < 2.5:
		wi += 1; best_d = INF; stall = 0.0; return false
	p.rotation.y = atan2(-d.x, -d.y)
	p.bot_input = Vector2(0, -1)
	if d.length() < best_d - 0.3: best_d = d.length(); stall = 0.0
	else: stall += dt
	if stall > 3.0 and p.is_on_floor(): p.velocity.y = 6.0  # hop over small lips
	if stall > 10.0:
		var q := PhysicsRayQueryParameters3D.create(p.global_position + Vector3.UP, p.global_position + Vector3.UP - p.global_basis.z * 3.0); q.exclude = [p.get_rid()]
		var h = p.get_world_3d().direct_space_state.intersect_ray(q)
		print("BOT blocker: ", h.collider if h else "none", " ", h.position if h else "", " floor=", p.is_on_floor(), " ground_h=", World.inst.height(p.global_position.x, p.global_position.z), " fort_top=", World.inst.fort_top)
		print("BOT FAIL stuck at ", p.global_position, " heading to wp ", wi, " ", target, " stage ", m.stage); return true
	if t > 600: print("BOT FAIL timeout"); return true
	return false
