extends Node3D
## Bonus: the forest's answer to a whistle. Charges, mauls up to 3 soldiers, then melts back into the bush.
var model: Node3D
var target: Node3D
var kills := 0
var state := "arrive"
var t := 0.0
var life := 22.0

func _ready() -> void:
	if Characters.exists("gorilla"):
		model = Characters.spawn("gorilla"); model.scale = Vector3.ONE * 1.15; add_child(model)
	Audio.play("gorilla_roar", global_position, 4)
	Audio.say("grrr_baow", 0.0)
	_pick()

func _pick() -> void:
	target = null
	var best := 45.0
	for e in get_tree().get_nodes_in_group("enemy"):
		var d: float = e.global_position.distance_to(global_position)
		if d < best: best = d; target = e

func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, World.inst.height(p.x, p.z) - 0.05, p.z)

func _process(dt: float) -> void:
	life -= dt; t -= dt
	match state:
		"arrive":
			if not is_instance_valid(target) or target.dead:
				if kills >= 3 or life < 0: state = "leave"
				else:
					_pick()
					if not target: state = "leave"
				return
			var d: Vector3 = target.global_position - global_position; d.y = 0
			if d.length() < 1.8:
				state = "maul"; t = 1.2
				Characters.play(model, "maul", 1.2, true)
				Audio.play("gorilla_maul", global_position, 2)
				target.alert(); target.busy = 2.0
			else:
				global_position = _ground(global_position + d.normalized() * 9.0 * dt)
				look_at(global_position + d)
				Characters.play(model, "run", 1.3)
				if d.length() < 12.0 and kills == 0: Audio.say("off_gorilla", 30.0)
		"maul":
			if t <= 0:
				if is_instance_valid(target) and not target.dead: target.die(true)
				kills += 1
				state = "roar"; t = 1.4
				Characters.play(model, "roar", 1.0, true)
				Audio.play("gorilla_roar", global_position, 0)
		"roar":
			if t <= 0: state = "arrive" if kills < 3 and life > 0 else "leave"
		"leave":
			var p = get_tree().get_first_node_in_group("player")
			var away: Vector3 = (global_position - p.global_position) if p else Vector3.FORWARD
			away.y = 0
			global_position = _ground(global_position + away.normalized() * 8.0 * dt)
			look_at(global_position + away)
			Characters.play(model, "run", 1.2)
			if p and global_position.distance_to(p.global_position) > 60.0: queue_free()
			if life < -15.0: queue_free()
