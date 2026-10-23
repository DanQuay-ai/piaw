extends CharacterBody3D
## First-person Asante warrior: three muskets + two afenas, stealth, whistle for the gorilla.
signal died
var hp := 100.0
var loaded := true
var reloading := false
var reload_t := 0.0
var crouched := false
var slash_cd := 0.0
var bob := 0.0
var step_t := 0.0
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

func gun_id() -> String: return Weapons.ORDER_GUNS[gun_i]
func blade_id() -> String: return Weapons.ORDER_BLADES[blade_i]
func gun_stats() -> Dictionary: return Weapons.GUNS[gun_id()]
func blade_stats() -> Dictionary: return Weapons.BLADES[blade_id()]

func _ready() -> void:
	add_to_group("player")
	for id in Weapons.ORDER_GUNS:
		var g := Weapons.model(id, Weapons.GUNS[id].len, Weapons.GUNS[id].flip)
		g.visible = false; cam.add_child(g); guns[id] = g
	for id in Weapons.ORDER_BLADES:
		var b := Weapons.model(id, Weapons.BLADES[id].len, Weapons.BLADES[id].flip)
		b.visible = false; cam.add_child(b); blades[id] = b
	_equip()

func _equip() -> void:
	for g in guns.values(): g.visible = false
	gun = guns[gun_id()]; gun.visible = true
	gun.position = Vector3(0.2, -0.45, -0.12)
	blade = blades[blade_id()]
	swap_t = 0.35

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not Hud.touch_mode:
		_look(e.relative * 0.0025 * (0.5 if Input.is_action_pressed("aim") else 1.0))

func _look(d: Vector2) -> void:
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
	if stick.length() > 0.12: _look(stick * stick.length() * PAD_LOOK * dt * (0.45 if aim else 1.0))
	if Hud.look_delta != Vector2.ZERO:
		_look(Hud.look_delta * 0.006); Hud.look_delta = Vector2.ZERO
	if Input.is_action_just_pressed("crouch"): crouched = not crouched
	if Input.is_action_just_pressed("swap_gun") and not reloading:
		gun_i = (gun_i + 1) % Weapons.ORDER_GUNS.size(); loaded = true; _equip()
		Hud.msg(gun_stats().name)
	if Input.is_action_just_pressed("swap_blade"):
		blade_i = (blade_i + 1) % Weapons.ORDER_BLADES.size(); _equip(); Hud.msg(blade_stats().name)
	if Input.is_action_just_pressed("whistle"): Main.inst.whistle()
	var inp := Input.get_vector("move_l", "move_r", "move_f", "move_b")
	var dir := (transform.basis * Vector3(inp.x, 0, inp.y))
	var sprint := Input.is_action_pressed("sprint") and not aim and inp.y < -0.2
	if sprint and crouched: crouched = false
	var spd := SPEED * (0.5 if crouched else (1.6 if sprint else 1.0)) * (0.6 if aim else 1.0)
	if global_position.y < World.WATER - 0.2: spd *= 0.55  # wading
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
	cam.position.y = lerp(cam.position.y, (0.95 if crouched else 1.62) + sin(bob) * 0.03 * min(moving, 1.0), 10 * dt)
	cam.fov = lerp(cam.fov, float(gun_stats().zoom) if aim else 75.0, 10 * dt)
	# viewmodel: hip vs. aimed down the barrel, sway, reload dip, swap raise
	swap_t = max(swap_t - dt, 0.0)
	var gp := Vector3(0.0, -0.11, -0.02) if aim else Vector3(0.2, -0.22, -0.12)
	gp += Vector3(cos(bob * 0.5) * 0.012, sin(bob) * 0.01, 0) + Vector3(0, -swap_t * 0.6, 0)
	gun.position = gun.position.lerp(gp, 12 * dt)
	var grot := Vector3(0, 0.06 if not aim else 0.0, 0)
	if reloading:
		reload_t -= dt
		grot = Vector3(0.9, 0.5, -0.4)
		if reload_t <= 0: reloading = false; loaded = true
	gun.rotation = gun.rotation.lerp(grot, 8 * dt)
	slash_cd -= dt
	if Input.is_action_just_pressed("fire"): _fire()
	if Input.is_action_just_pressed("reload"): _reload()
	if Input.is_action_just_pressed("slash"): _slash()

func _fire() -> void:
	if not loaded or reloading:
		if not reloading: _reload()
		return
	loaded = false
	var st := gun_stats()
	var muzzle: Vector3 = gun.global_position + (-cam.global_basis.z) * float(st.len) * 0.6
	Fx.smoke(get_parent(), muzzle, 1.6 if st.pellets > 1 else 1.3)
	Fx.flash(get_parent(), muzzle)
	Audio.play("musket_shot", null, -2)
	Main.inst.noise_at(global_position, 45.0)
	cam.rotation.x += 0.07
	var space := get_world_3d().direct_space_state
	var hit_any := false
	for i in int(st.pellets):
		var dirv: Vector3 = (-cam.global_basis.z + cam.global_basis.x * randf_range(-st.spread, st.spread) + cam.global_basis.y * randf_range(-st.spread, st.spread)).normalized()
		var q := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position + dirv * float(st.range))
		q.exclude = [get_rid()]
		var h := space.intersect_ray(q)
		if h and h.collider.has_method("hurt"):
			h.collider.hurt(float(st.dmg)); hit_any = true
	if hit_any: Hud.hit()
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
			e.hurt(999.0 if not e.alerted else float(st.dmg), true); Hud.hit()
			Audio.play("afena_hit", e.global_position, 0)

func hurt(d: float, _melee := false) -> void:
	hp -= d
	Hud.damage()
	Audio.play("hurt_grunt", null, -4)
	if hp <= 0:
		hp = 0; died.emit()
