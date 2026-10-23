class_name Hud extends CanvasLayer
## Modern HUD, start / pause / end menus, and touch controls (mobile).
signal play_pressed
signal restart_pressed

static var inst: Hud
static var look_delta := Vector2.ZERO
static var touch_mode := false

const ACCENT := Color(0.86, 0.64, 0.16)
const RED := Color(0.78, 0.2, 0.14)
const PANEL := Color(0.05, 0.05, 0.05, 0.62)

var theme_ := Theme.new()
var root: Control
var obj_title: Label
var obj_text: Label
var toast: Label
var toast_t := 0.0
var hp_bar: ProgressBar
var weapon_l: Label
var reload_bar: ProgressBar
var stealth_pill: Label
var cross: Control
var hitmark: Label
var hit_t := 0.0
var vignette: ColorRect
var vig_t := 0.0
var menu: Control
var pause_menu: Control
var end_menu: Control
var end_title: Label
var diff_btn: Button
var touch: Control
var hud_box: Control

func _init() -> void:
	inst = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	_theme()
	root = Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); root.theme = theme_
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(root)
	_build_hud(); _build_touch(); _build_menus()

# ---------------------------------------------------------------- theme
func _sb(bg: Color, radius := 14, border := Color(0, 0, 0, 0), bw := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new(); s.bg_color = bg; s.set_corner_radius_all(radius)
	s.border_color = border; s.set_border_width_all(bw)
	s.content_margin_left = 18; s.content_margin_right = 18; s.content_margin_top = 10; s.content_margin_bottom = 10
	return s

func _theme() -> void:
	theme_.default_font_size = 20
	theme_.set_stylebox("normal", "Button", _sb(Color(1, 1, 1, 0.08), 12, Color(1, 1, 1, 0.15), 1))
	theme_.set_stylebox("hover", "Button", _sb(Color(1, 1, 1, 0.16), 12, ACCENT, 2))
	theme_.set_stylebox("focus", "Button", _sb(Color(1, 1, 1, 0.16), 12, ACCENT, 2))
	theme_.set_stylebox("pressed", "Button", _sb(ACCENT, 12, ACCENT, 2))
	theme_.set_color("font_color", "Button", Color(0.95, 0.93, 0.88))
	theme_.set_color("font_pressed_color", "Button", Color.BLACK)
	theme_.set_font_size("font_size", "Button", 22)
	theme_.set_stylebox("panel", "PanelContainer", _sb(PANEL, 16))
	theme_.set_color("font_color", "Label", Color(0.96, 0.94, 0.9))
	theme_.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.6))
	theme_.set_constant("shadow_offset_y", "Label", 2)
	var bg := _sb(Color(0, 0, 0, 0.5), 6); bg.content_margin_top = 0; bg.content_margin_bottom = 0
	theme_.set_stylebox("background", "ProgressBar", bg)
	theme_.set_stylebox("fill", "ProgressBar", _sb(RED, 6))

func _label(text: String, size := 20, col := Color(0.96, 0.94, 0.9)) -> Label:
	var l := Label.new(); l.text = text; l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col); l.mouse_filter = Control.MOUSE_FILTER_IGNORE; return l

# ---------------------------------------------------------------- HUD
func _build_hud() -> void:
	hud_box = Control.new(); hud_box.set_anchors_preset(Control.PRESET_FULL_RECT); hud_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud_box); hud_box.visible = false
	vignette = ColorRect.new(); vignette.set_anchors_preset(Control.PRESET_FULL_RECT); vignette.color = Color(0.6, 0, 0, 0)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE; hud_box.add_child(vignette)
	# objective card (top-left)
	var card := PanelContainer.new(); card.position = Vector2(24, 24); card.custom_minimum_size = Vector2(380, 0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE; hud_box.add_child(card)
	var hb := HBoxContainer.new(); card.add_child(hb)
	var bar := ColorRect.new(); bar.color = ACCENT; bar.custom_minimum_size = Vector2(4, 0); hb.add_child(bar)
	var vb := VBoxContainer.new(); vb.add_theme_constant_override("separation", 2); hb.add_child(vb)
	obj_title = _label("OBJECTIVE", 13, ACCENT); vb.add_child(obj_title)
	obj_text = _label("", 19); obj_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; obj_text.custom_minimum_size = Vector2(340, 0); vb.add_child(obj_text)
	# toast (top-centre)
	toast = _label("", 22); toast.set_anchors_preset(Control.PRESET_CENTER_TOP); toast.position.y = 90
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast.custom_minimum_size = Vector2(700, 0); toast.position.x = -350; hud_box.add_child(toast)
	# health (bottom-left)
	var hp_box := VBoxContainer.new(); hp_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hp_box.position = Vector2(28, -84); hp_box.mouse_filter = Control.MOUSE_FILTER_IGNORE; hud_box.add_child(hp_box)
	stealth_pill = _label("", 14, ACCENT); hp_box.add_child(stealth_pill)
	hp_bar = ProgressBar.new(); hp_bar.custom_minimum_size = Vector2(260, 14); hp_bar.show_percentage = false; hp_bar.value = 100
	hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE; hp_box.add_child(hp_bar)
	hp_box.add_child(_label("HEALTH", 12, Color(1, 1, 1, 0.6)))
	# weapon (bottom-right)
	var wbox := VBoxContainer.new(); wbox.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	wbox.position = Vector2(-300, -96); wbox.alignment = BoxContainer.ALIGNMENT_END; wbox.mouse_filter = Control.MOUSE_FILTER_IGNORE; hud_box.add_child(wbox)
	weapon_l = _label("DANE GUN", 22); weapon_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; weapon_l.custom_minimum_size = Vector2(270, 0); wbox.add_child(weapon_l)
	reload_bar = ProgressBar.new(); reload_bar.custom_minimum_size = Vector2(270, 6); reload_bar.show_percentage = false
	reload_bar.add_theme_stylebox_override("fill", _sb(ACCENT, 4)); reload_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE; wbox.add_child(reload_bar)
	wbox.add_child(_r(_label("AFENA READY", 13, Color(1, 1, 1, 0.6))))
	# crosshair
	cross = Control.new(); cross.set_anchors_preset(Control.PRESET_CENTER); cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cross.draw.connect(_draw_cross); hud_box.add_child(cross)
	hitmark = _label("", 28, Color(1, 0.85, 0.4)); hitmark.set_anchors_preset(Control.PRESET_CENTER); hitmark.position = Vector2(-10, -22); hud_box.add_child(hitmark)

func _r(l: Label) -> Label: l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; l.custom_minimum_size = Vector2(270, 0); return l

func _draw_cross() -> void:
	var c := Color(1, 1, 1, 0.85); var g := 6.0; var L := 9.0
	cross.draw_circle(Vector2.ZERO, 1.8, c)
	for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		cross.draw_line(d * g, d * (g + L), c, 2.0, true)

# ---------------------------------------------------------------- menus
func _overlay() -> Control:
	var o := ColorRect.new(); o.set_anchors_preset(Control.PRESET_FULL_RECT); o.color = Color(0.03, 0.02, 0.01, 0.72)
	root.add_child(o); return o

func _center_col(parent: Control) -> VBoxContainer:
	var cc := CenterContainer.new(); cc.set_anchors_preset(Control.PRESET_FULL_RECT); parent.add_child(cc)
	var vb := VBoxContainer.new(); vb.add_theme_constant_override("separation", 14); vb.custom_minimum_size = Vector2(360, 0); cc.add_child(vb)
	return vb

func _btn(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new(); b.text = text; b.custom_minimum_size = Vector2(360, 56); b.pressed.connect(cb); parent.add_child(b); return b

func _build_menus() -> void:
	menu = _overlay()
	var vb := _center_col(menu)
	var t := _label("PIAW", 110, Color(0.98, 0.92, 0.78)); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(t)
	var st := _label("SLIDE FOR THE ASAFO", 18, ACCENT); st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(st)
	var st2 := _label("The Anglo-Asante Wars", 16, Color(1, 1, 1, 0.6)); st2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(st2)
	vb.add_child(Control.new())
	var play := _btn(vb, "PLAY", func(): play_pressed.emit())
	diff_btn = _btn(vb, "", _cycle_diff); _update_diff()
	var help := _label("Move WASD / L-stick   Look mouse / R-stick\nFire LMB / R2   Afena F, RMB / R1   Aim Q / L2\nCrouch C / Circle   Reload R / Square", 14, Color(1, 1, 1, 0.55))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(help)
	play.call_deferred("grab_focus")

	pause_menu = _overlay(); pause_menu.visible = false
	var pv := _center_col(pause_menu)
	var pt := _label("PAUSED", 48); pt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; pv.add_child(pt)
	_btn(pv, "RESUME", func(): set_paused(false))
	_btn(pv, "RESTART MISSION", func(): restart_pressed.emit())

	end_menu = _overlay(); end_menu.visible = false
	var ev := _center_col(end_menu)
	end_title = _label("", 48, ACCENT); end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; ev.add_child(end_title)
	_btn(ev, "PLAY AGAIN", func(): restart_pressed.emit())

func _cycle_diff() -> void:
	Game.difficulty = (Game.difficulty + 1) % 3; _update_diff()
func _update_diff() -> void:
	diff_btn.text = "DIFFICULTY:  " + ["EASY", "NORMAL", "HARD"][Game.difficulty]

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
	if inst: inst.hitmark.text = "✕"; inst.hit_t = 0.25
static func damage() -> void:
	if inst: inst.vig_t = 0.6

func _process(dt: float) -> void:
	toast_t -= dt; toast.modulate.a = clampf(toast_t * 2.0, 0.0, 1.0)
	hit_t -= dt; if hit_t <= 0.0: hitmark.text = ""
	vig_t = max(vig_t - dt, 0.0); vignette.color.a = vig_t * 0.5
	var p = get_tree().get_first_node_in_group("player")
	if p:
		hp_bar.value = p.hp
		weapon_l.text = "DANE GUN   " + ("●" if p.loaded else "○")
		reload_bar.value = 100.0 if p.loaded else p.reload_progress() * 100.0
		var s: float = p.stealth()
		stealth_pill.text = "◉ HIDDEN" if s < 0.5 else ("◐ LOW PROFILE" if s < 0.9 else "")
	if Input.is_action_just_pressed("pause"): set_paused(not pause_menu.visible)
	elif hud_box.visible and not touch_mode and not get_tree().paused and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and OS.has_feature("web"):
		set_paused(true)

func _notification(what: int) -> void:
	# browser released the pointer (Esc) -> pause
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and hud_box and hud_box.visible: set_paused(true)

# ---------------------------------------------------------------- touch controls
var joy_idx := -1
var joy_start := Vector2.ZERO
var joy_vec := Vector2.ZERO
var look_idx := -1
var buttons := []  # [center, radius, action, toggle]

func _build_touch() -> void:
	touch_mode = DisplayServer.is_touchscreen_available() and (OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios"))
	touch = Control.new(); touch.set_anchors_preset(Control.PRESET_FULL_RECT); touch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	touch.draw.connect(_draw_touch); root.add_child(touch); touch.visible = false

func _layout_buttons() -> void:
	var s := root.get_viewport_rect().size
	buttons = [
		[Vector2(s.x - 110, s.y - 120), 62.0, "fire", "FIRE"],
		[Vector2(s.x - 235, s.y - 90), 44.0, "slash", "AFENA"],
		[Vector2(s.x - 110, s.y - 260), 44.0, "aim", "AIM"],
		[Vector2(s.x - 230, s.y - 215), 38.0, "reload", "RLD"],
		[Vector2(s.x - 335, s.y - 70), 38.0, "crouch", "CRCH"],
		[Vector2(s.x - 335, s.y - 170), 34.0, "jump", "JUMP"],
		[Vector2(s.x - 56, 56), 30.0, "pause", "II"],
	]

func _hit_button(p: Vector2) -> Array:
	for b in buttons:
		if p.distance_to(b[0]) < b[1] + 8: return b
	return []

func _input(e: InputEvent) -> void:
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
					if Input.is_action_pressed(b[2]): Input.action_release(b[2])
					else: Input.action_press(b[2])
				elif b[2] == "pause": set_paused(true)
				else: Input.action_press(b[2]); _release_later(b[2])
			elif e.position.x < s.x * 0.42 and joy_idx < 0:
				joy_idx = e.index; joy_start = e.position
			elif look_idx < 0:
				look_idx = e.index
		else:
			if e.index == joy_idx: joy_idx = -1; joy_vec = Vector2.ZERO; _apply_joy()
			if e.index == look_idx: look_idx = -1
		touch.queue_redraw()
	elif e is InputEventScreenDrag:
		if e.index == joy_idx:
			joy_vec = ((e.position - joy_start) / 70.0).limit_length(1.0); _apply_joy(); touch.queue_redraw()
		elif e.index == look_idx:
			look_delta += e.relative

func _release_later(a: String) -> void:
	await get_tree().create_timer(0.12).timeout
	Input.action_release(a)

func _apply_joy() -> void:
	for pair in [["move_r", joy_vec.x], ["move_l", -joy_vec.x], ["move_b", joy_vec.y], ["move_f", -joy_vec.y]]:
		if pair[1] > 0.05: Input.action_press(pair[0], pair[1])
		else: Input.action_release(pair[0])
	if joy_vec.length() > 0.95: Input.action_press("sprint")
	else: Input.action_release("sprint")

func _draw_touch() -> void:
	if buttons.is_empty(): _layout_buttons()
	var s := root.get_viewport_rect().size
	var base := joy_start if joy_idx >= 0 else Vector2(170, s.y - 170)
	touch.draw_circle(base, 80, Color(1, 1, 1, 0.08))
	touch.draw_arc(base, 80, 0, TAU, 48, Color(1, 1, 1, 0.3), 2.0, true)
	touch.draw_circle(base + joy_vec * 70.0, 34, Color(1, 1, 1, 0.35))
	var f := ThemeDB.fallback_font
	for b in buttons:
		var on: bool = Input.is_action_pressed(b[2])
		touch.draw_circle(b[0], b[1], Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.75) if on else Color(0, 0, 0, 0.35))
		touch.draw_arc(b[0], b[1], 0, TAU, 40, Color(1, 1, 1, 0.45), 2.0, true)
		var fs := 15 if b[1] < 50 else 19
		var w := f.get_string_size(b[3], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		touch.draw_string(f, b[0] + Vector2(-w / 2, fs * 0.35), b[3], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.9))
