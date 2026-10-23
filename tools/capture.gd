extends SceneTree
var f := 0
func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
func _snap(n: String) -> void:
	get_root().get_texture().get_image().save_png("/tmp/c_%s.png" % n)
func _process(_dt: float) -> bool:
	f += 1
	var m = Main.inst
	if f == 20: m.hud.menus.show_screen("controls")
	if f == 26:
		_snap("controls"); m.hud.show_game(); m._start_ambush(); m.player.god = true
		var W = World.inst
		m.player.position = Vector3(W.path_x(70), W.height(W.path_x(70), 70) + 1, 70); m.player.rotation.y = 0.1
	if f == 40: _snap("hands")
	if f == 41: m.player.gun_i = 1; m.player._equip()
	if f == 52: _snap("hands2"); m.player.gun.visible = false; m.player.blade.visible = true; m.player.blade.position = Vector3(0.25, -0.2, -0.25); m.player.blade.rotation = Vector3(0.3, 0.3, 0.5); m.player.set_physics_process(false)
	if f == 60: _snap("blade"); m.player.set_physics_process(true); m.player.blade.visible = false; m.player._equip(); m.player.loaded = true; m.player._fire()
	if f == 62: _snap("fire"); return true
	return false
