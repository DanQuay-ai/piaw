class_name Weapons
## Weapon stats + loading/auto-fitting the Meshy weapon models.
const GUNS := {
	"dane_gun": {"name": "DANE GUN", "len": 1.25, "dmg": 100.0, "reload": 3.0, "pellets": 1, "spread": 0.004, "zoom": 42.0, "range": 160.0, "flip": true},
	"long_dane": {"name": "LONG DANE", "len": 1.55, "dmg": 160.0, "reload": 4.2, "pellets": 1, "spread": 0.001, "zoom": 22.0, "range": 260.0, "flip": true},
	"blunderbuss": {"name": "BLUNDERBUSS", "len": 0.85, "dmg": 40.0, "reload": 3.4, "pellets": 7, "spread": 0.07, "zoom": 60.0, "range": 35.0, "flip": true},
}
const BLADES := {
	"afena_royal": {"name": "ROYAL AFENA", "len": 0.8, "dmg": 60.0, "cd": 0.45, "reach": 2.5, "flip": false},
	"afena_war": {"name": "WAR AFENA", "len": 0.9, "dmg": 95.0, "cd": 0.7, "reach": 2.9, "flip": false},
}
const ORDER_GUNS := ["dane_gun", "long_dane", "blunderbuss"]
const ORDER_BLADES := ["afena_royal", "afena_war"]

static func _aabb(n: Node, xf: Transform3D, box: Array) -> void:
	if n is MeshInstance3D:
		var b: AABB = (xf * n.transform) * n.get_aabb()
		box[0] = b if box[0] == null else box[0].merge(b)
	for c in n.get_children():
		if c is Node3D: _aabb(c, xf * (n.transform if n is Node3D else Transform3D()), box)

## Loads a weapon GLB and returns a pivot whose longest axis lies along -Z, scaled to `length` metres.
static func model(id: String, length: float, flip := false) -> Node3D:
	var pivot := Node3D.new()
	var path := "res://assets/weapons/" + id + ".glb"
	if not ResourceLoader.exists(path): return pivot
	var m: Node3D = load(path).instantiate()
	var box := [null]; _aabb(m, Transform3D(), box)
	if box[0] == null: pivot.add_child(m); return pivot
	var b: AABB = box[0]
	var s := b.size
	var basis := Basis()
	if s.x >= s.y and s.x >= s.z: basis = Basis(Vector3.UP, PI / 2)       # X -> Z
	elif s.y >= s.x and s.y >= s.z: basis = Basis(Vector3.RIGHT, -PI / 2)  # Y -> Z
	if flip: basis = Basis(Vector3.UP, PI) * basis
	var k: float = length / max(s.x, max(s.y, s.z))
	var holder := Node3D.new(); holder.transform = Transform3D(basis.scaled(Vector3.ONE * k), Vector3.ZERO)
	m.position = -b.get_center()
	holder.add_child(m); holder.position = Vector3(0, 0, -length * 0.42); pivot.add_child(holder)  # pivot at the butt / hilt
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return pivot
