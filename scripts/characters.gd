class_name Characters
## Loads rigged Meshy characters and attaches their animation clips (assets/anims/<id>__<clip>.res).
const DIR := "res://assets/characters/"
const ANIM_DIR := "res://assets/anims/"
const CLIPS := ["idle", "walk", "run", "sneak", "charge", "shoot", "reload", "die", "hit", "slash", "cheer", "maul", "roar"]
static var _libs := {}

static func exists(id: String) -> bool:
	return ResourceLoader.exists(DIR + id + ".glb")

static func _lib(id: String) -> AnimationLibrary:
	if _libs.has(id): return _libs[id]
	var lib := AnimationLibrary.new()
	for c in CLIPS:
		var p: String = ANIM_DIR + id + "__" + c + ".res"
		if ResourceLoader.exists(p): lib.add_animation(c, load(p))
	_libs[id] = lib
	return lib

## Returns the model root; its AnimationPlayer has the clips under "m/<clip>".
static func spawn(id: String) -> Node3D:
	var m: Node3D = load(DIR + id + ".glb").instantiate()
	var ap: AnimationPlayer = m.find_child("AnimationPlayer", true, false)
	if not ap:
		ap = AnimationPlayer.new(); ap.name = "AnimationPlayer"; m.add_child(ap)
	ap.add_animation_library("m", _lib(id))
	m.rotation.y = PI  # Meshy models face +Z, Godot forward is -Z
	return m

static func has(model: Node3D, anim: String) -> bool:
	if not model: return false
	var ap: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	return ap != null and ap.has_animation("m/" + anim)

static func play(model: Node3D, anim: String, speed := 1.0, restart := false) -> void:
	if not model: return
	var ap: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	if not ap: return
	var n := "m/" + anim
	if not ap.has_animation(n):
		n = "m/idle"
		if not ap.has_animation(n):
			if ap.is_playing(): ap.pause()
			return
	if ap.current_animation != n or restart: ap.play(n, 0.2)
	ap.speed_scale = speed

static func length(model: Node3D, anim: String) -> float:
	var ap: AnimationPlayer = model.find_child("AnimationPlayer", true, false) if model else null
	if ap and ap.has_animation("m/" + anim): return ap.get_animation("m/" + anim).length
	return 0.0
