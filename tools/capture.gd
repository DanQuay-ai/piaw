extends SceneTree
## Dev tool: renders screenshots.  godot --path . -s tools/capture.gd
var f := 0
var shots := []
func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
func _snap(n: String) -> void:
	get_root().get_texture().get_image().save_png("/tmp/c_%s.png" % n); print("shot ", n)
func _process(_dt: float) -> bool:
	f += 1
	var m = Main.inst
	if f == 20: _snap("splash"); m.hud.menus.show_screen("main")
	if f == 26: _snap("main"); m.hud.menus.show_screen("missions")
	if f == 32: _snap("missions"); m.hud.menus.show_screen("options")
	if f == 38: _snap("options"); m.hud.menus.show_screen("controls")
	if f == 44:
		_snap("controls")
		m.hud.show_game(); m._start_ambush(); m.player.god = true
		var W = World.inst
		var e0 = m.get_tree().get_nodes_in_group("enemy")[0]
		m.player.position = e0.global_position + Vector3(0, 0.3, 10); m.player.rotation.y = 0
		m.player.cam.rotation.x = 0.02
		Main.inst.score_hit(e0, "You shot the British soldier in the forehead", 150, true, true)
	if f == 58: _snap("hud")
	if f == 60: m.hud.bigmap.visible = true
	if f == 64: _snap("bigmap"); m.hud.bigmap.visible = false; Hud.touch_mode = true; m.hud.touch.visible = true
	if f == 70: _snap("touch"); Hud.touch_mode = false; m.hud.touch.visible = false; m.gorilla_charge = 1.0; m.whistle()
	if f == 110: _snap("gorilla")
	if f == 112:
		var W = World.inst
		m.player.position = Vector3(-30, W.height(-30, 60) + 1, 60); m.player.rotation.y = 0.4
	if f == 124: _snap("bush"); return true
	return false
