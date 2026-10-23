class_name Fx
## Black-powder smoke and muzzle flashes.
static var _smoke_mat: StandardMaterial3D

static func smoke(parent: Node, pos: Vector3, size := 1.0) -> void:
	if not _smoke_mat:
		_smoke_mat = StandardMaterial3D.new()
		_smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_smoke_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_smoke_mat.vertex_color_use_as_albedo = true
	var p := CPUParticles3D.new()
	var q := QuadMesh.new(); q.size = Vector2.ONE * 0.6 * size; q.material = _smoke_mat
	p.mesh = q; p.amount = 14; p.lifetime = 2.2; p.one_shot = true; p.explosiveness = 0.9
	p.direction = Vector3(0, 0.3, -1); p.spread = 25; p.initial_velocity_min = 0.5; p.initial_velocity_max = 2.0
	p.gravity = Vector3(0, 0.35, 0); p.damping_min = 1.0; p.damping_max = 2.0
	p.scale_amount_min = 1.0; p.scale_amount_max = 3.0
	var g := Gradient.new(); g.set_color(0, Color(0.85, 0.85, 0.82, 0.7)); g.set_color(1, Color(0.8, 0.8, 0.8, 0.0))
	p.color_ramp = g
	parent.add_child(p); p.global_position = pos; p.emitting = true
	p.get_tree().create_timer(2.6).timeout.connect(p.queue_free)

static func flash(parent: Node, pos: Vector3) -> void:
	var l := OmniLight3D.new(); l.light_color = Color(1, 0.75, 0.4); l.light_energy = 4.0; l.omni_range = 6.0
	parent.add_child(l); l.global_position = pos
	l.get_tree().create_timer(0.07).timeout.connect(l.queue_free)
