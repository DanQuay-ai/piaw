class_name Props
## Jungle props built from textured alpha cards (PS2/PS3 style foliage). Built once, reused via MultiMesh.

static var _noise := FastNoiseLite.new()
const TEX := "res://assets/textures/"

static func mat(col: Color, tex: Texture2D = null, tri_scale := 0.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col; m.roughness = 0.95; m.vertex_color_use_as_albedo = true
	if tex:
		m.albedo_texture = tex; m.uv1_triplanar = true; m.uv1_scale = Vector3.ONE * tri_scale
	return m

static func card_mat(tex_name: String, col := Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(TEX + tex_name); m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR; m.alpha_scissor_threshold = 0.45
	m.cull_mode = BaseMaterial3D.CULL_DISABLED; m.vertex_color_use_as_albedo = true
	m.roughness = 1.0; m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return m

static func noise_tex(c1: Color, c2: Color, freq := 0.05, size := 128, cellular := false) -> NoiseTexture2D:
	var t := NoiseTexture2D.new(); t.width = size; t.height = size; t.seamless = true
	var n := FastNoiseLite.new(); n.frequency = freq; n.fractal_octaves = 4
	if cellular: n.noise_type = FastNoiseLite.TYPE_CELLULAR
	t.noise = n
	var g := Gradient.new(); g.set_color(0, c1); g.set_color(1, c2); t.color_ramp = g
	return t

static func _sphere(r: float, h: float, seg := 8, rings := 5) -> SphereMesh:
	var s := SphereMesh.new(); s.radius = r; s.height = h; s.radial_segments = seg; s.rings = rings; return s
static func _cyl(top: float, bot: float, h: float, seg := 7) -> CylinderMesh:
	var c := CylinderMesh.new(); c.top_radius = top; c.bottom_radius = bot; c.height = h; c.radial_segments = seg; c.rings = 2; return c
static func _box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new(); b.size = s; return b
static func _quad(w: float, h: float, centre := Vector3.ZERO) -> QuadMesh:
	var q := QuadMesh.new(); q.size = Vector2(w, h); q.center_offset = centre; return q
static func _tf(pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> Transform3D:
	return Transform3D(Basis.from_euler(rot).scaled(scl), pos)

## groups: Array of [parts [[mesh, transform]], material, jitter, ao_strength]
static func build(groups: Array) -> ArrayMesh:
	var am := ArrayMesh.new()
	for g in groups:
		var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part in g[0]: st.append_from(part[0], 0, part[1])
		var arr := st.commit_to_arrays()
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var jit: float = g[2]
		if jit > 0.0:
			for i in v.size():
				var p := v[i]; var n := _noise.get_noise_3d(p.x * 9.0, p.y * 9.0, p.z * 9.0)
				v[i] = p + Vector3(n, n * 0.6, -n) * jit
			arr[Mesh.ARRAY_VERTEX] = v
		var ao: float = g[3] if g.size() > 3 else 0.5
		var cols := PackedColorArray(); cols.resize(v.size())
		var miny := INF; var maxy := -INF
		for p in v: miny = min(miny, p.y); maxy = max(maxy, p.y)
		for i in v.size():
			var t: float = (v[i].y - miny) / max(maxy - miny, 0.01)
			var k: float = lerp(1.0 - ao, 1.08, t)
			cols[i] = Color(k, k, k)
		arr[Mesh.ARRAY_COLOR] = cols
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		am.surface_set_material(am.get_surface_count() - 1, g[1])
	return am

# ---------- shared materials ----------
static var bark: StandardMaterial3D
static var rock: StandardMaterial3D
static var laterite: StandardMaterial3D
static var canopy: StandardMaterial3D
static var canopy_dark: StandardMaterial3D
static var canopy_core: StandardMaterial3D
static var grass_card: StandardMaterial3D
static var fern_card: StandardMaterial3D
static var palm_card: StandardMaterial3D
static var taro_card: StandardMaterial3D
static var stalk: StandardMaterial3D

static func init_materials() -> void:
	bark = mat(Color(0.85, 0.8, 0.75), load(TEX + "bark.png"), 1.2)
	rock = mat(Color(0.8, 0.78, 0.75), noise_tex(Color(0.3, 0.28, 0.27), Color(0.6, 0.56, 0.5), 0.1), 0.8)
	laterite = mat(Color(1, 1, 1), load(TEX + "ground_laterite.png"), 0.4)
	canopy = card_mat("leaf_cluster.png", Color(0.9, 1.0, 0.85))
	canopy_dark = card_mat("leaf_cluster.png", Color(0.62, 0.72, 0.6))
	canopy_core = mat(Color(0.08, 0.15, 0.05))
	grass_card = card_mat("grass_card.png", Color(0.78, 0.8, 0.68))
	fern_card = card_mat("fern_frond.png")
	palm_card = card_mat("palm_frond.png", Color(0.9, 0.95, 0.8))
	taro_card = card_mat("taro_leaf.png", Color(0.85, 0.95, 0.85))
	stalk = mat(Color(0.35, 0.5, 0.2))

static func _canopy_cards(parts: Array, centre: Vector3, radius: float, n: int, size: float, rng: RandomNumberGenerator) -> void:
	for i in n:
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.5, 0.6), rng.randf_range(-1, 1)).normalized() * radius * rng.randf_range(0.35, 1.0)
		var rot := Vector3(rng.randf_range(-1.2, 1.2), rng.randf() * TAU, rng.randf_range(-1.2, 1.2))
		parts.append([_quad(size, size), _tf(centre + d, rot)])

# ---------- trees ----------
static func ceiba() -> ArrayMesh:  # giant silk-cotton / odum
	var rng := RandomNumberGenerator.new(); rng.seed = 1
	var t := []; var l := []; var core := []
	t.append([_cyl(0.45, 0.85, 20, 9), _tf(Vector3(0, 10, 0))])
	for i in 5:
		var a := TAU * i / 5.0
		t.append([_box(Vector3(0.18, 3.4, 2.2)), _tf(Vector3(cos(a) * 0.95, 1.5, sin(a) * 0.95), Vector3(0, -a + PI / 2, 0.15))])
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		t.append([_cyl(0.12, 0.28, 6.5), _tf(Vector3(cos(a) * 2.2, 17.5, sin(a) * 2.2), Vector3(sin(a) * 1.0, 0, -cos(a) * 1.0))])
	for c in [Vector3(0, 21, 0), Vector3(4, 19, 1.5), Vector3(-3.5, 19.5, -2), Vector3(1.5, 19.2, -4), Vector3(-2, 18.5, 3.5)]:
		core.append([_sphere(2.4, 1.8, 7, 4), _tf(c)])
		_canopy_cards(l, c, 3.6, 16, 3.6, rng)
	return build([[t, bark, 0.0, 0.5], [core, canopy_core, 0.4, 0.3], [l, canopy_dark, 0.0, 0.45]])

static func broadleaf(seed := 3) -> ArrayMesh:
	var rng := RandomNumberGenerator.new(); rng.seed = seed
	var t := []; var l := []; var core := []
	var h := rng.randf_range(7.0, 10.0)
	t.append([_cyl(0.2, 0.38, h, 8), _tf(Vector3(0, h / 2, 0), Vector3(0.04, 0, 0.03))])
	for i in 3:
		var a := TAU * i / 3.0 + rng.randf()
		t.append([_cyl(0.06, 0.14, 3.2), _tf(Vector3(cos(a) * 0.9, h - 1.0, sin(a) * 0.9), Vector3(sin(a) * 0.8, 0, -cos(a) * 0.8))])
	for i in 4:
		var c := Vector3(rng.randf_range(-1.6, 1.6), h + rng.randf_range(-0.5, 1.5), rng.randf_range(-1.6, 1.6))
		core.append([_sphere(1.3, 1.2, 6, 4), _tf(c)])
		_canopy_cards(l, c, 2.2, 10, 2.6, rng)
	return build([[t, bark, 0.0, 0.5], [core, canopy_core, 0.3, 0.3], [l, canopy, 0.0, 0.45]])

static func oil_palm() -> ArrayMesh:
	var t := []; var l := []
	for i in 6:
		t.append([_cyl(0.26, 0.32, 1.4), _tf(Vector3(0, 0.7 + i * 1.35, 0), Vector3(0, i * 0.5, 0))])
	var top := Vector3(0, 8.2, 0)
	for i in 16:
		var a := TAU * i / 16.0
		var droop := -0.25 - 0.3 * float(i % 3)
		var basis := Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, PI / 2 + droop)
		l.append([_quad(1.4, 4.6, Vector3(0, 2.2, 0)), Transform3D(basis, top)])
	return build([[t, bark, 0.0, 0.5], [l, palm_card, 0.0, 0.3]])

static func sapling() -> ArrayMesh:
	var rng := RandomNumberGenerator.new(); rng.seed = 9
	var t := [[_cyl(0.07, 0.12, 2.8), _tf(Vector3(0, 1.4, 0))]]
	var l := []
	_canopy_cards(l, Vector3(0, 3.0, 0), 1.2, 9, 1.8, rng)
	return build([[t, bark, 0.0, 0.5], [l, canopy, 0.0, 0.4]])

# ---------- undergrowth ----------
static func grass_tuft(h := 1.1) -> ArrayMesh:
	var l := []
	for i in 3: l.append([_quad(1.5, h, Vector3(0, h / 2, 0)), _tf(Vector3.ZERO, Vector3(0, i * PI / 3, 0))])
	return build([[l, grass_card, 0.0, 0.55]])

static func shrub() -> ArrayMesh:
	var rng := RandomNumberGenerator.new(); rng.seed = 5
	var l := []; var core := [[_sphere(0.8, 1.0, 6, 3), _tf(Vector3(0, 0.6, 0))]]
	_canopy_cards(l, Vector3(0, 0.8, 0), 1.0, 12, 1.6, rng)
	return build([[core, canopy_core, 0.3, 0.3], [l, canopy, 0.0, 0.5]])

static func fern() -> ArrayMesh:
	var l := []
	for i in 9:
		var a := TAU * i / 9.0
		var basis := Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, -0.55 - 0.25 * (i % 2))
		l.append([_quad(0.7, 1.9, Vector3(0, 0.9, 0)), Transform3D(basis, Vector3(0, 0.05, 0))])
	return build([[l, fern_card, 0.0, 0.5]])

static func taro() -> ArrayMesh:  # elephant-ear / cocoyam leaves
	var rng := RandomNumberGenerator.new(); rng.seed = 12
	var st := []; var l := []
	for i in 6:
		var a := TAU * i / 6.0 + rng.randf() * 0.4
		var hgt := rng.randf_range(0.9, 1.6)
		var tip := Vector3(cos(a) * 0.5, hgt, sin(a) * 0.5)
		st.append([_cyl(0.025, 0.04, hgt + 0.1, 5), _tf(tip * 0.5, Vector3(sin(a) * 0.3, 0, -cos(a) * 0.3))])
		var basis := Basis(Vector3.UP, -a + PI / 2) * Basis(Vector3.RIGHT, -1.1)
		l.append([_quad(1.0, 1.15, Vector3(0, -0.5, 0)), Transform3D(basis, tip)])
	return build([[st, stalk, 0.0, 0.2], [l, taro_card, 0.0, 0.35]])

static func elephant_grass() -> ArrayMesh:
	var l := []
	for i in 4: l.append([_quad(1.8, 2.6, Vector3(0, 1.3, 0)), _tf(Vector3.ZERO, Vector3(0, i * PI / 4, 0))])
	return build([[l, grass_card, 0.0, 0.5]])

static func plantain() -> ArrayMesh:
	var t := [[_cyl(0.14, 0.2, 2.2), _tf(Vector3(0, 1.1, 0))]]
	var l := []
	for i in 6:
		var a := TAU * i / 6.0
		var basis := Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, PI / 2 - 0.45)
		l.append([_quad(0.9, 2.4, Vector3(0, 1.1, 0)), Transform3D(basis, Vector3(0, 2.2, 0))])
	return build([[t, bark, 0.0, 0.4], [l, palm_card, 0.0, 0.3]])

# ---------- obstacles ----------
static func boulder() -> ArrayMesh:
	return build([[[[_sphere(1.0, 1.5, 7, 4), _tf(Vector3(0, 0.5, 0), Vector3.ZERO, Vector3(1.2, 1, 1))]], rock, 0.45, 0.5]])
static func log_mesh() -> ArrayMesh:
	return build([[[[_cyl(0.35, 0.4, 5.0), _tf(Vector3(0, 0.35, 0), Vector3(0, 0, PI / 2))]], bark, 0.05, 0.3]])
static func termite_mound() -> ArrayMesh:
	var p := [[_cyl(0.15, 1.1, 2.8), _tf(Vector3(0, 1.4, 0))], [_cyl(0.05, 0.4, 1.2), _tf(Vector3(0.4, 2.4, 0.1), Vector3(0, 0, -0.2))]]
	return build([[p, laterite, 0.25, 0.4]])
