extends CharacterBody3D
signal died
var hp := 100.0
var loaded := true
var reloading := false
var crouched := false
var in_foliage := 0
var slash_cd := 0.0
const SPEED := 5.0
const LOOK := 2.6
@onready var cam: Camera3D = $Cam
@onready var ray: RayCast3D = $Cam/Ray

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	add_to_group("player")

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look(e.relative * 0.003)
	if e.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

func _look(d: Vector2) -> void:
	rotate_y(-d.x)
	cam.rotation.x = clamp(cam.rotation.x - d.y, -1.4, 1.4)

func stealth() -> float:
	## lower = harder to see. 1.0 standing in open
	var s := 1.0
	if crouched: s *= 0.6
	if in_foliage > 0: s *= 0.45
	return s

func _physics_process(dt: float) -> void:
	var stick := Vector2(Input.get_axis("look_l", "look_r"), Input.get_axis("look_u", "look_d"))
	if stick.length() > 0.1: _look(stick * LOOK * dt)
	crouched = Input.is_action_pressed("crouch")
	cam.position.y = lerp(cam.position.y, 0.9 if crouched else 1.6, 10 * dt)
	var aim := Input.is_action_pressed("aim")
	cam.fov = lerp(cam.fov, 45.0 if aim else 75.0, 10 * dt)
	var inp := Input.get_vector("move_l", "move_r", "move_f", "move_b")
	var dir := (transform.basis * Vector3(inp.x, 0, inp.y)).normalized()
	var spd := SPEED * (0.5 if crouched else (1.6 if Input.is_action_pressed("sprint") else 1.0))
	velocity.x = dir.x * spd; velocity.z = dir.z * spd
	if not is_on_floor(): velocity.y -= 18 * dt
	elif Input.is_action_just_pressed("jump") and not crouched: velocity.y = 6
	move_and_slide()
	slash_cd -= dt
	if Input.is_action_just_pressed("fire"): _fire()
	if Input.is_action_just_pressed("reload"): _reload()
	if Input.is_action_just_pressed("slash"): _slash()

func _fire() -> void:
	if not loaded or reloading: return
	loaded = false
	Hud.msg("BANG")
	ray.force_raycast_update()
	var c = ray.get_collider()
	if c and c.has_method("hurt"): c.hurt(100.0)
	_reload()

func _reload() -> void:
	if loaded or reloading: return
	reloading = true
	Hud.msg("Reloading Dane gun...")
	await get_tree().create_timer(3.0).timeout
	loaded = true; reloading = false

func _slash() -> void:
	## Afena: short range, instant kill from behind/stealth, heavy damage otherwise
	if slash_cd > 0: return
	slash_cd = 0.6
	Hud.msg("Afena!")
	for e in get_tree().get_nodes_in_group("enemy"):
		var to: Vector3 = e.global_position - global_position
		if to.length() < 2.4 and (-cam.global_basis.z).dot(to.normalized()) > 0.5:
			e.hurt(999.0 if not e.alerted else 50.0)

func hurt(d: float) -> void:
	hp -= d
	Hud.msg("Hit! HP %d" % hp)
	if hp <= 0: died.emit()
