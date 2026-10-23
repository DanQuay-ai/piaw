class_name Buildings
## Asante architecture: white plaster walls, polished red-earth dado with spiral reliefs,
## open pillared fronts, steep thatched roofs. Courtyard compounds and street rows.

const WALL_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform float half_h = 1.5;
uniform float dado = 1.1;
varying vec3 lp;
varying vec3 ln;
float h21(vec2 p){ return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float vn(vec2 p){ vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
  return mix(mix(h21(i),h21(i+vec2(1,0)),f.x), mix(h21(i+vec2(0,1)),h21(i+vec2(1,1)),f.x), f.y); }
void vertex(){ lp = VERTEX; ln = NORMAL; }
void fragment(){
  vec2 uv = abs(ln.x) > 0.5 ? lp.zy : (abs(ln.y) > 0.5 ? lp.xz : lp.xy);
  float y = lp.y + half_h;
  float grime = vn(uv*3.0)*0.5 + vn(uv*11.0)*0.25;
  vec3 plaster = vec3(0.88,0.84,0.74) * (0.85 + 0.2*grime);
  plaster = mix(plaster, vec3(0.62,0.5,0.38), smoothstep(0.6, 0.0, y) * 0.4);
  vec3 col = plaster;
  if (y < dado) {
    vec3 red = vec3(0.42,0.15,0.08) * (0.8 + 0.3*grime);
    vec2 c = fract(uv * vec2(1.4, 1.4)) - 0.5;
    float r = length(c); float a = atan(c.y, c.x);
    float sp = sin(r * 38.0 - a * 2.0);
    float relief = smoothstep(0.55, 0.95, sp) * step(r, 0.42);
    float band = step(abs(y - dado + 0.06), 0.05);
    col = mix(red, red * 1.9 + 0.05, relief * 0.6);
    col = mix(col, plaster * 0.9, band);
  }
  // fine crack network
  float cr = smoothstep(0.03, 0.0, abs(vn(uv*6.0) - 0.5));
  col *= 1.0 - cr * 0.25;
  ALBEDO = col;
  ROUGHNESS = y < dado ? 0.55 : 0.95;
}
"""

const THATCH_SHADER := """
shader_type spatial;
render_mode cull_disabled;
varying vec3 wp;
float h21(vec2 p){ return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float vn(vec2 p){ vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
  return mix(mix(h21(i),h21(i+vec2(1,0)),f.x), mix(h21(i+vec2(0,1)),h21(i+vec2(1,1)),f.x), f.y); }
void vertex(){ wp = VERTEX; }
void fragment(){
  vec2 uv = UV * vec2(70.0, 6.0);
  float streak = vn(vec2(uv.x, uv.y * 0.15)) * 0.6 + vn(uv * vec2(3.0, 0.5)) * 0.4;
  float layers = smoothstep(0.2, 1.0, fract(UV.y * 9.0));
  vec3 straw = mix(vec3(0.16,0.13,0.09), vec3(0.34,0.28,0.19), streak);
  straw *= 0.75 + 0.3 * layers;
  ALBEDO = straw;
  ROUGHNESS = 1.0;
}
"""

static var wall_mat: ShaderMaterial
static var thatch_mat: ShaderMaterial
static var floor_mat: StandardMaterial3D
static var wood_mat: StandardMaterial3D

static func init_materials() -> void:
	var ws := Shader.new(); ws.code = WALL_SHADER
	wall_mat = ShaderMaterial.new(); wall_mat.shader = ws
	var ts := Shader.new(); ts.code = THATCH_SHADER
	thatch_mat = ShaderMaterial.new(); thatch_mat.shader = ts
	floor_mat = Props.laterite
	wood_mat = Props.bark

static func _wall(parent: Node3D, size: Vector3, pos: Vector3, body: StaticBody3D) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm
	var m: ShaderMaterial = wall_mat.duplicate()
	m.set_shader_parameter("half_h", size.y / 2.0)
	m.set_shader_parameter("dado", min(1.1, size.y * 0.45))
	mi.material_override = m; mi.position = pos; parent.add_child(mi)
	var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = size; cs.shape = sh; cs.position = pos
	body.add_child(cs)

static func _roof_mesh(w: float, d: float, rise: float, over: float) -> ArrayMesh:
	## steep gable roof with thick eaves, UV.y runs ridge -> eave
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := w / 2.0 + over; var hd := d / 2.0 + over
	var ridge_l := Vector3(-hw + over * 0.6, rise, 0); var ridge_r := Vector3(hw - over * 0.6, rise, 0)
	var eave := -over * 0.5
	var quads := [
		[ridge_l, ridge_r, Vector3(hw, eave, hd), Vector3(-hw, eave, hd)],
		[ridge_r, ridge_l, Vector3(-hw, eave, -hd), Vector3(hw, eave, -hd)],
	]
	for q in quads:
		var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_uv(uvs[idx]); st.add_vertex(q[idx])
	# hipped ends
	for side in [-1.0, 1.0]:
		var r: Vector3 = ridge_r if side > 0 else ridge_l
		var a := Vector3(hw * side, eave, hd); var b := Vector3(hw * side, eave, -hd)
		st.set_uv(Vector2(0.5, 0)); st.add_vertex(r)
		st.set_uv(Vector2(0, 1)); st.add_vertex(a if side > 0 else b)
		st.set_uv(Vector2(1, 1)); st.add_vertex(b if side > 0 else a)
	st.generate_normals()
	return st.commit()

## One open-fronted Asante building. Front (open side, with pillars) faces local +Z.
static func house(parent: Node3D, pos: Vector3, yaw: float, w := 8.0, d := 4.5, h := 3.0) -> void:
	var root := Node3D.new(); root.position = pos; root.rotation.y = yaw; parent.add_child(root)
	var body := StaticBody3D.new(); root.add_child(body)
	var plinth := 0.55
	_wall(root, Vector3(w + 0.6, plinth, d + 0.6), Vector3(0, plinth / 2.0, 0), body)  # raised platform
	var y0 := plinth
	_wall(root, Vector3(w, h, 0.3), Vector3(0, y0 + h / 2, -d / 2), body)          # back
	_wall(root, Vector3(0.3, h, d), Vector3(-w / 2, y0 + h / 2, 0), body)          # sides
	_wall(root, Vector3(0.3, h, d), Vector3(w / 2, y0 + h / 2, 0), body)
	var cols := 4
	for i in cols:  # square pillars across the open front
		var x: float = lerp(-w / 2 + 0.3, w / 2 - 0.3, float(i) / (cols - 1))
		_wall(root, Vector3(0.45, h, 0.45), Vector3(x, y0 + h / 2, d / 2 - 0.2), body)
	_wall(root, Vector3(w, 0.5, 0.35), Vector3(0, y0 + h - 0.25, d / 2 - 0.2), body)  # lintel
	# wooden eave props (as in old Kumasi photos)
	for i in 3:
		var p := MeshInstance3D.new(); var c := CylinderMesh.new(); c.top_radius = 0.06; c.bottom_radius = 0.08; c.height = h + 0.6; c.radial_segments = 5
		p.mesh = c; p.material_override = wood_mat; p.position = Vector3(lerp(-w / 3, w / 3, i / 2.0), (h + 0.6) / 2 + y0 - 0.3, d / 2 + 0.9); p.rotation.x = -0.12
		root.add_child(p)
	var roof := MeshInstance3D.new(); roof.mesh = _roof_mesh(w, d, h * 1.15, 1.3)
	roof.material_override = thatch_mat; roof.position.y = y0 + h; root.add_child(roof)
	var rc := CollisionShape3D.new(); var rs := BoxShape3D.new(); rs.size = Vector3(w + 1, 1.5, d + 1); rc.shape = rs; rc.position.y = y0 + h + 0.9; body.add_child(rc)

## Four buildings around a square courtyard, all opening inward.
static func compound(parent: Node3D, c: Vector3, yaw := 0.0) -> void:
	var root := Node3D.new(); root.position = c; root.rotation.y = yaw; parent.add_child(root)
	var s := 6.8
	house(root, Vector3(0, 0, -s), 0.0)
	house(root, Vector3(0, 0, s), PI)
	house(root, Vector3(-s, 0, 0), PI / 2, 7.0)
	house(root, Vector3(s, 0, 0), -PI / 2, 7.0)
