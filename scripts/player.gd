extends CharacterBody3D
## First-person Asante warrior: three muskets + two afenas, stealth, whistle for the gorilla.
signal died
var hp := 100.0
var loaded := true
var reloading := false
var reload_t := 0.0
var crouched := false
var sprint_lock := false
var slash_cd := 0.0
var bob := 0.0
var step_t := 0.0
var trauma := 0.0
var aim_enemy := false
var god := false
var bot_input := Vector2.ZERO   # used by the autoplay test bot
const SPEED := 5.0
const PAD_LOOK := 2.8
@onready var cam: Camera3D = $Cam
var gun_i := 0
var blade_i := 0
var guns := {}
var blades := {}
var gun: Node3D
var blade: Node3D
var swap_t := 0.0
var body_model: Node3D

func gun_id() -> String: return Weapons.ORDER_GUNS[gun_i]
func blade_id() -> String: return Weapons.ORDER_BLADES[blade_i]
func gun_stats() -> Dictionary: return Weapons.GUNS[gun_id()]
func blade_stats() -> Dictionary: return Weapons.BLADES[blade_id()]

func _ready() -> void:
	add_to_group("player")
	floor_max_angle = deg_to_rad(55.0)
	floor_snap_length = 0.4
	for id in Weapons.ORDER_GUNS:
		var g := Weapons.model(id, Weapons.GUNS[id].len, Weapons.GUNS[id].flip)
		g.visible = false; cam.add_child(g); guns[id] = g
	for id in Weapons.ORDER_BLADES:
		var b := Weapons.model(id, Weapons.BLADES[id].len, Weapons.BLADES[id].flip)
		b.visible = false; cam.add_child(b); blades[id] = b
	# full body that only casts a shadow, so you see a warrior on the ground, not a floating gun
	if Characters.exists("asante_batakari"):
		body_model = Characters.spawn("asante_batakari"); add_child(body_model)
		for mi in body_model.find_children("*", "MeshInstance3D", true, false):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	_equip()

func _equip() -> void:
	for g in guns.values(): g.visible = false
	gun = guns[gun_id()]; gun.visible = true
	gun.position = Vector3(0.2, -0.45, -0.12)
	blade = blades[blade_id()]
	swap_t = 0.35

func shake(amount: float) -> void:
	trauma = min(1.0, trauma + amount * Settings.shake)

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not Hud.touch_mode:
		_look(e.relative * 0.0025 * Settings.mouse_sens * (0.5 if Input.is_action_pressed("aim") else 1.0))

func _look(d: Vector2) -> void:
	if Settings.invert_y: d.y = -d.y
	rotate_y(-d.x)
	cam.rotation.x = clamp(cam.rotation.x - d.y, -1.35, 1.35)

func stealth() -> float:
	## 1.0 = fully visible. Bushes, crouching, standing still all help.
	var s := 1.0
	if crouched: s *= 0.6
	if World.inst and World.inst.is_hidden_spot(global_position): s *= 0.45
	if Vector2(velocity.x, velocity.z).length() < 0.3: s *= 0.8
	return s

func reload_progress() -> float:
	return clampf(1.0 - reload_t / float(gun_stats().reload), 0.0, 1.0)

func _physics_process(dt: float) -> void:
	var aim := Input.is_action_pressed("aim")
	var stick := Vector2(Input.get_axis("look_l", "look_r"), Input.get_axis("look_u", "look_d"))
	if stick.length() > 0.12: _look(stick * stick.length() * PAD_LOOK * Settings.pad_sens * dt * (0.45 if aim else 1.0))
	if Hud.look_delta != Vector2.ZERO:
		_look(Hud.look_delta * 0.006 * Settings.mouse_sens); Hud.look_delta = Vector2.ZERO
	if Input.is_action_just_pressed("crouch"): crouched = not crouched
	if Input.is_action_just_pressed("swap_gun") and not reloading:
		gun_i = (gun_i + 1) % Weapons.ORDER_GUNS.size(); loaded = true; _equip()
		Hud.msg(gun_stats().name)
	if Input.is_action_just_pressed("swap_blade"):
		blade_i = (blade_i + 1) % Weapons.ORDER_BLADES.size(); _equip(); Hud.msg(blade_stats().name)
	if Input.is_action_just_pressed("whistle"): Main.inst.whistle()
	var inp := Input.get_vector("move_l", "move_r", "move_f", "move_b")
	if bot_input != Vector2.ZERO: inp = bot_input
	# L3 / Shift: click to sprint, stays on until you stop or aim
	if Input.is_action_just_pressed("sprint"): sprint_lock = not sprint_lock
	if inp.length() < 0.2 or aim or inp.y > 0.1: sprint_lock = false
	var dir := (transform.basis * Vector3(inp.x, 0, inp.y))
	var sprint := (sprint_lock or Input.is_action_pressed("sprint")) and not aim and inp.y < -0.2
	if sprint and crouched: crouched = false
	var spd := SPEED * (0.5 if crouched else (1.65 if sprint else 1.0)) * (0.6 if aim else 1.0)
	if global_position.y < World.WATER - 0.2: spd *= 0.6  # wading
	velocity.x = dir.x * spd; velocity.z = dir.z * spd
	if not is_on_floor(): velocity.y -= 18 * dt
	elif Input.is_action_just_pressed("jump"):
		if crouched: crouched = false
		else: velocity.y = 6
	move_and_slide()
	var moving := Vector2(velocity.x, velocity.z).length()
	bob += dt * moving * 1.6
	step_t -= dt * moving
	if step_t <= 0 and is_on_floor() and moving > 0.5:
		step_t = 2.2; Audio.play("footstep_leaves", null, -18 if crouched else -11, 0.15)
	if body_model:
		Characters.play(body_model, ("sneak" if crouched else ("run" if sprint else "walk")) if moving > 0.4 else "idle", 1.0 if not sprint else 1.2)
	# camera: crouch height, bob, zoom, shake
	cam.position.y = lerp(cam.position.y, (0.95 if crouched else 1.62) + sin(bob) * 0.03 * min(moving, 1.0), 10 * dt)
	cam.fov = lerp(cam.fov, float(gun_stats().zoom) if aim else (80.0 if sprint else 75.0), 10 * dt)
	trauma = max(trauma - dt * 1.6, 0.0)
	var t2 := trauma * trauma
	cam.h_offset = randf_range(-1, 1) * 0.06 * t2; cam.v_offset = randf_range(-1, 1) * 0.06 * t2
	cam.rotation.z = randf_range(-1, 1) * 0.05 * t2
	# viewmodel: hip vs. aimed down the barrel, sway, reload dip, swap raise
	swap_t = max(swap_t - dt, 0.0)
	var gp := Vector3(0.0, -0.11, -0.02) if aim else Vector3(0.2, -0.22, -0.12)
	gp += Vector3(cos(bob * 0.5) * 0.012, sin(bob) * 0.01, 0) + Vector3(0, -swap_t * 0.6, 0)
	if sprint: gp += Vector3(-0.05, -0.06, 0.05)
	gun.position = gun.position.lerp(gp, 12 * dt)
	var grot := Vector3(0, 0.06 if not aim else 0.0, 0.35 if sprint else 0.0)
	if reloading:
		reload_t -= dt
		grot = Vector3(0.9, 0.5, -0.4)
		if reload_t <= 0: reloading = false; loaded = true
	gun.rotation = gun.rotation.lerp(grot, 8 * dt)
	# red marker when the barrel is on an enemy
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position - cam.global_basis.z * float(gun_stats().range))
	q.exclude = [get_rid()]
	var h := get_world_3d().direct_space_state.intersect_ray(q)
	aim_enemy = h and h.collider.is_in_group("enemy")
	slash_cd -= dt
	if Input.is_action_just_pressed("fire"): _fire()
	if Input.is_action_just_pressed("reload"): _reload()
	if Input.is_action_just_pressed("slash"): _slash()

func body_part(e: Node3D, hit_pos: Vector3) -> String:
	var local: Vector3 = e.global_transform.affine_inverse() * hit_pos
	var y := local.y
	if y > 1.6: return "forehead"
	if y > 1.47: return "face"
	if y > 1.36: return "neck"
	if abs(local.x) > 0.26 and y > 0.85: return "left arm" if local.x > 0 else "right arm"
	if y > 1.05: return "chest"
	if y > 0.82: return "stomach"
	if y > 0.5: return "thigh"
	return "knee"

const PART_MULT := {"forehead": 4.0, "face": 3.0, "neck": 2.2, "chest": 1.0, "stomach": 0.9, "left arm": 0.5, "right arm": 0.5, "thigh": 0.6, "knee": 0.5}
const PART_PTS := {"forehead": 150, "face": 130, "neck": 120, "chest": 100, "stomach": 80, "left arm": 50, "right arm": 50, "thigh": 60, "knee": 60}

func _fire() -> void:
	if not loaded or reloading:
		if not reloading: _reload()
		return
	loaded = false
	var st := gun_stats()
	var muzzle: Vector3 = gun.global_position + (-cam.global_basis.z) * float(st.len) * 0.6
	Fx.smoke(get_parent(), muzzle, 1.6 if st.pellets > 1 else 1.3)
	Fx.flash(get_parent(), muzzle); Fx.muzzle(get_parent(), muzzle, -cam.global_basis.z)
	Hud.shot_flash()
	Audio.play("musket_shot", null, -2)
	Main.inst.noise_at(global_position, 45.0)
	cam.rotation.x += 0.07 if st.pellets == 1 else 0.11
	shake(0.45 if st.pellets == 1 else 0.6)
	var space := get_world_3d().direct_space_state
	var best := {}  # enemy -> [part, dmg]
	for i in int(st.pellets):
		var dirv: Vector3 = (-cam.global_basis.z + cam.global_basis.x * randf_range(-st.spread, st.spread) + cam.global_basis.y * randf_range(-st.spread, st.spread)).normalized()
		var q := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position + dirv * float(st.range))
		q.exclude = [get_rid()]
		var h := space.intersect_ray(q)
		if not h: continue
		if h.collider.is_in_group("enemy"):
			var part := body_part(h.collider, h.position)
			Fx.impact(get_parent(), h.position, h.normal, true)
			var d: float = float(st.dmg) * PART_MULT[part]
			if best.has(h.collider): best[h.collider][1] += d
			else: best[h.collider] = [part, d]
		else:
			Fx.impact(get_parent(), h.position, h.normal, false)
	for e in best:
		var part: String = best[e][0]
		var was_alerted: bool = e.alerted
		var killed: bool = e.hurt(best[e][1], false)
		var pts: int = PART_PTS[part] + (50 if not was_alerted else 0)
		Main.inst.score_hit(e, "You shot the %s in the %s" % [Main.inst.enemy_name(e), part], pts if killed else pts / 3, killed, part == "forehead" or part == "face")
		Hud.hit()
	_reload()

func _reload() -> void:
	if loaded or reloading: return
	reloading = true; reload_t = float(gun_stats().reload)
	Audio.play("reload", null, -6)

func _slash() -> void:
	## Afena: instant kill on an unaware enemy, heavy damage otherwise
	var st := blade_stats()
	if slash_cd > 0: return
	slash_cd = float(st.cd)
	gun.visible = false; blade.visible = true
	Audio.play("afena_swing", null, -4)
	blade.position = Vector3(0.3, -0.1, -0.15)
	blade.rotation = Vector3(0.2, 0.0, 1.2)
	var tw := create_tween()
	tw.tween_property(blade, "rotation", Vector3(-0.6, 0.9, -0.9), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(blade, "position", Vector3(-0.25, -0.3, -0.2), 0.2)
	tw.tween_interval(0.1)
	tw.tween_callback(func(): blade.visible = false; gun.visible = true)
	for e in get_tree().get_nodes_in_group("enemy"):
		var to: Vector3 = e.global_position - global_position
		if to.length() < float(st.reach) and (-cam.global_basis.z).dot(to.normalized()) > 0.35:
			var silent: bool = not e.alerted
			var killed: bool = e.hurt(999.0 if silent else float(st.dmg), true)
			Hud.hit(); shake(0.35)
			Fx.impact(get_parent(), e.global_position + Vector3.UP * 1.3, -to.normalized(), true)
			Audio.play("afena_hit", e.global_position, 0)
			var txt := ("Silent afena kill on the %s" if silent else "You cut the %s with the afena") % Main.inst.enemy_name(e)
			Main.inst.score_hit(e, txt, (200 if silent else 120) if killed else 40, killed, false)

func hurt(d: float, _melee := false) -> void:
	if god: return
	hp -= d
	Hud.damage(); shake(0.7)
	Audio.play("hurt_grunt", null, -4)
	if hp <= 0:
		hp = 0; died.emit()
