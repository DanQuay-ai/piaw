class_name World extends Node3D
## Builds the Asante forest map: hills, red laterite soil, river, lake, ponds,
## mixed forest, bushes, obstacles, an Asante neighbourhood and the hill fort.

const X0 := -120.0; const X1 := 120.0
const Z0 := -150.0; const Z1 := 120.0
const STEP := 2.0
const M := 70.0  # scenery margin beyond the playable boundary (mirrored terrain)
const WATER := -0.45
static var FORT := Vector2(0, -110)
static var VILLAGE := Vector2(52, -40)
static var LAKE := Vector2(-62, 30)
static var SPAWN := Vector2(0, 95)
static var COAST := false        # sea along the north edge
static var SEA_Z := -105.0       # shoreline (z below this is sea)
static var FORT_HILL := 15.0     # hill height under the fort (0 = beach castle)
static var HAS_VILLAGE := true
static var HAS_FORT := true

## Apply a mission's map layout before build().
static func configure(cfg: Dictionary) -> void:
	FORT = cfg.get("fort", Vector2(0, -110)); VILLAGE = cfg.get("village", Vector2(52, -40))
	SPAWN = cfg.get("spawn", Vector2(0, 95)); COAST = cfg.get("coast", false)
	SEA_Z = cfg.get("sea_z", -105.0); FORT_HILL = cfg.get("fort_hill", 15.0)
	HAS_VILLAGE = cfg.get("has_village", true); HAS_FORT = cfg.get("has_fort", true)
	LAKE = cfg.get("lake", Vector2(-62, 30))

static var inst: World
var n1 := FastNoiseLite.new()
var n2 := FastNoiseLite.new()
var n3 := FastNoiseLite.new()
var rng := RandomNumberGenerator.new()
var foliage := {}  # Vector2i cell -> true  (hiding spots)
var fort_top := 0.0
var village_h := 0.0
var quality := 1  # 0 low (mobile), 1 high
var colliders: StaticBody3D

func _init() -> void:
	inst = self
	n1.seed = 11; n1.frequency = 0.012; n1.fractal_octaves = 4
	n2.seed = 23; n2.frequency = 0.004
	n3.seed = 5; n3.frequency = 0.05
	rng.seed = 2024

func path_x(z: float) -> float:  # red earth road from the south to the fort
	return 14.0 * sin(z / 28.0) + 4.0 * sin(z / 9.0)
func river_z(x: float) -> float:
	return -2.0 + 9.0 * sin(x / 22.0) + 3.0 * sin(x / 7.0)

func _base(x: float, z: float) -> float:
	var h := 5.5 + n1.get_noise_2d(x, z) * 4.0 + n2.get_noise_2d(x, z) * 8.0
	# walls of hills at the map edge
	h += max(0.0, abs(x) - 95.0) * 0.8 + max(0.0, z - 100.0) * 0.8 + max(0.0, -z - 135.0) * 0.8
	return h

func height(x: float, z: float) -> float:
	# outside the playable area: mirror the map so the horizon is never empty
	if x < X0: x = X0 + (X0 - x)
	elif x > X1: x = X1 - (x - X1)
	if z < Z0: z = Z0 + (Z0 - z)
	elif z > Z1: z = Z1 - (z - Z1)
	var h := _base(x, z)
	var p := Vector2(x, z)
	# fort hill with flat top
	var df := p.distance_to(FORT) if HAS_FORT else 9999.0
	h += FORT_HILL * exp(-pow(df / 44.0, 2.0))
	# flattened neighbourhood plateau
	if HAS_VILLAGE: h = lerp(h, village_h, smoothstep(36.0, 24.0, p.distance_to(VILLAGE)))
	# road: smooth and keep dry
	var dp: float = abs(x - path_x(z))
	h = lerp(h, max(h * 0.7 + 0.5, WATER + 0.9), smoothstep(6.0, 2.0, dp) * 0.8 * smoothstep(28.0, 50.0, df))
	# river channel (wadeable)
	var dr: float = abs(z - river_z(x))
	h = min(h, lerp(-0.95, min(h, 2.0 + dr * 0.25), smoothstep(3.5, 22.0, dr)))  # gentle, walkable banks
	if dp < 7.0 and dr < 12.0: h = max(h, -0.7)  # ford where the road crosses
	# lake
	var dl := p.distance_to(LAKE)
	h = min(h, lerp(-3.5, h, smoothstep(13.0, 26.0, dl)))
	# flat fort summit, blended last so nothing cuts into it
	h = lerp(h, fort_top, smoothstep(34.0, 22.0, df))
	# the sea: beach then deep water past the shoreline
	if COAST:
		var into: float = SEA_Z - z
		h = lerp(h, min(h, 0.6 - into * 0.05), smoothstep(-28.0, -6.0, into))
		h = lerp(h, -6.0, smoothstep(0.0, 22.0, into))
	# keep spawn dry and gentle
	if not HAS_FORT or SPAWN.distance_to(FORT) > 40.0: h = lerp(h, 2.0, smoothstep(14.0, 4.0, p.distance_to(SPAWN)))
	return h

func ground_tint(x: float, z: float, h: float, slope: float) -> Color:
	## r = grass amount, g = wetness
	var grass := clampf(0.8 + n3.get_noise_2d(x, z) * 0.6, 0.0, 1.0)
	grass *= smoothstep(1.5, 4.5, abs(x - path_x(z)))
	if HAS_VILLAGE: grass *= smoothstep(30.0, 38.0, Vector2(x, z).distance_to(VILLAGE))
	if HAS_FORT: grass *= smoothstep(22.0, 30.0, Vector2(x, z).distance_to(FORT))
	grass *= 1.0 - smoothstep(0.5, 1.2, slope)
	var wet := smoothstep(WATER + 1.4, WATER, h)
	var sand := 0.0
	if COAST: sand = smoothstep(SEA_Z + 30.0, SEA_Z + 12.0, z)
	if COAST: grass *= 1.0 - sand
	return Color(grass, wet * (1.0 - sand), sand)

func build() -> void:
	quality = 0 if (OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")) else 1
	fort_top = max(_base(FORT.x, FORT.y), 1.2) + FORT_HILL
	village_h = max(_base(VILLAGE.x, VILLAGE.y), 1.5)
	Props.init_materials(); Buildings.init_materials()
	colliders = StaticBody3D.new(); add_child(colliders)
	_environment()
	_terrain()
	_water()
	_forest()
	if HAS_VILLAGE: _neighbourhood()

# ---------------------------------------------------------------- sky & light
func _environment() -> void:
	var we := WorldEnvironment.new(); var e := Environment.new()
	var sky := Sky.new(); var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.22, 0.42, 0.78); sm.sky_horizon_color = Color(0.68, 0.76, 0.8)
	sm.ground_horizon_color = Color(0.5, 0.48, 0.4); sm.ground_bottom_color = Color(0.2, 0.2, 0.15)
	sm.sun_angle_max = 20.0
	sky.sky_material = sm
	e.background_mode = Environment.BG_SKY; e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY; e.ambient_light_energy = 0.7
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC; e.tonemap_exposure = 1.05
	e.fog_enabled = true; e.fog_light_color = Color(0.55, 0.65, 0.6); e.fog_density = 0.011
	e.fog_aerial_perspective = 0.4; e.fog_sky_affect = 0.3
	we.environment = e; add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-38, 35, 0)
	sun.light_color = Color(1.0, 0.93, 0.8); sun.light_energy = 1.25
	sun.shadow_enabled = quality > 0
	sun.directional_shadow_max_distance = 70.0
	add_child(sun)

# ---------------------------------------------------------------- terrain
const GROUND_SHADER := """
shader_type spatial;
uniform sampler2D grass_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D soil_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D detail_tex : repeat_enable, filter_linear_mipmap;
varying vec3 wp;
void vertex(){ wp = VERTEX; }
void fragment(){
  vec3 g = texture(grass_tex, wp.xz * 0.06).rgb;
  vec3 s = texture(soil_tex, wp.xz * 0.05).rgb;
  float d = texture(detail_tex, wp.xz * 0.5).r;
  float far = texture(detail_tex, wp.xz * 0.01).r;
  float k = smoothstep(0.35, 0.65, COLOR.r + (d - 0.5) * 0.5);
  vec3 col = mix(s, g, k) * (0.85 + 0.3 * far) * (0.92 + 0.16 * d);
  col *= mix(1.0, 0.55, COLOR.g);   // damp banks
  vec3 sandc = vec3(0.78, 0.7, 0.52) * (0.9 + 0.2 * d);
  col = mix(col, sandc, COLOR.b);
  ALBEDO = col;
  ROUGHNESS = mix(0.95, 0.5, COLOR.g);
}
"""

func _terrain() -> void:
	_terrain_mesh(X0 - M, X1 + M, Z0 - M, Z1 + M, STEP * 1.5 if quality == 0 else STEP)
	_terrain_collision()
	_bounds()

func _bounds() -> void:
	var b := StaticBody3D.new(); add_child(b)
	var w := X1 - X0; var d := Z1 - Z0; var cx := (X0 + X1) / 2.0; var cz := (Z0 + Z1) / 2.0
	for sp in [[Vector3(w + 4, 80, 2), Vector3(cx, 30, Z0 + 3)], [Vector3(w + 4, 80, 2), Vector3(cx, 30, Z1 - 3)],
			[Vector3(2, 80, d + 4), Vector3(X0 + 3, 30, cz)], [Vector3(2, 80, d + 4), Vector3(X1 - 3, 30, cz)]]:
		var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = sp[0]; cs.shape = sh; cs.position = sp[1]; b.add_child(cs)

func _terrain_mesh(ax: float, bx: float, az: float, bz: float, step: float) -> void:
	var nx := int((bx - ax) / step) + 1
	var nz := int((bz - az) / step) + 1
	var hs := PackedFloat32Array(); hs.resize(nx * nz)
	for j in nz:
		for i in nx:
			hs[j * nx + i] = height(ax + i * step, az + j * step)
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in nz:
		for i in nx:
			var x := ax + i * step; var z := az + j * step; var h := hs[j * nx + i]
			var hx := hs[j * nx + min(i + 1, nx - 1)] - hs[j * nx + max(i - 1, 0)]
			var hz := hs[min(j + 1, nz - 1) * nx + i] - hs[max(j - 1, 0) * nx + i]
			var slope := Vector2(hx, hz).length() / (2.0 * step)
			st.set_color(ground_tint(x, z, h, slope))
			st.add_vertex(Vector3(x, h, z))
	for j in nz - 1:
		for i in nx - 1:
			var a := j * nx + i; var b := a + 1; var c := a + nx; var d := c + 1
			st.add_index(a); st.add_index(b); st.add_index(c)
			st.add_index(b); st.add_index(d); st.add_index(c)
	st.generate_normals()
	var mi := MeshInstance3D.new(); mi.mesh = st.commit()
	var sh := Shader.new(); sh.code = GROUND_SHADER
	var m := ShaderMaterial.new(); m.shader = sh
	m.set_shader_parameter("grass_tex", load("res://assets/textures/ground_forest.png"))
	m.set_shader_parameter("soil_tex", load("res://assets/textures/ground_laterite.png"))
	m.set_shader_parameter("detail_tex", Props.noise_tex(Color(0, 0, 0), Color(1, 1, 1), 0.1, 128))
	mi.material_override = m
	add_child(mi)

func _terrain_collision() -> void:
	var nx := int((X1 - X0) / STEP) + 1
	var nz := int((Z1 - Z0) / STEP) + 1
	var hs := PackedFloat32Array(); hs.resize(nx * nz)
	for j in nz:
		for i in nx:
			hs[j * nx + i] = height(X0 + i * STEP, Z0 + j * STEP)
	# collision: HeightMapShape3D is centred, 1 unit per cell -> scale by STEP
	var body := StaticBody3D.new(); var cs := CollisionShape3D.new(); var hm := HeightMapShape3D.new()
	hm.map_width = nx; hm.map_depth = nz; hm.map_data = hs
	cs.shape = hm; cs.scale = Vector3(STEP, 1, STEP)
	body.position = Vector3((X0 + X1) / 2.0, 0, (Z0 + Z1) / 2.0)
	body.add_child(cs); add_child(body)

func _water() -> void:
	var mi := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(X1 - X0 + 2 * M, Z1 - Z0 + 2 * M)
	mi.mesh = pm; mi.position = Vector3((X0 + X1) / 2.0, WATER, (Z0 + Z1) / 2.0)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.16, 0.24, 0.17, 0.82)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.metallic = 0.4; m.roughness = 0.08
	m.normal_enabled = true
	var nt := Props.noise_tex(Color(0.5, 0.5, 1), Color(1, 1, 1), 0.08, 128); nt.as_normal_map = true
	m.normal_texture = nt; m.uv1_scale = Vector3(40, 40, 1)
	mi.material_override = m; add_child(mi)

# ---------------------------------------------------------------- vegetation
func ok_spot(x: float, z: float, clear := 4.0) -> bool:
	var h := height(x, z)
	if h < WATER + 0.4: return false
	if abs(x - path_x(z)) < clear: return false
	var p := Vector2(x, z)
	if (HAS_VILLAGE and p.distance_to(VILLAGE) < 30.0) or (HAS_FORT and p.distance_to(FORT) < 32.0) or p.distance_to(SPAWN) < 7.0: return false
	if COAST and z < SEA_Z + 14.0: return false
	return true

func _scatter(mesh: Mesh, count: int, smin: float, smax: float, tint_var: float, clear: float, collide_r: float, hide := false, grassy := false, ext := false) -> void:
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.use_colors = true; mm.mesh = mesh
	var xf := []; var cols := []
	var tries := 0
	while xf.size() < count and tries < count * 20:
		tries += 1
		var x := rng.randf_range(X0 + 6, X1 - 6); var z := rng.randf_range(Z0 + 6, Z1 - 6)
		if ext:
			x = rng.randf_range(X0 - M, X1 + M); z = rng.randf_range(Z0 - M, Z1 + M)
			if x > X0 and x < X1 and z > Z0 and z < Z1: continue
		if not ok_spot(x, z, clear): continue
		if grassy and ground_tint(x, z, height(x, z), 0.0).r < 0.45: continue
		var s := rng.randf_range(smin, smax)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.85, 1.15), s))
		var pos := Vector3(x, height(x, z) - 0.15, z)
		xf.append(Transform3D(basis, pos))
		var v := rng.randf_range(-tint_var, tint_var)
		cols.append(Color(1.0 + v, 1.0 + v * 0.5, 1.0 - v * 0.3))
		if collide_r > 0.0:
			var cs := CollisionShape3D.new(); var c := CylinderShape3D.new(); c.radius = collide_r * s; c.height = 4.0
			cs.shape = c; cs.position = pos + Vector3(0, 2, 0); colliders.add_child(cs)
		if hide:
			var r := int(round(1.0 * s / 2.0))
			for dx in range(-r, r + 1):
				for dz in range(-r, r + 1):
					foliage[Vector2i(int(floor(x / 2.0)) + dx, int(floor(z / 2.0)) + dz)] = true
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i]); mm.set_instance_color(i, cols[i])
	var mmi := MultiMeshInstance3D.new(); mmi.multimesh = mm; add_child(mmi)
	if grassy: mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _forest() -> void:
	var q := 1.0 if quality > 0 else 0.5
	_scatter(Props.ceiba(), int(55 * q), 0.8, 1.3, 0.1, 6.0, 0.9)
	for sd in [3, 4, 7]: _scatter(Props.broadleaf(sd), int(110 * q), 0.8, 1.4, 0.15, 4.0, 0.4)
	_scatter(Props.oil_palm(), int(80 * q), 0.8, 1.2, 0.12, 4.0, 0.35)
	_scatter(Props.sapling(), int(160 * q), 0.7, 1.3, 0.2, 3.0, 0.0)
	_scatter(Props.shrub(), int(220 * q), 0.7, 1.5, 0.2, 2.5, 0.0, true)
	_scatter(Props.fern(), int(260 * q), 0.8, 1.6, 0.15, 2.0, 0.0, true)
	_scatter(Props.taro(), int(200 * q), 0.8, 1.5, 0.12, 2.0, 0.0, true)
	_scatter(Props.elephant_grass(), int(220 * q), 0.8, 1.3, 0.1, 2.5, 0.0, true)
	_scatter(Props.plantain(), int(60 * q), 0.8, 1.2, 0.1, 3.0, 0.0, true)
	_scatter(Props.grass_tuft(), int(5500 * q), 0.6, 1.3, 0.15, 1.6, 0.0, false, true)
	# scenery beyond the boundary
	_scatter(Props.ceiba(), int(40 * q), 0.9, 1.4, 0.1, 0.0, 0.0, false, false, true)
	for sd in [3, 4]: _scatter(Props.broadleaf(sd), int(160 * q), 0.9, 1.5, 0.15, 0.0, 0.0, false, false, true)
	_scatter(Props.oil_palm(), int(60 * q), 0.8, 1.2, 0.12, 0.0, 0.0, false, false, true)
	_scatter(Props.shrub(), int(120 * q), 0.9, 1.6, 0.2, 0.0, 0.0, false, false, true)
	_scatter(Props.boulder(), 45, 0.6, 2.2, 0.1, 3.0, 0.9)
	_scatter(Props.termite_mound(), 25, 0.8, 1.4, 0.05, 3.0, 0.7)
	_logs(24)

func _logs(n: int) -> void:
	var m := Props.log_mesh()
	for i in n:
		var x := rng.randf_range(-90, 90); var z := rng.randf_range(-100, 90)
		if not ok_spot(x, z, 3.0): continue
		var mi := MeshInstance3D.new(); mi.mesh = m; mi.position = Vector3(x, height(x, z) - 0.1, z); mi.rotation.y = rng.randf() * TAU
		add_child(mi)
		var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = Vector3(5, 0.8, 0.8)
		cs.shape = b; cs.position = mi.position + Vector3(0, 0.4, 0); cs.rotation = mi.rotation; colliders.add_child(cs)

## Top-down map texture of the playable area (for the minimap / full map).
func map_image(px := 256) -> Image:
	var img := Image.create(px, int(px * (Z1 - Z0) / (X1 - X0)), false, Image.FORMAT_RGB8)
	for j in img.get_height():
		for i in img.get_width():
			var x := X0 + (i + 0.5) / img.get_width() * (X1 - X0); var z := Z0 + (j + 0.5) / img.get_height() * (Z1 - Z0)
			var h := height(x, z); var t := ground_tint(x, z, h, 0.0)
			var c := Color(0.42, 0.24, 0.15).lerp(Color(0.22, 0.3, 0.14), t.r)
			if foliage.has(Vector2i(int(floor(x / 2.0)), int(floor(z / 2.0)))): c = c.darkened(0.15)
			if abs(x - path_x(z)) < 2.5: c = Color(0.62, 0.3, 0.16)
			c = c.lightened(clampf(h / 30.0, 0.0, 0.3))
			if COAST and z < SEA_Z + 22.0: c = Color(0.75, 0.67, 0.5)
			if h < WATER: c = Color(0.16, 0.3, 0.36)
			img.set_pixel(i, j, c)
	return img

func is_hidden_spot(p: Vector3) -> bool:
	return foliage.has(Vector2i(int(floor(p.x / 2.0)), int(floor(p.z / 2.0))))

# ---------------------------------------------------------------- Asante neighbourhood
func _neighbourhood() -> void:
	var c := Vector3(VILLAGE.x, village_h, VILLAGE.y)
	var town := Node3D.new(); town.name = "Town"; add_child(town)
	# main street running north-south, buildings face the street (like the old Kumasi photographs)
	for i in 5:
		var z := c.z - 20.0 + i * 9.5
		Buildings.house(town, Vector3(c.x - 7.5, c.y, z), PI / 2, 8.5, 4.5, 3.0)
		Buildings.house(town, Vector3(c.x + 7.5, c.y, z), -PI / 2, 8.5, 4.5, 3.2)
	# courtyard compounds behind the street
	Buildings.compound(town, Vector3(c.x - 24.0, c.y, c.z - 6.0))
	Buildings.compound(town, Vector3(c.x + 24.0, c.y, c.z + 4.0), 0.3)
	# shade trees in the square
	var palm := Props.oil_palm()
	for p in [Vector3(c.x, c.y, c.z + 30.0), Vector3(c.x + 3, c.y, c.z - 28.0)]:
		var mi := MeshInstance3D.new(); mi.mesh = palm; mi.position = p; town.add_child(mi)
	var tree := Props.ceiba()
	var big := MeshInstance3D.new(); big.mesh = tree; big.position = Vector3(c.x - 3.0, c.y, c.z + 24.0); town.add_child(big)
	var cs := CollisionShape3D.new(); var cy := CylinderShape3D.new(); cy.radius = 0.9; cy.height = 6; cs.shape = cy
	cs.position = big.position + Vector3(0, 3, 0); colliders.add_child(cs)
