extends SceneTree
## Autoplay test for every mission: walks to each objective with real physics, clears enemies near it.
## godot --headless --fixed-fps 60 --path . -s tools/bot.gd -- <mission_id>
var f := 0
var t := 0.0
var best_d := INF
var stall := 0.0
var nudges := 0
var last_target := Vector3.ZERO
var m
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	Main.mission_id = args[0] if args.size() > 0 else "nsamankow"
	change_scene_to_file("res://scenes/main.tscn")
func _physics_process(dt: float) -> bool:
	f += 1
	m = Main.inst
	if f == 5:
		m.hud.show_game(); m._begin_stage(0); m.player.god = true
		print("BOT ", Main.mission_id, " start ", m.player.global_position)
	if f < 6: return false
	t += dt
	var p = m.player
	for e in m.get_tree().get_nodes_in_group("enemy"):
		if e.global_position.distance_to(p.global_position) < 22.0: e.die(false)
	if m.stage >= m.stages.size() or m.hud.menus.current == "end":
		print("BOT SUCCESS %s in %.0fs, nudges %d" % [Main.mission_id, t, nudges]); return true
	var s: Dictionary = m.stages[m.stage]
	var target: Vector3 = m.objective_pos
	if s.type == "waves" and m.remaining > 0:  # go meet the wave
		for e in m.get_tree().get_nodes_in_group("enemy"): target = e.global_position; break
	if target.distance_to(last_target) > 3.0: best_d = INF; stall = 0.0; last_target = target
	var d := Vector2(target.x - p.global_position.x, target.z - p.global_position.z)
	if d.length() < 1.2: p.bot_input = Vector2.ZERO; stall = 0.0; best_d = INF
	else:
		p.rotation.y = atan2(-d.x, -d.y); p.bot_input = Vector2(0, -1)
		if d.length() < best_d - 0.3: best_d = d.length(); stall = 0.0
		else: stall += dt
		if stall > 3.0 and p.is_on_floor(): p.velocity.y = 6.0
		if stall > 12.0:
			nudges += 1; stall = 0.0; best_d = INF
			var q := PhysicsRayQueryParameters3D.create(p.global_position + Vector3.UP * 0.6, p.global_position + Vector3.UP * 0.6 - p.global_basis.z * 2.0); q.exclude = [p.get_rid()]
			var h = p.get_world_3d().direct_space_state.intersect_ray(q)
			var qd := PhysicsRayQueryParameters3D.create(p.global_position + Vector3.UP * 0.5, p.global_position + Vector3.DOWN * 3.0); qd.exclude = [p.get_rid()]
			var hd = p.get_world_3d().direct_space_state.intersect_ray(qd)
			print("BOT vel ", p.velocity, " real ", p.get_real_velocity(), " rot ", p.rotation.y, " inp ", p.bot_input, " crouch ", p.crouched, " paused ", p.get_tree().paused, " menu ", m.hud.menus.current, " proc ", p.can_process())
			var qs := PhysicsShapeQueryParameters3D.new(); var cap := CapsuleShape3D.new(); cap.radius = 0.45; qs.shape = cap
			qs.transform = Transform3D(Basis(), p.global_position + Vector3.UP); qs.exclude = [p.get_rid()]
			for r in p.get_world_3d().direct_space_state.intersect_shape(qs, 8):
				var cs = r.collider.shape_owner_get_owner(r.collider.shape_find_owner(r.shape))
				print("BOT overlap: ", r.collider, " parent ", r.collider.get_parent().name, " shape ", cs, " ", cs.shape if cs else null, " at ", cs.global_position if cs else null)
			if hd: print("BOT below: ", hd.collider, " ", hd.collider.get_parent(), " shape ", hd.shape, " at ", hd.position, " n=", hd.normal)
			for c in p.get_slide_collision_count(): print("BOT slide: ", p.get_slide_collision(c).get_collider(), " n=", p.get_slide_collision(c).get_normal())
			var what := "nothing"
			if h: what = "%s shape#%d at %s" % [h.collider.get_class(), h.shape, h.position]
			print("BOT nudge at ", p.global_position, " stage ", m.stage, " -> ", target, " blocked by ", what, " floor=", p.is_on_floor())
			var np: Vector3 = p.global_position + Vector3(d.normalized().x, 0, d.normalized().y) * 8.0
			np.y = max(World.inst.height(np.x, np.z), p.global_position.y) + 4.0
			p.global_position = np; p.velocity = Vector3.ZERO
	if fmod(t, 30.0) < dt: print("BOT t=%d stage=%d remaining=%d waves=%d pos=%s" % [t, m.stage, m.remaining, m.waves_left.size(), p.global_position])
	if t > 500: print("BOT FAIL timeout ", Main.mission_id, " stage ", m.stage); return true
	return false
