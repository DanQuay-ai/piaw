extends SceneTree
## Converts assets/raw_anims/<char>__<clip>.glb into lightweight assets/anims/<char>__<clip>.res
const LOOP := ["idle", "walk", "run", "sneak", "charge"]
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/anims")
	var d := DirAccess.open("res://assets/raw_anims")
	for f in d.get_files():
		if not f.ends_with(".glb"): continue
		var s: Node = load("res://assets/raw_anims/" + f).instantiate()
		var ap: AnimationPlayer = s.find_child("AnimationPlayer", true, false)
		if ap and ap.get_animation_list().size() > 0:
			var a: Animation = ap.get_animation(ap.get_animation_list()[0]).duplicate(true)
			var clip := f.get_basename().split("__")[1]
			a.loop_mode = Animation.LOOP_LINEAR if clip in LOOP else Animation.LOOP_NONE
			for t in a.get_track_count():  # keep clips in place: lock hips X/Z
				if a.track_get_type(t) == Animation.TYPE_POSITION_3D and String(a.track_get_path(t)).to_lower().ends_with("hips"):
					var p0: Vector3 = a.track_get_key_value(t, 0)
					for k in a.track_get_key_count(t):
						var v: Vector3 = a.track_get_key_value(t, k); a.track_set_key_value(t, k, Vector3(p0.x, v.y, p0.z))
			ResourceSaver.save(a, "res://assets/anims/" + f.get_basename() + ".res")
			print("saved ", f.get_basename(), " ", a.length)
		s.free()
	quit()
