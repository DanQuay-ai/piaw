extends CharacterBody3D
## First-person Asante warrior: Dane gun (1 shot, slow reload) + afena.
signal died
var hp := 100.0
var loaded := true
var reloading := false
var reload_t := 0.0
const RELOAD := 3.0
var crouched := false
var slash_cd := 0.0
var bob := 0.0
const SPEED := 5.0
const PAD_LOOK := 2.8
@onready var cam: Camera3D = $Cam
@onready var ray: RayCast3D = $Cam/Ray
var gun: Node3D
var blade: Node3D

func _ready() -> void:
	add_to_group("player")
	_viewmodel()

func _viewmodel() -> void:
	gun = Node3D.new(); cam.add_child(gun); gun.position = Vector3(0.2, -0.2, -0.32)
	var stock := MeshInstance3D.new(); var sb := BoxMesh.new(); sb.size = Vector3(0.05, 0.075, 0.5); stock.mesh = sb
	stock.material_override = Props.bark; stock.position.z = 0.05; gun.add_child(stock)
	var barrel := MeshInstance3D.new(); var cb := CylinderMesh.new(); cb.top_radius = 0.018; cb.bottom_radius = 0.022; cb.height = 0.8; cb.radial_segments = 8
	barrel.mesh = cb; barrel.rotation.x = PI / 2; barrel.position = Vector3(0, 0.03, -0.6)
	var steel := StandardMaterial3D.new(); steel.albedo_color = Color(0.2, 0.2, 0.22); steel.metallic = 0.8; steel.roughness = 0.35
	barrel.material_override = steel; gun.add_child(barrel)
	var band := MeshInstance3D.new(); var bb := BoxMesh.new(); bb.size = Vector3(0.055, 0.08, 0.025); band.mesh = bb
	var brass := StandardMaterial3D.new(); brass.albedo_color = Color(0.75, 0.55, 0.2); brass.metallic = 0.9; brass.roughness = 0.3
	band.material_override = brass; band.position.z = -0.3; gun.add_child(band)
	# afena: curved iron blade, gold-wrapped hilt
	blade = Node3D.new(); cam.add_child(blade); blade.position = Vector3(-0.35, -0.3, -0.5); blade.visible = false
	for i in 4:
		var seg := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.012, 0.09 + i * 0.015, 0.16)
		seg.mesh = bm; seg.material_override = steel; seg.position = Vector3(0, 0.02 * i * i, -0.12 - i * 0.15); seg.rotation.x = i * 0.18
		blade.add_child(seg)
	var hilt := MeshInstance3D.new(); var hm := CylinderMesh.new(); hm.top_radius = 0.025; hm.bottom_radius = 0.025; hm.height = 0.16
	hilt.mesh = hm; hilt.material_override = brass; hilt.rotation.x = PI / 2; hilt.position.z = 0.02; blade.add_child(hilt)

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not Hud.touch_mode:
		_look(e.relative * 0.0025 * (0.6 if Input.is_action_pressed("aim") else 1.0))

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
	return clampf(1.0 - reload_t / RELOAD, 0.0, 1.0)

func _physics_process(dt: float) -> void:
	var stick := Vector2(Input.get_axis("look_l", "look_r"), Input.get_axis("look_u", "look_d"))
	if stick.length() > 0.12: _look(stick * stick.length() * PAD_LOOK * dt * (0.5 if Input.is_action_pressed("aim") else 1.0))
	if Hud.look_delta != Vector2.ZERO:
		_look(Hud.look_delta * 0.006); Hud.look_delta = Vector2.ZERO
	if Input.is_action_just_pressed("crouch"): crouched = not crouched
	var aim := Input.is_action_pressed("aim")
	var inp := Input.get_vector("move_l", "move_r", "move_f", "move_b")
	var dir := (transform.basis * Vector3(inp.x, 0, inp.y))
	var sprint := Input.is_action_pressed("sprint") and not crouched and not aim
	if sprint and crouched: crouched = false
	var spd := SPEED * (0.5 if crouched else (1.6 if sprint else 1.0)) * (0.6 if aim else 1.0)
	if global_position.y < World.WATER - 0.2: spd *= 0.55  # wading
	velocity.x = dir.x * spd; velocity.z = dir.z * spd
	if not is_on_floor(): velocity.y -= 18 * dt
	elif Input.is_action_just_pressed("jump"):
		if crouched: crouched = false
		else: velocity.y = 6
	move_and_slide()
	# camera height, fov, head bob, gun sway
	var moving := Vector2(velocity.x, velocity.z).length()
	bob += dt * moving * 1.6
	cam.position.y = lerp(cam.position.y, (0.95 if crouched else 1.62) + sin(bob) * 0.03 * min(moving, 1.0), 10 * dt)
	cam.fov = lerp(cam.fov, 42.0 if aim else 75.0, 10 * dt)
	var gp := Vector3(0.0, -0.12, -0.3) if aim else Vector3(0.2, -0.2, -0.32)
	gun.position = gun.position.lerp(gp + Vector3(cos(bob * 0.5) * 0.01, sin(bob) * 0.008, 0), 12 * dt)
	if reloading:
		reload_t -= dt
		gun.rotation.x = lerp(gun.rotation.x, -0.6, 8 * dt)
		if reload_t <= 0: reloading = false; loaded = true
	else:
		gun.rotation.x = lerp(gun.rotation.x, 0.0, 8 * dt)
	slash_cd -= dt
	if Input.is_action_just_pressed("fire"): _fire()
	if Input.is_action_just_pressed("reload"): _reload()
	if Input.is_action_just_pressed("slash"): _slash()

func _fire() -> void:
	if not loaded or reloading:
		if not reloading: _reload()
		return
	loaded = false
	var muzzle: Vector3 = gun.global_position + (-cam.global_basis.z) * 1.2
	Fx.smoke(get_parent(), muzzle, 1.4)
	Fx.flash(get_parent(), muzzle)
	cam.rotation.x += 0.06  # recoil
	ray.force_raycast_update()
	var c = ray.get_collider()
	if c and c.has_method("hurt"):
		c.hurt(100.0); Hud.hit()
	_reload()

func _reload() -> void:
	if loaded or reloading: return
	reloading = true; reload_t = RELOAD

func _slash() -> void:
	## Afena: instant kill on an unaware enemy, heavy damage otherwise
	if slash_cd > 0: return
	slash_cd = 0.6
	gun.visible = false; blade.visible = true
	var tw := create_tween()
	blade.rotation = Vector3(0.4, 0.9, 0.6)
	tw.tween_property(blade, "rotation", Vector3(-0.3, -0.9, -0.5), 0.18).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func(): blade.visible = false; gun.visible = true).set_delay(0.12)
	for e in get_tree().get_nodes_in_group("enemy"):
		var to: Vector3 = e.global_position - global_position
		if to.length() < 2.6 and (-cam.global_basis.z).dot(to.normalized()) > 0.4:
			e.hurt(999.0 if not e.alerted else 55.0); Hud.hit()

func hurt(d: float) -> void:
	hp -= d
	Hud.damage()
	if hp <= 0:
		hp = 0; died.emit()
