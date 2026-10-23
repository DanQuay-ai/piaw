class_name Props
## Procedural low-poly meshes (PS2/PS3 style). Built once per type, reused through MultiMesh.

static var _noise := FastNoiseLite.new()

static func mat(col: Color, tex: Texture2D = null, tri_scale := 0.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.95
	m.vertex_color_use_as_albedo = true
	if tex:
		m.albedo_texture = tex
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * tri_scale
	return m

static func noise_tex(c1: Color, c2: Color, freq := 0.05, size := 128, cellular := false) -> NoiseTexture2D:
	var t := NoiseTexture2D.new()
	t.width = size; t.height = size; t.seamless = true
	var n := FastNoiseLite.new(); n.frequency = freq
	if cellular: n.noise_type = FastNoiseLite.TYPE_CELLULAR
	n.fractal_octaves = 4
	t.noise = n
	var g := Gradient.new(); g.set_color(0, c1); g.set_color(1, c2)
	t.color_ramp = g
	return t

static func _sphere(r: float, h: float, seg := 8, rings := 5) -> SphereMesh:
	var s := SphereMesh.new(); s.radius = r; s.height = h; s.radial_segments = seg; s.rings = rings; return s
static func _cyl(top: float, bot: float, h: float, seg := 7) -> CylinderMesh:
	var c := CylinderMesh.new(); c.top_radius = top; c.bottom_radius = bot; c.height = h; c.radial_segments = seg; c.rings = 1; return c
static func _box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new(); b.size = s; return b

static func _tf(pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> Transform3D:
	var b := Basis.from_euler(rot).scaled(scl)
	return Transform3D(b, pos)

## groups: Array of [Array[[mesh, transform]], material, jitter]
static func build(groups: Array) -> ArrayMesh:
	var am := ArrayMesh.new()
	for g in groups:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part in g[0]:
			st.append_from(part[0], 0, part[1])
		var arr := st.commit_to_arrays()
		var jit: float = g[2]
		if jit > 0.0:
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			for i in v.size():
				var p := v[i]
				var n := _noise.get_noise_3d(p.x * 9.0, p.y * 9.0, p.z * 9.0)
				v[i] = p + Vector3(n, n * 0.6, -n) * jit
			arr[Mesh.ARRAY_VERTEX] = v
		# brighten tops / darken bottoms (fake AO) through vertex colour
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var cols := PackedColorArray(); cols.resize(verts.size())
		var miny := INF; var maxy := -INF
		for p in verts: miny = min(miny, p.y); maxy = max(maxy, p.y)
		for i in verts.size():
			var t: float = (verts[i].y - miny) / max(maxy - miny, 0.01)
			var k: float = lerp(0.55, 1.1, t)
			cols[i] = Color(k, k, k)
		arr[Mesh.ARRAY_COLOR] = cols
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		am.surface_set_material(am.get_surface_count() - 1, g[1])
	return am

# ---------- materials (shared) ----------
static var bark: StandardMaterial3D
static var leaf: StandardMaterial3D
static var leaf_dark: StandardMaterial3D
static var palm_leaf: StandardMaterial3D
static var grass_blade: StandardMaterial3D
static var rock: StandardMaterial3D
static var laterite: StandardMaterial3D

static func init_materials() -> void:
	bark = mat(Color(0.42, 0.33, 0.25), noise_tex(Color(0.25, 0.2, 0.15), Color(0.6, 0.5, 0.4), 0.15), 1.5)
	leaf = mat(Color(0.62, 0.72, 0.5), noise_tex(Color(0.08, 0.22, 0.06), Color(0.3, 0.5, 0.15), 0.12, 128, true), 0.8)
	leaf_dark = mat(Color(0.55, 0.65, 0.48), noise_tex(Color(0.05, 0.16, 0.05), Color(0.2, 0.38, 0.1), 0.12, 128, true), 0.8)
	palm_leaf = mat(Color(0.72, 0.8, 0.55), noise_tex(Color(0.15, 0.3, 0.08), Color(0.45, 0.55, 0.2), 0.3), 1.0)
	grass_blade = mat(Color(0.7, 0.72, 0.55), noise_tex(Color(0.25, 0.32, 0.1), Color(0.5, 0.48, 0.22), 0.2), 1.0)
	for m in [leaf, leaf_dark, palm_leaf, grass_blade]: m.cull_mode = BaseMaterial3D.CULL_DISABLED
	rock = mat(Color(0.8, 0.78, 0.75), noise_tex(Color(0.3, 0.28, 0.27), Color(0.6, 0.56, 0.5), 0.1), 0.8)
	laterite = mat(Color(1, 1, 1), noise_tex(Color(0.45, 0.17, 0.08), Color(0.7, 0.33, 0.16), 0.1), 0.7)

# ---------- trees ----------
static func ceiba() -> ArrayMesh:  # giant silk-cotton / odum
	var t := []; var l := []
	t.append([_cyl(0.45, 0.8, 18), _tf(Vector3(0, 9, 0))])
	for i in 5:  # buttress roots
		var a := TAU * i / 5.0
		t.append([_box(Vector3(0.18, 3.2, 2.0)), _tf(Vector3(cos(a) * 0.9, 1.4, sin(a) * 0.9), Vector3(0, -a + PI / 2, 0.15))])
	for i in 3:  # branches
		var a := TAU * i / 3.0 + 0.4
		t.append([_cyl(0.12, 0.25, 6), _tf(Vector3(cos(a) * 2.2, 16.5, sin(a) * 2.2), Vector3(sin(a) * 1.0, 0, -cos(a) * 1.0))])
	for p in [Vector3(0, 19, 0), Vector3(3.5, 17.5, 1), Vector3(-3, 18, -2), Vector3(1, 17.8, -3.5), Vector3(-2, 17, 3)]:
		l.append([_sphere(3.6, 3.0, 9, 5), _tf(p)])
	return build([[t, bark, 0.0], [l, leaf_dark, 0.5]])

static func broadleaf() -> ArrayMesh:
	var t := []; var l := []
	t.append([_cyl(0.26, 0.42, 8), _tf(Vector3(0, 4, 0), Vector3(0.05, 0, 0.04))])
	t.append([_cyl(0.08, 0.16, 3.5), _tf(Vector3(0.9, 7, 0), Vector3(0, 0, -0.75))])
	t.append([_cyl(0.07, 0.14, 3.2), _tf(Vector3(-0.8, 7.2, 0.3), Vector3(0.2, 0, 0.7))])
	var rng := RandomNumberGenerator.new(); rng.seed = 3
	for i in 9:
		var a := TAU * i / 9.0
		var r := 0.6 + rng.randf() * 1.8
		l.append([_sphere(rng.randf_range(1.4, 2.2), rng.randf_range(1.4, 2.0), 8, 5), _tf(Vector3(cos(a) * r, 8.0 + rng.randf_range(-0.8, 1.2), sin(a) * r))])
	return build([[t, bark, 0.0], [l, leaf, 0.4]])

static func oil_palm() -> ArrayMesh:
	var t := []; var l := []
	for i in 6:  # ringed trunk segments
		t.append([_cyl(0.26, 0.32, 1.4), _tf(Vector3(0, 0.7 + i * 1.35, 0), Vector3(0, i * 0.5, 0))])
	var top := Vector3(0, 8.2, 0)
	for i in 14:
		var a := TAU * i / 14.0
		var droop := -0.35 - 0.35 * float(i % 3)
		var basis := Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, droop)
		var fwd := basis * Vector3(0, 0, 1)
		l.append([_box(Vector3(0.7, 0.03, 4.2)), Transform3D(basis, top + fwd * 2.0)])
	l.append([_sphere(0.6, 0.9, 6, 3), _tf(top)])
	return build([[t, bark, 0.0], [l, palm_leaf, 0.0]])

static func sapling() -> ArrayMesh:
	var t := [[_cyl(0.07, 0.12, 2.6), _tf(Vector3(0, 1.3, 0))]]
	var l := [[_sphere(1.3, 1.6, 7, 4), _tf(Vector3(0, 3.0, 0))], [_sphere(0.9, 1.1, 6, 4), _tf(Vector3(0.6, 2.6, 0.3))]]
	return build([[t, bark, 0.0], [l, leaf, 0.3]])

# ---------- bushes ----------
static func shrub() -> ArrayMesh:
	var l := []
	for p in [Vector3(0, 0.7, 0), Vector3(0.8, 0.55, 0.3), Vector3(-0.7, 0.5, -0.4), Vector3(0.2, 0.5, -0.8)]:
		l.append([_sphere(0.95, 1.2, 7, 4), _tf(p)])
	return build([[l, leaf, 0.35]])

static func fern() -> ArrayMesh:
	var l := []
	for i in 11:
		var a := TAU * i / 11.0
		var basis := Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, -0.75 - 0.2 * (i % 2))
		l.append([_box(Vector3(0.35, 0.02, 1.7)), Transform3D(basis, basis * Vector3(0, 0, 0.8) + Vector3(0, 0.1, 0))])
	return build([[l, palm_leaf, 0.0]])

static func elephant_grass() -> ArrayMesh:
	var l := []
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	for i in 18:
		var p := Vector3(rng.randf_range(-0.6, 0.6), 1.1, rng.randf_range(-0.6, 0.6))
		l.append([_box(Vector3(0.06, 2.3, 0.25)), _tf(p, Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3)))])
	return build([[l, grass_blade, 0.0]])

static func plantain() -> ArrayMesh:
	var t := [[_cyl(0.14, 0.2, 2.2), _tf(Vector3(0, 1.1, 0))]]
	var l := []
	for i in 6:
		var a := TAU * i / 6.0
		var basis := Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, -0.5)
		l.append([_box(Vector3(0.7, 0.02, 2.3)), Transform3D(basis, Vector3(0, 2.2, 0) + basis * Vector3(0, 0, 1.1))])
	return build([[t, palm_leaf, 0.0], [l, palm_leaf, 0.0]])

# ---------- obstacles ----------
static func boulder() -> ArrayMesh:
	return build([[[[_sphere(1.0, 1.5, 7, 4), _tf(Vector3(0, 0.5, 0), Vector3.ZERO, Vector3(1.2, 1, 1))]], rock, 0.45]])
static func log_mesh() -> ArrayMesh:
	return build([[[[_cyl(0.35, 0.4, 5.0), _tf(Vector3(0, 0.35, 0), Vector3(0, 0, PI / 2))]], bark, 0.05]])
static func termite_mound() -> ArrayMesh:
	var p := [[_cyl(0.15, 1.1, 2.8), _tf(Vector3(0, 1.4, 0))], [_cyl(0.05, 0.4, 1.2), _tf(Vector3(0.4, 2.4, 0.1), Vector3(0, 0, -0.2))]]
	return build([[p, laterite, 0.25]])
