extends CharacterBody3D
## Placeholder redcoat. Swap the mesh for the Meshy model later.
var hp := Game.enemy_hp()
var alerted := false
var loaded := true
var dead := false
var home: Vector3
var patrol := Vector3.ZERO
var static_post := false
@onready var eye: RayCast3D = $Eye

func _ready() -> void:
	add_to_group("enemy"); home = global_position

func hurt(d: float) -> void:
	if dead: return
	hp -= d; alerted = true
	if hp <= 0:
		dead = true; remove_from_group("enemy")
		rotation.x = -PI / 2; position.y = 0.3
		collision_layer = 0
		get_parent().get_parent().enemy_down()

func _physics_process(dt: float) -> void:
	if dead: return
	var p = get_tree().get_first_node_in_group("player")
	if not p: return
	var to: Vector3 = p.global_position - global_position
	var dist := to.length()
	var sees := false
	if dist < Game.enemy_sight() * p.stealth() or (alerted and dist < 60):
		eye.target_position = eye.to_local(p.global_position + Vector3.UP * 1.2)
		eye.force_raycast_update()
		sees = eye.get_collider() == p
	if sees:
		if not alerted: alerted = true; Hud.msg("You've been spotted!")
		look_at(Vector3(p.global_position.x, global_position.y, p.global_position.z))
		velocity = Vector3.ZERO
		if loaded: _shoot(p, dist)
	elif not static_post:
		if patrol == Vector3.ZERO or global_position.distance_to(patrol) < 1.0:
			patrol = home + Vector3(randf_range(-8, 8), 0, randf_range(-8, 8))
		var d := (patrol - global_position); d.y = 0
		velocity = d.normalized() * (3.0 if alerted else 1.5)
		if d.length() > 0.1: look_at(global_position + d)
	if not is_on_floor(): velocity.y -= 18 * dt
	move_and_slide()

func _shoot(p, dist: float) -> void:
	loaded = false
	await get_tree().create_timer(randf_range(0.6, 1.4)).timeout  # aim time
	if dead: return
	var chance: float = Game.enemy_accuracy() * p.stealth() * clamp(1.5 - dist / 40.0, 0.2, 1.2)
	if randf() < chance: p.hurt(34)
	else: Hud.msg("A musket ball whizzes past")
	await get_tree().create_timer(randf_range(4.0, 6.0)).timeout  # Brown Bess reload
	loaded = true
