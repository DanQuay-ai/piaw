extends SceneTree
## Dev tool: renders screenshots.  godot --path . -s tools/capture.gd
var f := 0
var shots := []
var cur = null
func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
func _process(_dt: float) -> bool:
	f += 1
	var m = Main.inst
	if f == 30:
		get_root().get_texture().get_image().save_png("/tmp/c_menu.png")
		m.hud.show_game(); m._start_ambush(); m.player.hp = 99999; Game.difficulty = 0
		var W = World.inst
		var e0 = m.get_tree().get_nodes_in_group("enemy")[0]
		shots = [
			["slash", Vector3(W.path_x(70), W.height(W.path_x(70), 70) + 1, 70), 0.1, 0.0, {"slash": true}],
		]
	if f > 40 and f % 14 == 0 and shots.size() > 0:
		var s = shots[0]
		m.player.position = s[1]; m.player.rotation.y = s[2]; m.player.cam.rotation.x = s[3]
		if s[4].has("gun"): m.player.gun_i = s[4].gun; m.player._equip()
		if s[4].has("aim"): Input.action_press("aim")
		else: Input.action_release("aim")
		if s[4].has("slash"): m.player.gun.visible = false; m.player.blade.visible = true; m.player.blade.position = Vector3(0.25, -0.2, -0.2); m.player.blade.rotation = Vector3(0.3, 0.3, 0.5); m.player.set_physics_process(false)
		if s[4].has("gorilla"): m.gorilla_charge = 1.0; m.whistle()
	if f > 40 and f % 14 == (3 if shots.size() > 0 and shots[0][4].has("slash") else 13) and shots.size() > 0:
		var s = shots.pop_front()
		get_root().get_texture().get_image().save_png("/tmp/c_%s.png" % s[0])
		print("shot ", s[0])
	if f > 40 and shots.is_empty(): return true
	return false
