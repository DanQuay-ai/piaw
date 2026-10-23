extends SceneTree
## Dev tool: renders screenshots of key locations.  godot --path . -s tools/capture.gd
var f := 0
var shots := []
func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
func _process(_dt: float) -> bool:
	f += 1
	var m = Main.inst
	if f == 30:
		get_root().get_texture().get_image().save_png("/tmp/c_menu.png")
		m.hud.show_game(); m._start_ambush(); m.player.hp = 99999; Game.difficulty = 0
		var W = World.inst
		shots = [
			["spawn", m.player.position, 0.0, 0.0],
			["road", Vector3(W.path_x(55), W.height(W.path_x(55), 55) + 1, 55), 0.2, -0.05],
			["river", Vector3(10, W.height(10, 12) + 1, 12), 0.6, -0.1],
			["village", Vector3(World.VILLAGE.x, W.village_h + 1, World.VILLAGE.y + 28), 0.0, 0.0],
			["compound", Vector3(World.VILLAGE.x - 24, W.village_h + 1, World.VILLAGE.y - 6), 0.9, 0.0],
			["lake", Vector3(-40, W.height(-40, 30) + 1, 30), 1.57, -0.1],
			["fort", Vector3(0, W.height(0, -72) + 1, -72), 0.0, 0.1],
			["fort_in", Vector3(0, W.fort_top + 1, World.FORT.y + 4), PI, -0.1],
			["column", Vector3(W.path_x(52), W.height(W.path_x(52), 52) + 1, 52), 0.0, 0.0],
		]
	if f > 40 and shots.size() > 0 and f % 12 == 0:
		var s = shots[0]
		m.player.position = s[1]; m.player.rotation.y = s[2]; m.player.cam.rotation.x = s[3]
	if f > 40 and shots.size() > 0 and f % 12 == 11:
		var s = shots.pop_front()
		get_root().get_texture().get_image().save_png("/tmp/c_%s.png" % s[0])
		print("shot ", s[0], " fps ", Engine.get_frames_per_second())
	if f > 40 and shots.is_empty(): return true
	return false
