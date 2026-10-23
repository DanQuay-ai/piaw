class_name Hud extends CanvasLayer
## HUD (bronze plates, compass, subtitles, kill feed, gorilla meter), menus, and touch controls.
signal play_pressed
signal restart_pressed

static var inst: Hud
static var look_delta := Vector2.ZERO
static var touch_mode := false

const GOLD := Color(0.86, 0.66, 0.24)
const RED := Color(0.72, 0.16, 0.1)
const IVORY := Color(0.96, 0.92, 0.84)
const PLATE := Color(0.075, 0.06, 0.045, 0.84)

var f_title: FontFile
var f_ui: FontFile
var f_ui_b: FontFile
var theme_ := Theme.new()
var root: Control
var hud_box: Control
var obj_text: Label
var toast: Label
var toast_t := 0.0
var hp_num: Label
var hp_bar: ProgressBar
var stealth_l: Label
var weapon_l: Label
var blade_l: Label
var ammo_l: Label
var reload_bar: ProgressBar
var gorilla_meter: Control
var gorilla_l: Label
var compass: Control
var cross: Control
var hitmark: Label
var hit_t := 0.0
var vignette: ColorRect
var vig_t := 0.0
var sub_main: Label
var sub_tr: Label
var sub_t := 0.0
var feed: VBoxContainer
var menu: Control
var pause_menu: Control
var end_menu: Control
var end_title: Label
var diff_btn: Button
var pad_l: Label
var touch: Control

func _init() -> void:
	inst = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	f_title = load("res://assets/fonts/cinzel_bold.woff2")
	f_ui = load("res://assets/fonts/barlow_semibold.woff2")
	f_ui_b = load("res://assets/fonts/barlow_bold.woff2")
	var ext: FontFile = load("res://assets/fonts/noto_ext_bold.woff2")  # Twi letters: ɔ ɛ
	for f in [f_title, f_ui, f_ui_b]: f.fallbacks = [ext]
	_theme()
	root = Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); root.theme = theme_
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(root)
	_build_hud(); _build_touch(); _build_menus()
	Input.joy_connection_changed.connect(_on_joy)

func _on_joy(device: int, connected: bool) -> void:
	var n := Input.get_joy_name(device)
	msg(("Controller connected: " + n) if connected else "Controller disconnected")
	_update_pad_label()

func _update_pad_label() -> void:
	if not pad_l: return
	var pads := Input.get_connected_joypads()
	pad_l.text = ("CONTROLLER READY: " + Input.get_joy_name(pads[0])) if pads.size() > 0 else "Controller: press any button on it to wake it up"

# ---------------------------------------------------------------- theme
func _sb(bg: Color, radius := 6, border := Color(0, 0, 0, 0), bw := 0, pad := 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new(); s.bg_color = bg; s.set_corner_radius_all(radius)
	s.border_color = border; s.set_border_width_all(bw)
	s.content_margin_left = pad; s.content_margin_right = pad; s.content_margin_top = pad * 0.6; s.content_margin_bottom = pad * 0.6
	return s

func _plate() -> StyleBoxFlat:
	var s := _sb(PLATE, 4, Color(GOLD.r, GOLD.g, GOLD.b, 0.7), 2, 14)
	s.shadow_color = Color(0, 0, 0, 0.45); s.shadow_size = 8
	s.border_width_top = 1; s.border_width_bottom = 3
	return s

func _theme() -> void:
	theme_.default_font = f_ui; theme_.default_font_size = 20
	theme_.set_stylebox("normal", "Button", _sb(Color(0.1, 0.08, 0.06, 0.85), 4, Color(GOLD.r, GOLD.g, GOLD.b, 0.35), 1))
	theme_.set_stylebox("hover", "Button", _sb(Color(0.2, 0.15, 0.08, 0.95), 4, GOLD, 2))
	theme_.set_stylebox("focus", "Button", _sb(Color(0.2, 0.15, 0.08, 0.95), 4, GOLD, 2))
	theme_.set_stylebox("pressed", "Button", _sb(GOLD, 4, GOLD, 2))
	theme_.set_font("font", "Button", f_title); theme_.set_font_size("font_size", "Button", 21)
	theme_.set_color("font_color", "Button", IVORY); theme_.set_color("font_focus_color", "Button", Color(1, 0.88, 0.6))
	theme_.set_color("font_hover_color", "Button", Color(1, 0.88, 0.6)); theme_.set_color("font_pressed_color", "Button", Color.BLACK)
	theme_.set_stylebox("panel", "PanelContainer", _plate())
	theme_.set_color("font_color", "Label", IVORY)
	theme_.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.75)); theme_.set_constant("shadow_offset_y", "Label", 2); theme_.set_constant("shadow_offset_x", "Label", 1)
	var bg := _sb(Color(0, 0, 0, 0.55), 2, Color(0, 0, 0, 0), 0, 0)
	theme_.set_stylebox("background", "ProgressBar", bg)
	theme_.set_stylebox("fill", "ProgressBar", _sb(RED, 2, Color(0, 0, 0, 0), 0, 0))

func _label(text: String, size := 20, col := IVORY, font: Font = null) -> Label:
	var l := Label.new(); l.text = text; l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col); l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font: l.add_theme_font_override("font", font)
	return l

func _anchor(c: Control, preset: int, pos: Vector2) -> Control:
	c.set_anchors_preset(preset); c.position = pos; c.mouse_filter = Control.MOUSE_FILTER_IGNORE; hud_box.add_child(c); return c

# ---------------------------------------------------------------- HUD
func _build_hud() -> void:
	hud_box = Control.new(); hud_box.set_anchors_preset(Control.PRESET_FULL_RECT); hud_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud_box); hud_box.visible = false
	vignette = ColorRect.new(); vignette.set_anchors_preset(Control.PRESET_FULL_RECT); vignette.color = Color(0.6, 0, 0, 0)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE; hud_box.add_child(vignette)
	# objective (top-left)
	var card := PanelContainer.new(); card.custom_minimum_size = Vector2(360, 0)
	_anchor(card, Control.PRESET_TOP_LEFT, Vector2(22, 22))
	var vb := VBoxContainer.new(); vb.add_theme_constant_override("separation", 2); card.add_child(vb)
	vb.add_child(_label("OBJECTIVE", 13, GOLD, f_title))
	obj_text = _label("", 18); obj_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; obj_text.custom_minimum_size = Vector2(330, 0); vb.add_child(obj_text)
	# compass (top-centre)
	compass = Control.new(); compass.custom_minimum_size = Vector2(420, 34); compass.size = Vector2(420, 34)
	_anchor(compass, Control.PRESET_CENTER_TOP, Vector2(-210, 18)); compass.draw.connect(_draw_compass)
	# toast
	toast = _label("", 22, IVORY, f_ui_b); toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.custom_minimum_size = Vector2(800, 0); _anchor(toast, Control.PRESET_CENTER_TOP, Vector2(-400, 66))
	# kill feed (top-right)
	feed = VBoxContainer.new(); feed.alignment = BoxContainer.ALIGNMENT_BEGIN; feed.custom_minimum_size = Vector2(320, 0)
	_anchor(feed, Control.PRESET_TOP_RIGHT, Vector2(-342, 22))
	# health plate (bottom-left)
	var hp := PanelContainer.new(); _anchor(hp, Control.PRESET_BOTTOM_LEFT, Vector2(22, -112))
	var hb := HBoxContainer.new(); hb.add_theme_constant_override("separation", 12); hp.add_child(hb)
	var cross_l := _label("+", 40, RED, f_ui_b); hb.add_child(cross_l)
	hp_num = _label("100", 40, IVORY, f_ui_b); hp_num.custom_minimum_size = Vector2(70, 0); hb.add_child(hp_num)
	var hv := VBoxContainer.new(); hv.alignment = BoxContainer.ALIGNMENT_CENTER; hb.add_child(hv)
	hp_bar = ProgressBar.new(); hp_bar.custom_minimum_size = Vector2(170, 10); hp_bar.show_percentage = false; hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE; hv.add_child(hp_bar)
	stealth_l = _label("", 14, GOLD, f_ui_b); hv.add_child(stealth_l)
	# gorilla meter (above health)
	gorilla_meter = Control.new(); gorilla_meter.custom_minimum_size = Vector2(240, 40); gorilla_meter.size = Vector2(240, 40)
	_anchor(gorilla_meter, Control.PRESET_BOTTOM_LEFT, Vector2(26, -160)); gorilla_meter.draw.connect(_draw_gorilla)
	# weapon plate (bottom-right)
	var wp := PanelContainer.new(); wp.custom_minimum_size = Vector2(300, 0); _anchor(wp, Control.PRESET_BOTTOM_RIGHT, Vector2(-322, -124))
	var wv := VBoxContainer.new(); wv.add_theme_constant_override("separation", 3); wp.add_child(wv)
	var wh := HBoxContainer.new(); wv.add_child(wh)
	weapon_l = _label("DANE GUN", 24, IVORY, f_title); weapon_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; wh.add_child(weapon_l)
	ammo_l = _label("LOADED", 16, GOLD, f_ui_b); wh.add_child(ammo_l)
	reload_bar = ProgressBar.new(); reload_bar.custom_minimum_size = Vector2(270, 6); reload_bar.show_percentage = false
	reload_bar.add_theme_stylebox_override("fill", _sb(GOLD, 2, Color(0, 0, 0, 0), 0, 0)); reload_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE; wv.add_child(reload_bar)
	blade_l = _label("ROYAL AFENA", 14, Color(1, 1, 1, 0.65), f_ui_b); wv.add_child(blade_l)
	# subtitles (bottom-centre)
	var sb := VBoxContainer.new(); sb.custom_minimum_size = Vector2(800, 0); _anchor(sb, Control.PRESET_CENTER_BOTTOM, Vector2(-400, -170))
	sub_main = _label("", 26, GOLD, f_ui_b); sub_main.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; sb.add_child(sub_main)
	sub_tr = _label("", 17, Color(1, 1, 1, 0.8)); sub_tr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; sb.add_child(sub_tr)
	sub_main.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; sub_main.custom_minimum_size = Vector2(800, 0)
	# crosshair + hit marker
	cross = Control.new(); _anchor(cross, Control.PRESET_CENTER, Vector2.ZERO); cross.draw.connect(_draw_cross)
	hitmark = _label("", 30, Color(1, 0.85, 0.4), f_ui_b); _anchor(hitmark, Control.PRESET_CENTER, Vector2(-10, -24))

func _draw_cross() -> void:
	var c := Color(1, 1, 1, 0.85); var g := 6.0; var L := 8.0
	var p = get_tree().get_first_node_in_group("player")
	if p and p.reloading: c = Color(1, 1, 1, 0.3)
	cross.draw_circle(Vector2.ZERO, 1.6, c)
	for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		cross.draw_line(d * g, d * (g + L), Color(0, 0, 0, 0.5), 4.0, true)
		cross.draw_line(d * g, d * (g + L), c, 2.0, true)

func _draw_compass() -> void:
	var w := compass.size.x; var h := compass.size.y
	compass.draw_rect(Rect2(0, 0, w, h), PLATE)
	compass.draw_rect(Rect2(0, h - 2, w, 2), Color(GOLD.r, GOLD.g, GOLD.b, 0.7))
	var p = get_tree().get_first_node_in_group("player")
	if not p: return
	var yaw: float = -p.global_rotation.y  # 0 = facing -Z (north)
	var fov := deg_to_rad(120.0)
	var f := f_ui_b
	var marks := {"N": 0.0, "NE": PI / 4, "E": PI / 2, "SE": 3 * PI / 4, "S": PI, "SW": -3 * PI / 4, "W": -PI / 2, "NW": -PI / 4}
	for i in 24:
		var a := i * TAU / 24.0
		var d := wrapf(a - yaw, -PI, PI)
		if abs(d) < fov / 2: compass.draw_line(Vector2(w / 2 + d / fov * w, h - 8), Vector2(w / 2 + d / fov * w, h - 3), Color(1, 1, 1, 0.4), 1.0)
	for k in marks:
		var d := wrapf(marks[k] - yaw, -PI, PI)
		if abs(d) < fov / 2:
			var x := w / 2 + d / fov * w
			var fs := 18 if k.length() == 1 else 13
			var sw := f.get_string_size(k, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			compass.draw_string(f, Vector2(x - sw / 2, 20), k, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, GOLD if k == "N" else IVORY)
	var op: Vector3 = Main.inst.objective_pos if Main.inst else Vector3.ZERO
	if op != Vector3.ZERO:
		var v: Vector3 = op - p.global_position
		var a := atan2(v.x, -v.z)
		var d := clampf(wrapf(a - yaw, -PI, PI), -fov / 2, fov / 2)
		var x := w / 2 + d / fov * w
		compass.draw_colored_polygon(PackedVector2Array([Vector2(x, h - 14), Vector2(x - 7, h - 24), Vector2(x, h - 34), Vector2(x + 7, h - 24)]), RED)
		var dist := "%dm" % int(v.length())
		compass.draw_string(f, Vector2(x + 10, h - 18), dist, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.75))
	compass.draw_line(Vector2(w / 2, 0), Vector2(w / 2, 6), GOLD, 2.0)

func _draw_gorilla() -> void:
	var c: float = Main.inst.gorilla_charge if Main.inst else 0.0
	var ready := c >= 1.0
	var ctr := Vector2(20, 20)
	gorilla_meter.draw_circle(ctr, 19, PLATE)
	gorilla_meter.draw_arc(ctr, 16, -PI / 2, -PI / 2 + TAU * c, 40, GOLD if ready else Color(0.6, 0.5, 0.3), 4.0, true)
	var f := f_ui_b
	gorilla_meter.draw_string(f, ctr + Vector2(-7, 7), "!" if ready else "G", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, IVORY)
	var t := "WHISTLE READY  [G / TRIANGLE]" if ready else "GORILLA  %d%%" % int(c * 100)
	if touch_mode and ready: t = "WHISTLE READY"
	gorilla_meter.draw_string(f, Vector2(46, 26), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, GOLD if ready else Color(1, 1, 1, 0.7))

# ---------------------------------------------------------------- menus
func _overlay() -> Control:
	var o := ColorRect.new(); o.set_anchors_preset(Control.PRESET_FULL_RECT); o.color = Color(0.03, 0.02, 0.01, 0.74)
	root.add_child(o); return o

func _center_col(parent: Control) -> VBoxContainer:
	var cc := CenterContainer.new(); cc.set_anchors_preset(Control.PRESET_FULL_RECT); parent.add_child(cc)
	var vb := VBoxContainer.new(); vb.add_theme_constant_override("separation", 12); vb.custom_minimum_size = Vector2(380, 0); cc.add_child(vb)
	return vb

func _btn(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new(); b.text = text; b.custom_minimum_size = Vector2(380, 54); b.pressed.connect(cb); parent.add_child(b); return b

func _build_menus() -> void:
	menu = _overlay()
	var vb := _center_col(menu)
	var logo := TextureRect.new(); logo.texture = load("res://art/logo.png"); logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; logo.custom_minimum_size = Vector2(460, 300); vb.add_child(logo)
	var st2 := _label("THE ANGLO-ASANTE WARS", 15, Color(1, 1, 1, 0.6), f_title); st2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(st2)
	var play := _btn(vb, "PLAY", func(): play_pressed.emit())
	diff_btn = _btn(vb, "", _cycle_diff); _update_diff()
	pad_l = _label("", 14, GOLD, f_ui_b); pad_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(pad_l); _update_pad_label()
	var help := _label("WASD move · mouse look · LMB fire · Q aim · F / RMB afena · C crouch · R reload · X swap gun · V swap afena · G whistle\nPad: sticks · R2 fire · L2 aim · R1 afena · Circle crouch · Square reload · L1 swap · Triangle whistle", 13, Color(1, 1, 1, 0.55))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; help.custom_minimum_size = Vector2(560, 0); vb.add_child(help)
	play.call_deferred("grab_focus")

	pause_menu = _overlay(); pause_menu.visible = false
	var pv := _center_col(pause_menu)
	var pt := _label("PAUSED", 46, IVORY, f_title); pt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; pv.add_child(pt)
	_btn(pv, "RESUME", func(): set_paused(false))
	_btn(pv, "RESTART MISSION", func(): restart_pressed.emit())

	end_menu = _overlay(); end_menu.visible = false
	var ev := _center_col(end_menu)
	end_title = _label("", 46, GOLD, f_title); end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; ev.add_child(end_title)
	_btn(ev, "PLAY AGAIN", func(): restart_pressed.emit())

func _cycle_diff() -> void:
	Game.difficulty = (Game.difficulty + 1) % 3; _update_diff()
func _update_diff() -> void:
	diff_btn.text = "DIFFICULTY:  " + ["EASY", "NORMAL", "HARD"][Game.difficulty]

func _active_menu() -> Control:
	for m in [menu, pause_menu, end_menu]:
		if m.visible: return m
	return null

func show_game() -> void:
	menu.visible = false; end_menu.visible = false; pause_menu.visible = false; hud_box.visible = true
	touch.visible = touch_mode
	get_tree().paused = false
	if not touch_mode: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func set_paused(p: bool) -> void:
	if menu.visible or end_menu.visible: return
	pause_menu.visible = p; get_tree().paused = p
	if p:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		pause_menu.find_children("*", "Button", true, false)[0].grab_focus()
	elif not touch_mode: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func show_end(text: String) -> void:
	end_title.text = text; end_menu.visible = true; get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	end_menu.find_children("*", "Button", true, false)[0].grab_focus()

# ---------------------------------------------------------------- static API
static func msg(s: String) -> void:
	if inst: inst.toast.text = s; inst.toast_t = 2.2
static func objective(s: String) -> void:
	if inst: inst.obj_text.text = s
static func hit() -> void:
	if inst: inst.hitmark.text = "X"; inst.hit_t = 0.25
static func damage() -> void:
	if inst: inst.vig_t = 0.6
static func subtitle(line: String, translation: String) -> void:
	if not inst: return
	inst.sub_main.text = line; inst.sub_tr.text = ("\"" + translation + "\"") if translation != "" else ""; inst.sub_t = 3.5
static func kill_feed(t: String) -> void:
	if not inst: return
	var l := inst._label(t, 15, IVORY, inst.f_ui_b); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.custom_minimum_size = Vector2(320, 0); inst.feed.add_child(l)
	if inst.feed.get_child_count() > 5: inst.feed.get_child(0).queue_free()
	inst.get_tree().create_timer(5.0).timeout.connect(func(): if is_instance_valid(l): l.queue_free())

func _process(dt: float) -> void:
	toast_t -= dt; toast.modulate.a = clampf(toast_t * 2.0, 0.0, 1.0)
	sub_t -= dt; sub_main.modulate.a = clampf(sub_t * 2.0, 0.0, 1.0); sub_tr.modulate.a = sub_main.modulate.a
	hit_t -= dt
	if hit_t <= 0.0: hitmark.text = ""
	vig_t = max(vig_t - dt, 0.0); vignette.color.a = vig_t * 0.5
	var p = get_tree().get_first_node_in_group("player")
	if p and hud_box.visible:
		hp_num.text = str(int(p.hp)); hp_bar.value = p.hp
		hp_num.add_theme_color_override("font_color", RED if p.hp < 35 else IVORY)
		weapon_l.text = p.gun_stats().name
		blade_l.text = p.blade_stats().name + ("   ·   CROUCHED" if p.crouched else "")
		ammo_l.text = "LOADED" if p.loaded else "EMPTY"
		reload_bar.value = 100.0 if p.loaded else p.reload_progress() * 100.0
		var s: float = p.stealth()
		stealth_l.text = "HIDDEN" if s < 0.5 else ("LOW PROFILE" if s < 0.9 else "EXPOSED")
		compass.queue_redraw(); gorilla_meter.queue_redraw(); cross.queue_redraw()
	if Input.is_action_just_pressed("pause"):
		if pause_menu.visible: set_paused(false)
		elif hud_box.visible: set_paused(true)
	elif hud_box.visible and not touch_mode and not get_tree().paused and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and OS.has_feature("web"):
		set_paused(true)
	if touch.visible: touch.queue_redraw()

# ---------------------------------------------------------------- controller in menus
func _input(e: InputEvent) -> void:
	var m := _active_menu()
	if m and (e is InputEventJoypadButton or e is InputEventJoypadMotion):
		if pad_l and pad_l.text.begins_with("Controller:"): _update_pad_label()
		var f := get_viewport().gui_get_focus_owner()
		var btns := m.find_children("*", "Button", true, false)
		if not f or not (f in btns):
			if btns.size() > 0: btns[0].grab_focus()
			get_viewport().set_input_as_handled(); return
		var idx := btns.find(f)
		if e is InputEventJoypadButton and e.pressed:
			if e.button_index == JOY_BUTTON_A: f.emit_signal("pressed"); get_viewport().set_input_as_handled(); return
			if e.button_index == JOY_BUTTON_DPAD_DOWN: btns[(idx + 1) % btns.size()].grab_focus()
			if e.button_index == JOY_BUTTON_DPAD_UP: btns[(idx - 1 + btns.size()) % btns.size()].grab_focus()
			if e.button_index == JOY_BUTTON_START and m == pause_menu: set_paused(false)
			get_viewport().set_input_as_handled(); return
		if e is InputEventJoypadMotion and e.axis == JOY_AXIS_LEFT_Y and abs(e.axis_value) > 0.6 and not _stick_held:
			_stick_held = true
			btns[(idx + (1 if e.axis_value > 0 else -1) + btns.size()) % btns.size()].grab_focus()
		elif e is InputEventJoypadMotion and e.axis == JOY_AXIS_LEFT_Y and abs(e.axis_value) < 0.3:
			_stick_held = false
		get_viewport().set_input_as_handled(); return
	_touch_input(e)

var _stick_held := false

# ---------------------------------------------------------------- touch controls
var joy_idx := -1
var joy_start := Vector2.ZERO
var joy_vec := Vector2.ZERO
var look_idx := -1
var buttons := []  # [center, radius, action, label]

func _build_touch() -> void:
	touch_mode = DisplayServer.is_touchscreen_available() and (OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios"))
	touch = Control.new(); touch.set_anchors_preset(Control.PRESET_FULL_RECT); touch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	touch.draw.connect(_draw_touch); root.add_child(touch); touch.visible = false

func _layout_buttons() -> void:
	var s := root.get_viewport_rect().size
	buttons = [
		[Vector2(s.x - 110, s.y - 120), 62.0, "fire", "FIRE"],
		[Vector2(s.x - 240, s.y - 92), 44.0, "slash", "AFENA"],
		[Vector2(s.x - 110, s.y - 262), 44.0, "aim", "AIM"],
		[Vector2(s.x - 232, s.y - 218), 36.0, "reload", "RLD"],
		[Vector2(s.x - 345, s.y - 70), 36.0, "crouch", "CRCH"],
		[Vector2(s.x - 345, s.y - 168), 32.0, "jump", "JUMP"],
		[Vector2(s.x - 205, s.y - 330), 32.0, "swap_gun", "SWAP"],
		[Vector2(s.x - 315, s.y - 285), 34.0, "whistle", "CALL"],
		[Vector2(s.x - 56, 120), 30.0, "pause", "II"],
	]

func _hit_button(p: Vector2) -> Array:
	for b in buttons:
		if p.distance_to(b[0]) < b[1] + 8: return b
	return []

func _touch_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch or e is InputEventScreenDrag:
		if not touch_mode:
			touch_mode = true
			if hud_box.visible: touch.visible = true; Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif (e is InputEventKey or e is InputEventJoypadButton) and touch_mode:
		touch_mode = false; touch.visible = false
	if not touch.visible: return
	if buttons.is_empty(): _layout_buttons()
	var s := root.get_viewport_rect().size
	if e is InputEventScreenTouch:
		if e.pressed:
			var b := _hit_button(e.position)
			if b:
				if b[2] == "aim":
					if Input.is_action_pressed("aim"): Input.action_release("aim")
					else: Input.action_press("aim")
				elif b[2] == "pause": set_paused(true)
				else: Input.action_press(b[2]); _release_later(b[2])
			elif e.position.x < s.x * 0.42 and joy_idx < 0:
				joy_idx = e.index; joy_start = e.position
			elif look_idx < 0:
				look_idx = e.index
		else:
			if e.index == joy_idx: joy_idx = -1; joy_vec = Vector2.ZERO; _apply_joy()
			if e.index == look_idx: look_idx = -1
	elif e is InputEventScreenDrag:
		if e.index == joy_idx:
			joy_vec = ((e.position - joy_start) / 70.0).limit_length(1.0); _apply_joy()
		elif e.index == look_idx:
			look_delta += e.relative

func _release_later(a: String) -> void:
	await get_tree().create_timer(0.12).timeout
	Input.action_release(a)

func _apply_joy() -> void:
	for pair in [["move_r", joy_vec.x], ["move_l", -joy_vec.x], ["move_b", joy_vec.y], ["move_f", -joy_vec.y]]:
		if pair[1] > 0.05: Input.action_press(pair[0], pair[1])
		else: Input.action_release(pair[0])
	if joy_vec.length() > 0.95 and joy_vec.y < -0.5: Input.action_press("sprint")
	else: Input.action_release("sprint")

func _draw_touch() -> void:
	if buttons.is_empty(): _layout_buttons()
	var s := root.get_viewport_rect().size
	var base := joy_start if joy_idx >= 0 else Vector2(170, s.y - 170)
	touch.draw_circle(base, 80, Color(0, 0, 0, 0.25))
	touch.draw_arc(base, 80, 0, TAU, 48, Color(GOLD.r, GOLD.g, GOLD.b, 0.5), 2.0, true)
	touch.draw_circle(base + joy_vec * 70.0, 34, Color(1, 1, 1, 0.35))
	for b in buttons:
		var on: bool = Input.is_action_pressed(b[2])
		var ready: bool = b[2] == "whistle" and Main.inst and Main.inst.gorilla_charge >= 1.0
		touch.draw_circle(b[0], b[1], Color(GOLD.r, GOLD.g, GOLD.b, 0.8) if on or ready else Color(0.05, 0.04, 0.03, 0.55))
		touch.draw_arc(b[0], b[1], 0, TAU, 40, Color(GOLD.r, GOLD.g, GOLD.b, 0.7), 2.0, true)
		var fs := 15 if b[1] < 50 else 20
		var w := f_ui_b.get_string_size(b[3], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		touch.draw_string(f_ui_b, b[0] + Vector2(-w / 2, fs * 0.35), b[3], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, IVORY)
