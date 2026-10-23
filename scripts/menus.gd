class_name Menus extends Control
## Splash, main menu, mission select, options, controls (with pad remapping), pause and end screens.
## Fully navigable with mouse, touch, keyboard or controller.
signal start_mission(id: String)
signal restart
signal resume

var hud: Hud
var screens := {}
var current := ""
var back_to := "main"
var overlay: ColorRect
var bg_logo: TextureRect
var end_title: Label
var end_score: Label
var pad_label: Label
var waiting_bind := ""      # action currently being remapped
var bind_buttons := {}
var stick_held := false
var pad_diag: Label

func _process(_dt: float) -> void:
	if pad_diag and current == "controls":
		pad_diag.text = "LIVE CONTROLLER CHECK:  " + (PadBridge.info if PadBridge.info != "" else "(desktop build)")

const MISSIONS := [
	{"id": "nsamankow", "title": "NSAMANKOW", "year": "1824", "desc": "Ambush MacCarthy's column in the forest, then storm the hill fort.", "open": true},
	{"id": "asameni", "title": "THE KEYS OF OSU", "year": "1693", "desc": "Asameni and the Akwamu take Christiansborg Castle from the Danes. Fight inside the fort.", "open": false},
	{"id": "canoe", "title": "JOHN CANOE'S FORT", "year": "1711", "desc": "Hold Groß Friedrichsburg at Pokesu against the Dutch, cannon by cannon.", "open": false},
	{"id": "amoaful", "title": "AMOAFUL", "year": "1874", "desc": "Wolseley marches on Kumasi. Bleed his column in the bush.", "open": false},
	{"id": "golden_stool", "title": "THE GOLDEN STOOL", "year": "1900", "desc": "Yaa Asantewaa besieges the Kumasi fort.", "open": false},
]

func _init(h: Hud) -> void:
	hud = h
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = h.theme_

func build() -> void:
	overlay = ColorRect.new(); overlay.set_anchors_preset(Control.PRESET_FULL_RECT); overlay.color = Color(0.03, 0.02, 0.01, 0.78)
	add_child(overlay)
	_splash(); _main(); _missions(); _options(); _controls(); _pause(); _end()
	show_screen("splash")

# ---------------------------------------------------------------- helpers
func _panel(name: String, width := 420.0) -> VBoxContainer:
	var cc := CenterContainer.new(); cc.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(cc)
	var vb := VBoxContainer.new(); vb.add_theme_constant_override("separation", 12); vb.custom_minimum_size = Vector2(width, 0); cc.add_child(vb)
	screens[name] = cc; cc.visible = false
	return vb

func _title(parent: Control, t: String, size := 40) -> void:
	var l := hud._label(t, size, Hud.IVORY, hud.f_title); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; parent.add_child(l)

func _btn(parent: Control, text: String, cb: Callable, h := 54.0) -> Button:
	var b := Button.new(); b.text = text; b.custom_minimum_size = Vector2(0, h * (1.25 if Hud.touch_mode else 1.0)); b.pressed.connect(cb); parent.add_child(b); return b

func _slider(parent: Control, label: String, key: String, lo: float, hi: float) -> void:
	var row := HBoxContainer.new(); parent.add_child(row)
	var l := hud._label(label, 18); l.custom_minimum_size = Vector2(190, 0); row.add_child(l)
	var s := HSlider.new(); s.min_value = lo; s.max_value = hi; s.step = (hi - lo) / 20.0; s.value = Settings.value(key)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL; s.custom_minimum_size = Vector2(0, 40); s.focus_mode = Control.FOCUS_ALL
	var v := hud._label("%d%%" % int(s.value / hi * 100), 16, Hud.GOLD); v.custom_minimum_size = Vector2(56, 0)
	s.value_changed.connect(func(x): Settings.set_value(key, x); v.text = "%d%%" % int(x / hi * 100); Settings.save_cfg())
	row.add_child(s); row.add_child(v)

func _toggle(parent: Control, label: String, key: String) -> void:
	var b := Button.new()
	var upd := func(): b.text = label + ":  " + ("ON" if Settings.value(key) else "OFF")
	upd.call()
	b.custom_minimum_size = Vector2(0, 48)
	b.pressed.connect(func(): Settings.set_value(key, not Settings.value(key)); Settings.save_cfg(); upd.call())
	parent.add_child(b)

func show_screen(n: String) -> void:
	for k in screens: screens[k].visible = k == n
	current = n
	visible = n != ""
	overlay.color.a = 1.0 if n == "splash" else 0.78
	if n != "":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		var f := _focusables()
		if f.size() > 0: f[0].call_deferred("grab_focus")

func _focusables() -> Array:
	if current == "" or not screens.has(current): return []
	var out := []
	for c in screens[current].find_children("*", "", true, false):
		if (c is Button or c is HSlider) and c.is_visible_in_tree() and not (c is Button and c.disabled): out.append(c)
	return out

# ---------------------------------------------------------------- screens
func _splash() -> void:
	var vb := _panel("splash", 640)
	var pre := hud._label("MERANKRON PRESENTS", 18, Color(1, 1, 1, 0.55), hud.f_title); pre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(pre)
	var logo := TextureRect.new(); logo.texture = load("res://art/logo.png"); logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; logo.custom_minimum_size = Vector2(620, 300); vb.add_child(logo)
	var sub := hud._label("SLIDE FOR THE ASAFO", 20, Hud.GOLD, hud.f_title); sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(sub)
	var press := hud._label("PRESS ANY KEY / BUTTON / TAP", 15, Color(1, 1, 1, 0.6), hud.f_ui_b); press.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(press)
	vb.modulate.a = 0.0
	var tw := create_tween(); tw.tween_property(vb, "modulate:a", 1.0, 1.4)
	tw.tween_callback(func(): var t2 := create_tween().set_loops(); t2.tween_property(press, "modulate:a", 0.25, 0.8); t2.tween_property(press, "modulate:a", 1.0, 0.8))

func _main() -> void:
	var vb := _panel("main")
	var logo := TextureRect.new(); logo.texture = load("res://art/logo.png"); logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; logo.custom_minimum_size = Vector2(420, 220); vb.add_child(logo)
	var st := hud._label("THE ANGLO-ASANTE WARS", 15, Color(1, 1, 1, 0.6), hud.f_title); st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(st)
	_btn(vb, "CAMPAIGN", func(): show_screen("missions"))
	_btn(vb, "OPTIONS", func(): back_to = "main"; show_screen("options"))
	_btn(vb, "CONTROLS", func(): back_to = "main"; show_screen("controls"))
	_toggle(vb, "SOUND MUTED", "muted")
	pad_label = hud._label("", 14, Hud.GOLD, hud.f_ui_b); pad_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(pad_label)
	update_pad_label()

func update_pad_label() -> void:
	if not pad_label: return
	var pads := Input.get_connected_joypads()
	pad_label.text = ("CONTROLLER READY: " + Input.get_joy_name(pads[0])) if pads.size() > 0 else "Controller? Press any button on it to wake it up"

func _missions() -> void:
	var vb := _panel("missions", 720)
	_title(vb, "CAMPAIGN", 38)
	for m in MISSIONS:
		var b := Button.new(); b.custom_minimum_size = Vector2(0, 78 * (1.15 if Hud.touch_mode else 1.0))
		b.text = "%s   ·   %s\n%s" % [m.year, m.title, m.desc if m.open else "COMING SOON  ·  " + m.desc]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_override("font", hud.f_ui_b); b.add_theme_font_size_override("font_size", 18)
		if m.open: b.pressed.connect(func(): show_screen(""); start_mission.emit(m.id))
		else: b.modulate = Color(1, 1, 1, 0.45); b.pressed.connect(func(): hud.msg("This mission is still being built"))
		vb.add_child(b)
	_btn(vb, "BACK", func(): show_screen("main"))

func _options() -> void:
	var vb := _panel("options", 560)
	_title(vb, "OPTIONS", 38)
	vb.add_child(hud._label("SOUND", 14, Hud.GOLD, hud.f_title))
	_slider(vb, "Master volume", "master", 0.0, 1.0)
	_slider(vb, "Music", "music", 0.0, 1.0)
	_slider(vb, "Effects", "sfx", 0.0, 1.0)
	_slider(vb, "Voices", "voice", 0.0, 1.0)
	vb.add_child(hud._label("GAMEPLAY & DISPLAY", 14, Hud.GOLD, hud.f_title))
	_slider(vb, "Camera shake", "shake", 0.0, 1.5)
	_toggle(vb, "Colour grading", "grading")
	_toggle(vb, "Shot flashes", "flashes")
	_toggle(vb, "Sound muted", "muted")
	_btn(vb, "BACK", func(): show_screen(back_to))

func _controls() -> void:
	var vb := _panel("controls", 660)
	_title(vb, "CONTROLS", 38)
	_slider(vb, "Mouse / touch look", "mouse_sens", 0.2, 3.0)
	_slider(vb, "Stick look", "pad_sens", 0.2, 3.0)
	_toggle(vb, "Invert look Y", "invert_y")
	_slider(vb, "Touch button size", "touch_scale", 0.7, 1.6)
	pad_diag = hud._label("", 14, Hud.GOLD, hud.f_ui_b); vb.add_child(pad_diag)
	vb.add_child(hud._label("CONTROLLER MAPPING  (pick an action, then press the button or trigger)", 14, Hud.GOLD, hud.f_ui_b))
	var grid := GridContainer.new(); grid.columns = 3; grid.add_theme_constant_override("h_separation", 10); grid.add_theme_constant_override("v_separation", 8); vb.add_child(grid)
	for a in [["fire", "FIRE (R2)"], ["aim", "AIM (L2)"], ["slash", "AFENA (R1)"], ["sprint", "SPRINT (L3)"], ["whistle", "WHISTLE (TRIANGLE)"], ["map", "MAP (TOUCHPAD)"], ["jump", "JUMP (CROSS)"], ["crouch", "CROUCH (CIRCLE)"], ["reload", "RELOAD (SQUARE)"], ["swap_gun", "SWAP GUN (L1)"], ["swap_blade", "SWAP AFENA (D-LEFT)"], ["pause", "PAUSE (OPTIONS)"]]:
		var b := Button.new(); b.custom_minimum_size = Vector2(205, 40); b.text = a[1]; b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(func(): waiting_bind = a[0]; b.text = "PRESS A BUTTON / TRIGGER..."); grid.add_child(b); bind_buttons[a[0]] = [b, a[1]]
	var keys := hud._label("Keyboard: WASD move · Shift sprint · Space jump · C crouch · LMB fire · Q/MMB aim · F/RMB afena · R reload · X swap gun · V swap afena · G whistle · M map · Esc pause", 13, Color(1, 1, 1, 0.6))
	keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; keys.custom_minimum_size = Vector2(620, 0); vb.add_child(keys)
	_btn(vb, "BACK", func(): waiting_bind = ""; show_screen(back_to))

func _pause() -> void:
	var vb := _panel("pause")
	_title(vb, "PAUSED", 44)
	_btn(vb, "RESUME", func(): resume.emit())
	_toggle(vb, "SOUND MUTED", "muted")
	_btn(vb, "OPTIONS", func(): back_to = "pause"; show_screen("options"))
	_btn(vb, "CONTROLS", func(): back_to = "pause"; show_screen("controls"))
	_btn(vb, "RESTART MISSION", func(): restart.emit())

func _end() -> void:
	var vb := _panel("end")
	end_title = hud._label("", 46, Hud.GOLD, hud.f_title); end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(end_title)
	end_score = hud._label("", 22, Hud.IVORY, hud.f_ui_b); end_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(end_score)
	_btn(vb, "PLAY AGAIN", func(): restart.emit())

# ---------------------------------------------------------------- input
func _input(e: InputEvent) -> void:
	if not visible: return
	if current == "splash":
		if (e is InputEventKey or e is InputEventJoypadButton or e is InputEventMouseButton or e is InputEventScreenTouch) and e.is_pressed():
			show_screen("main"); get_viewport().set_input_as_handled()
		return
	if waiting_bind != "" and (e is InputEventJoypadButton and e.pressed or e is InputEventJoypadMotion and abs(e.axis_value) > 0.6):
		var b := {"type": "button", "index": e.button_index, "dir": 0.0} if e is InputEventJoypadButton else {"type": "axis", "index": e.axis, "dir": signf(e.axis_value)}
		Settings.bind_pad(waiting_bind, b); Settings.save_cfg()
		var bb = bind_buttons[waiting_bind]; bb[0].text = bb[1] + "  =  " + ("button %d" % b.index if b.type == "button" else "axis %d" % b.index)
		waiting_bind = ""; get_viewport().set_input_as_handled(); return
	if e is InputEventJoypadButton or e is InputEventJoypadMotion:
		update_pad_label()
		var fs := _focusables()
		if fs.is_empty(): return
		var f := get_viewport().gui_get_focus_owner()
		if not (f in fs): fs[0].grab_focus(); get_viewport().set_input_as_handled(); return
		var i := fs.find(f)
		var dy := 0; var dx := 0
		if e is InputEventJoypadButton and e.pressed:
			match e.button_index:
				JOY_BUTTON_A:
					if f is Button: f.emit_signal("pressed")
				JOY_BUTTON_B:
					if current in ["options", "controls"]: show_screen(back_to)
					elif current == "missions": show_screen("main")
					elif current == "pause": resume.emit()
				JOY_BUTTON_DPAD_DOWN: dy = 1
				JOY_BUTTON_DPAD_UP: dy = -1
				JOY_BUTTON_DPAD_LEFT: dx = -1
				JOY_BUTTON_DPAD_RIGHT: dx = 1
				JOY_BUTTON_START:
					if current == "pause": resume.emit()
		elif e is InputEventJoypadMotion and (e.axis == JOY_AXIS_LEFT_Y or e.axis == JOY_AXIS_LEFT_X):
			if abs(e.axis_value) > 0.6 and not stick_held:
				stick_held = true
				if e.axis == JOY_AXIS_LEFT_Y: dy = 1 if e.axis_value > 0 else -1
				else: dx = 1 if e.axis_value > 0 else -1
			elif abs(e.axis_value) < 0.3: stick_held = false
		if dy != 0: fs[(i + dy + fs.size()) % fs.size()].grab_focus()
		if dx != 0 and f is HSlider: f.value += f.step * dx
		get_viewport().set_input_as_handled()
