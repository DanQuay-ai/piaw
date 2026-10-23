extends CharacterBody3D
## European soldier. Patrols, spots the player (stealth-aware), fires Brown Bess volleys.
var hp := Game.enemy_hp()
var alerted := false
var loaded := true
var dead := false
var home: Vector3
var patrol := Vector3.ZERO
var static_post := false
var model: Node3D
var kind := "british_redcoat"
@onready var eye: RayCast3D = $Eye

func _ready() -> void:
	add_to_group("enemy"); home = global_position
	if Characters.exists(kind):
		model = Characters.spawn(kind); add_child(model)
	else:
		var mi := MeshInstance3D.new(); mi.mesh = CapsuleMesh.new(); mi.position.y = 1
		var m := StandardMaterial3D.new(); m.albedo_color = Color(0.75, 0.1, 0.1); mi.material_override = m; add_child(mi)

func hurt(d: float) -> void:
	if dead: return
	hp -= d; alerted = true
	if hp <= 0:
		dead = true; remove_from_group("enemy")
		collision_layer = 0; collision_mask = 1
		Characters.play(model, "")
		var tw := create_tween()
		tw.tween_property(self, "rotation:x", -PI / 2, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(self, "position:y", position.y + 0.25, 0.45)
		Main.inst.enemy_down()

func _physics_process(dt: float) -> void:
	if dead: return
	var p = get_tree().get_first_node_in_group("player")
	if not p: return
	var to: Vector3 = p.global_position - global_position
	var dist := to.length()
	var sees := false
	var sight: float = Game.enemy_sight() * p.stealth()
	if dist < sight or (alerted and dist < 70.0):
		eye.target_position = eye.to_local(p.global_position + Vector3.UP * 1.2)
		eye.force_raycast_update()
		sees = eye.get_collider() == p
	if sees:
		if not alerted:
			alerted = true; Hud.msg("Spotted! A redcoat raises his musket")
			for e in get_tree().get_nodes_in_group("enemy"):  # shout alerts neighbours
				if e.global_position.distance_to(global_position) < 25.0: e.alerted = true
		look_at(Vector3(p.global_position.x, global_position.y, p.global_position.z))
		velocity.x = 0; velocity.z = 0
		Characters.play(model, "")
		if loaded: _shoot(p, dist)
	elif not static_post:
		var target := patrol
		if alerted and dist < 70.0: target = p.global_position  # hunt
		if not alerted and (patrol == Vector3.ZERO or global_position.distance_to(patrol) < 1.5):
			patrol = home + Vector3(randf_range(-10, 10), 0, randf_range(-10, 10)); target = patrol
		var d := target - global_position; d.y = 0
		var spd := 3.2 if alerted else 1.4
		velocity.x = d.normalized().x * spd; velocity.z = d.normalized().z * spd
		if d.length() > 0.2: look_at(global_position + d)
		Characters.play(model, "run" if alerted else "walk")
	else:
		Characters.play(model, "")
	if not is_on_floor(): velocity.y -= 18 * dt
	move_and_slide()

func _shoot(p, dist: float) -> void:
	loaded = false
	await get_tree().create_timer(randf_range(0.7, 1.5)).timeout  # aim
	if dead or not is_inside_tree(): return
	var muzzle := global_position + Vector3.UP * 1.5 - global_basis.z * 0.9
	Fx.smoke(get_parent(), muzzle, 1.2); Fx.flash(get_parent(), muzzle)
	var chance: float = Game.enemy_accuracy() * p.stealth() * clampf(1.5 - dist / 40.0, 0.2, 1.2)
	if randf() < chance: p.hurt(34)
	else: Hud.msg("A musket ball whizzes past")
	await get_tree().create_timer(randf_range(4.5, 6.5)).timeout  # Brown Bess reload
	loaded = true
