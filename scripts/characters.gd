class_name Characters
## Loads rigged Meshy characters and attaches the shared walk / run clips.
const DIR := "res://assets/characters/"
static var _libs := {}

static func exists(id: String) -> bool:
	return ResourceLoader.exists(DIR + id + ".glb")

static func _clip(id: String, kind: String) -> Animation:
	var key := id + kind
	if _libs.has(key): return _libs[key]
	var path := DIR + id + "__" + kind + "_armature.glb"
	var a: Animation = null
	if ResourceLoader.exists(path):
		var s: Node = load(path).instantiate()
		var ap: AnimationPlayer = s.find_child("AnimationPlayer", true, false)
		if ap and ap.get_animation_list().size() > 0:
			a = ap.get_animation(ap.get_animation_list()[0]).duplicate()
			a.loop_mode = Animation.LOOP_LINEAR
		s.free()
	_libs[key] = a
	return a

## Returns the model root; its AnimationPlayer has "walk" and "run".
static func spawn(id: String) -> Node3D:
	var m: Node3D = load(DIR + id + ".glb").instantiate()
	var ap: AnimationPlayer = m.find_child("AnimationPlayer", true, false)
	if ap:
		var lib := AnimationLibrary.new()
		for k in [["walk", "walking"], ["run", "running"]]:
			var c := _clip(id, k[1])
			if c: lib.add_animation(k[0], c)
		ap.add_animation_library("m", lib)
	m.rotation.y = PI  # Meshy models face +Z, Godot forward is -Z
	return m

static func play(model: Node3D, anim: String, speed := 1.0) -> void:
	if not model: return
	var ap: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	if not ap: return
	var n := "m/" + anim
	if anim == "" or not ap.has_animation(n):
		if ap.is_playing(): ap.pause()
		return
	if ap.current_animation != n: ap.play(n, 0.2)
	ap.speed_scale = speed
