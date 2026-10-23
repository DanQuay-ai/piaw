extends CharacterBody3D
## European soldier. Patrols, hears shots, spots the player (stealth-aware), fires Brown Bess volleys.
var hp := Game.enemy_hp()
var alerted := false
var loaded := true
var busy := 0.0       # time locked in shoot/reload/hit animation
var dead := false
var home: Vector3
var patrol := Vector3.ZERO
var investigate := Vector3.ZERO
var static_post := false
var model: Node3D
var kind := "british_redcoat"
var is_officer := false
@onready var eye: RayCast3D = $Eye

func _ready() -> void:
	add_to_group("enemy"); home = global_position
	if Characters.exists(kind):
		model = Characters.spawn(kind); add_child(model)
	else:
		var mi := MeshInstance3D.new(); mi.mesh = CapsuleMesh.new(); mi.position.y = 1
		var m := StandardMaterial3D.new(); m.albedo_color = Color(0.75, 0.1, 0.1); mi.material_override = m; add_child(mi)

func alert(by_sound := Vector3.ZERO) -> void:
	if dead: return
	if not alerted:
		alerted = true
		Main.inst.on_alert(self)
	if by_sound != Vector3.ZERO: investigate = by_sound

func hurt(d: float, melee := false) -> void:
	if dead: return
	hp -= d
	if hp <= 0:
		die(melee); return
	alert(); busy = 0.5
	Characters.play(model, "hit", 1.0, true)

func die(melee := false) -> void:
	if dead: return
	dead = true; remove_from_group("enemy")
	collision_layer = 0
	Audio.play("redcoat_death", global_position, -2)
	if Characters.has(model, "die"):
		Characters.play(model, "die", 1.0, true)
	else:
		var tw := create_tween()
		tw.tween_property(self, "rotation:x", -PI / 2, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	Main.inst.enemy_down(self, melee)

func _physics_process(dt: float) -> void:
	if dead:
		velocity = Vector3(0, velocity.y - 18 * dt, 0); move_and_slide(); return
	var p = get_tree().get_first_node_in_group("player")
	if not p: return
	busy -= dt
	var to: Vector3 = p.global_position - global_position
	var dist := to.length()
	var sees := false
	var sight: float = Game.enemy_sight() * p.stealth()
	if dist < sight or (alerted and dist < 70.0):
		eye.target_position = eye.to_local(p.global_position + Vector3.UP * 1.2)
		eye.force_raycast_update()
		sees = eye.get_collider() == p
	velocity.x = 0; velocity.z = 0
	if sees:
		if not alerted: alert()
		investigate = p.global_position
		look_at(Vector3(p.global_position.x, global_position.y, p.global_position.z))
		if loaded and busy <= 0: _shoot(p, dist)
		elif busy <= 0: Characters.play(model, "idle")
	elif busy <= 0 and not static_post:
		var target := patrol
		if alerted and investigate != Vector3.ZERO: target = investigate
		elif patrol == Vector3.ZERO or global_position.distance_to(patrol) < 1.5:
			patrol = home + Vector3(randf_range(-10, 10), 0, randf_range(-10, 10)); target = patrol
		var d := target - global_position; d.y = 0
		if d.length() < 1.5 and alerted:
			investigate = Vector3.ZERO; Characters.play(model, "idle")  # lost the trail
			if randf() < 0.01: Audio.say("off_where", 12.0)
		else:
			var spd := 3.4 if alerted else 1.4
			velocity.x = d.normalized().x * spd; velocity.z = d.normalized().z * spd
			if d.length() > 0.2: look_at(global_position + d)
			Characters.play(model, "run" if alerted else "walk")
	elif busy <= 0:
		Characters.play(model, "idle")
	if not is_on_floor(): velocity.y -= 18 * dt
	move_and_slide()

func _shoot(p, dist: float) -> void:
	loaded = false
	busy = 1.6
	Characters.play(model, "shoot", 1.0, true)
	await get_tree().create_timer(randf_range(0.7, 1.4)).timeout  # aim
	if dead or not is_inside_tree(): return
	var muzzle := global_position + Vector3.UP * 1.5 - global_basis.z * 0.9
	Fx.smoke(get_parent(), muzzle, 1.2); Fx.flash(get_parent(), muzzle)
	Audio.play("musket_far" if dist > 25.0 else "musket_shot", muzzle, -4 if dist > 25.0 else -8)
	var chance: float = Game.enemy_accuracy() * p.stealth() * clampf(1.5 - dist / 40.0, 0.2, 1.2)
	if randf() < chance: p.hurt(34)
	await get_tree().create_timer(0.5).timeout
	if dead or not is_inside_tree(): return
	var rl := randf_range(4.5, 6.5)  # Brown Bess reload
	busy = rl if Characters.has(model, "reload") else 0.0
	Characters.play(model, "reload", Characters.length(model, "reload") / rl if Characters.has(model, "reload") else 1.0, true)
	await get_tree().create_timer(rl).timeout
	loaded = true
