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

## Bullet impact: blood mist on flesh, dust/splinters elsewhere.
static func impact(parent: Node, pos: Vector3, normal: Vector3, flesh: bool) -> void:
	var p := CPUParticles3D.new()
	var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED; m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.vertex_color_use_as_albedo = true
	var q := QuadMesh.new(); q.size = Vector2.ONE * (0.12 if flesh else 0.18); q.material = m
	p.mesh = q; p.amount = 16 if flesh else 12; p.lifetime = 0.6 if flesh else 0.9; p.one_shot = true; p.explosiveness = 1.0
	p.direction = normal if normal != Vector3.ZERO else Vector3.UP; p.spread = 35
	p.initial_velocity_min = 1.5; p.initial_velocity_max = 4.0; p.gravity = Vector3(0, -9, 0)
	p.scale_amount_min = 0.6; p.scale_amount_max = 1.8
	var g := Gradient.new()
	if flesh: g.set_color(0, Color(0.55, 0.02, 0.02, 0.95)); g.set_color(1, Color(0.3, 0.0, 0.0, 0.0))
	else: g.set_color(0, Color(0.55, 0.35, 0.22, 0.9)); g.set_color(1, Color(0.5, 0.4, 0.3, 0.0))
	p.color_ramp = g
	parent.add_child(p); p.global_position = pos; p.emitting = true
	p.get_tree().create_timer(1.2).timeout.connect(p.queue_free)

## Short flame burst at the barrel tip.
static func muzzle(parent: Node, pos: Vector3, dir: Vector3) -> void:
	var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED; m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.75, 0.35, 0.9); m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var mi := MeshInstance3D.new(); var q := QuadMesh.new(); q.size = Vector2(0.35, 0.35); mi.mesh = q; mi.material_override = m
	parent.add_child(mi); mi.global_position = pos + dir * 0.15
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.get_tree().create_timer(0.05).timeout.connect(mi.queue_free)
