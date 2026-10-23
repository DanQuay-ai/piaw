extends Node3D
## Townsperson wandering the Asante neighbourhood.
var model: Node3D
var centre: Vector3
var target: Vector3
var wait := 0.0

func setup(id: String, c: Vector3) -> void:
	centre = c; target = position
	model = Characters.spawn(id); add_child(model)

func _process(dt: float) -> void:
	if wait > 0.0:
		wait -= dt; Characters.play(model, ""); return
	var d := target - position; d.y = 0
	if d.length() < 0.5:
		target = centre + Vector3(randf_range(-3, 3), 0, randf_range(-22, 22)); wait = randf_range(1.0, 5.0); return
	position += d.normalized() * 1.2 * dt
	look_at(position + d)
	Characters.play(model, "walk")
