class_name World extends Node3D
## Builds the Asante forest map: hills, red laterite soil, river, lake, ponds,
## mixed forest, bushes, obstacles, an Asante neighbourhood and the hill fort.

const X0 := -120.0; const X1 := 120.0
const Z0 := -150.0; const Z1 := 120.0
const STEP := 2.0
const WATER := -0.45
const FORT := Vector2(0, -110)
const VILLAGE := Vector2(52, -40)
const LAKE := Vector2(-62, 30)
const SPAWN := Vector2(0, 95)

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
	var h := _base(x, z)
	var p := Vector2(x, z)
	# fort hill with flat top
	var df := p.distance_to(FORT)
	h += 15.0 * exp(-pow(df / 44.0, 2.0))
	h = lerp(h, fort_top, smoothstep(30.0, 23.0, df))
	# flattened neighbourhood plateau
	h = lerp(h, village_h, smoothstep(36.0, 24.0, p.distance_to(VILLAGE)))
	# road: smooth and keep dry
	var dp: float = abs(x - path_x(z))
	h = lerp(h, max(h * 0.7 + 0.5, WATER + 0.9), smoothstep(6.0, 2.0, dp) * 0.8)
	# river channel (wadeable)
	var dr: float = abs(z - river_z(x))
	h = min(h, lerp(-1.4, h, smoothstep(2.5, 9.0, dr)))
	if dp < 5.0 and dr < 9.0: h = max(h, -0.75)  # ford where the road crosses
	# lake
	var dl := p.distance_to(LAKE)
	h = min(h, lerp(-3.5, h, smoothstep(13.0, 26.0, dl)))
	# keep spawn dry and gentle
	h = lerp(h, 2.0, smoothstep(14.0, 4.0, p.distance_to(SPAWN)))
	return h

func ground_tint(x: float, z: float, h: float, slope: float) -> Color:
	## r = grass amount, g = wetness
	var grass := clampf(0.8 + n3.get_noise_2d(x, z) * 0.6, 0.0, 1.0)
	grass *= smoothstep(1.5, 4.5, abs(x - path_x(z)))
	grass *= smoothstep(30.0, 38.0, Vector2(x, z).distance_to(VILLAGE))
	grass *= smoothstep(22.0, 30.0, Vector2(x, z).distance_to(FORT))
	grass *= 1.0 - smoothstep(0.5, 1.2, slope)
	var wet := smoothstep(WATER + 1.4, WATER, h)
	return Color(grass, wet, 0)

func build() -> void:
	quality = 0 if (OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")) else 1
	fort_top = _base(FORT.x, FORT.y) + 15.0
	village_h = max(_base(VILLAGE.x, VILLAGE.y), 1.5)
	Props.init_materials(); Buildings.init_materials()
	colliders = StaticBody3D.new(); add_child(colliders)
	_environment()
	_terrain()
	_water()
	_forest()
	_neighbourhood()

# ---------------------------------------------------------------- sky & light
func _environment() -> void:
	var we := WorldEnvironment.new(); var e := Environment.new()
	var sky := Sky.new(); var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.42, 0.55, 0.68); sm.sky_horizon_color = Color(0.78, 0.76, 0.66)
	sm.ground_horizon_color = Color(0.5, 0.48, 0.4); sm.ground_bottom_color = Color(0.2, 0.2, 0.15)
	sm.sun_angle_max = 20.0
	sky.sky_material = sm
	e.background_mode = Environment.BG_SKY; e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY; e.ambient_light_energy = 0.7
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC; e.tonemap_exposure = 1.05
	e.fog_enabled = true; e.fog_light_color = Color(0.7, 0.72, 0.62); e.fog_density = 0.009
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
  vec3 g = texture(grass_tex, wp.xz * 0.11).rgb;
  vec3 s = texture(soil_tex, wp.xz * 0.07).rgb;
  float d = texture(detail_tex, wp.xz * 0.5).r;
  float far = texture(detail_tex, wp.xz * 0.01).r;
  float k = smoothstep(0.35, 0.65, COLOR.r + (d - 0.5) * 0.5);
  vec3 col = mix(s, g, k) * (0.8 + 0.4 * far) * (0.85 + 0.3 * d);
  col *= mix(1.0, 0.55, COLOR.g);   // damp banks
  ALBEDO = col;
  ROUGHNESS = mix(0.95, 0.5, COLOR.g);
}
"""

func _terrain() -> void:
	var nx := int((X1 - X0) / STEP) + 1
	var nz := int((Z1 - Z0) / STEP) + 1
	var hs := PackedFloat32Array(); hs.resize(nx * nz)
	for j in nz:
		for i in nx:
			hs[j * nx + i] = height(X0 + i * STEP, Z0 + j * STEP)
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in nz:
		for i in nx:
			var x := X0 + i * STEP; var z := Z0 + j * STEP; var h := hs[j * nx + i]
			var hx := hs[j * nx + min(i + 1, nx - 1)] - hs[j * nx + max(i - 1, 0)]
			var hz := hs[min(j + 1, nz - 1) * nx + i] - hs[max(j - 1, 0) * nx + i]
			var slope := Vector2(hx, hz).length() / (2.0 * STEP)
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
	m.set_shader_parameter("grass_tex", Props.noise_tex(Color(0.15, 0.17, 0.07), Color(0.33, 0.32, 0.15), 0.08, 256))
	m.set_shader_parameter("soil_tex", Props.noise_tex(Color(0.33, 0.14, 0.07), Color(0.56, 0.26, 0.13), 0.09, 256))
	m.set_shader_parameter("detail_tex", Props.noise_tex(Color(0, 0, 0), Color(1, 1, 1), 0.1, 128))
	mi.material_override = m
	add_child(mi)
	# collision: HeightMapShape3D is centred, 1 unit per cell -> scale by STEP
	var body := StaticBody3D.new(); var cs := CollisionShape3D.new(); var hm := HeightMapShape3D.new()
	hm.map_width = nx; hm.map_depth = nz; hm.map_data = hs
	cs.shape = hm; cs.scale = Vector3(STEP, 1, STEP)
	body.position = Vector3((X0 + X1) / 2.0, 0, (Z0 + Z1) / 2.0)
	body.add_child(cs); add_child(body)

func _water() -> void:
	var mi := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(X1 - X0, Z1 - Z0)
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
	if p.distance_to(VILLAGE) < 30.0 or p.distance_to(FORT) < 30.0 or p.distance_to(SPAWN) < 7.0: return false
	return true

func _scatter(mesh: Mesh, count: int, smin: float, smax: float, tint_var: float, clear: float, collide_r: float, hide := false) -> void:
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.use_colors = true; mm.mesh = mesh
	var xf := []; var cols := []
	var tries := 0
	while xf.size() < count and tries < count * 20:
		tries += 1
		var x := rng.randf_range(X0 + 6, X1 - 6); var z := rng.randf_range(Z0 + 6, Z1 - 6)
		if not ok_spot(x, z, clear): continue
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
			var r := int(ceil(1.4 * s / 2.0))
			for dx in range(-r, r + 1):
				for dz in range(-r, r + 1):
					foliage[Vector2i(int(floor(x / 2.0)) + dx, int(floor(z / 2.0)) + dz)] = true
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i]); mm.set_instance_color(i, cols[i])
	var mmi := MultiMeshInstance3D.new(); mmi.multimesh = mm; add_child(mmi)

func _forest() -> void:
	var q := 1.0 if quality > 0 else 0.55
	_scatter(Props.ceiba(), int(45 * q), 0.8, 1.3, 0.1, 6.0, 0.9)
	_scatter(Props.broadleaf(), int(280 * q), 0.75, 1.5, 0.18, 4.0, 0.4)
	_scatter(Props.oil_palm(), int(70 * q), 0.8, 1.2, 0.12, 4.0, 0.35)
	_scatter(Props.sapling(), int(150 * q), 0.7, 1.3, 0.2, 3.0, 0.0)
	_scatter(Props.shrub(), int(160 * q), 0.7, 1.4, 0.2, 2.5, 0.0, true)
	_scatter(Props.fern(), int(160 * q), 0.8, 1.5, 0.15, 2.0, 0.0, true)
	_scatter(Props.elephant_grass(), int(140 * q), 0.8, 1.3, 0.1, 2.5, 0.0, true)
	_scatter(Props.plantain(), int(50 * q), 0.8, 1.2, 0.1, 3.0, 0.0, true)
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
