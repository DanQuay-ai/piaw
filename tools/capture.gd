extends SceneTree
var f := 0
func _initialize() -> void:
	Main.mission_id = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "nsamankow"
	change_scene_to_file("res://scenes/main.tscn")
func _snap(n: String) -> void:
	get_root().get_texture().get_image().save_png("/tmp/c_%s_%s.png" % [Main.mission_id, n])
func _process(_dt: float) -> bool:
	f += 1
	var m = Main.inst
	if f == 20:
		m.hud.show_game(); m._begin_stage(0); m.player.god = true
	if f == 34: _snap("start")
	if f == 35:
		var c: Vector3 = m._fort_c() if World.HAS_FORT else Vector3(World.VILLAGE.x, m.world.village_h, World.VILLAGE.y)
		m.player.global_position = c + Vector3(0, 2, 40); m.player.rotation.y = 0.0; m.player.cam.rotation.x = 0.05
	if f == 48: _snap("fort")
	if f == 49: m.player.global_position = m.player.global_position + Vector3(0, 0, -36)
	if f == 60: _snap("inside"); return true
	return false
