class_name Hud extends CanvasLayer
static var inst: Hud
var obj: Label
var log_l: Label
var stat: Label
var t := 0.0
func _init() -> void:
	inst = self
	obj = _lab(Vector2(20, 20), 22); log_l = _lab(Vector2(20, 60), 18); stat = _lab(Vector2(20, 680), 20)
	var cross := _lab(Vector2(632, 348), 24); cross.text = "+"
func _lab(p: Vector2, s: int) -> Label:
	var l := Label.new(); l.position = p; l.add_theme_font_size_override("font_size", s)
	l.add_theme_color_override("font_outline_color", Color.BLACK); l.add_theme_constant_override("outline_size", 6)
	add_child(l); return l
static func msg(s: String) -> void:
	if inst: inst.log_l.text = s; inst.t = 2.0
static func objective(s: String) -> void:
	if inst: inst.obj.text = "OBJECTIVE: " + s
func _process(dt: float) -> void:
	t -= dt
	if t <= 0: log_l.text = ""
	var p = get_tree().get_first_node_in_group("player")
	if p: stat.text = "HP %d   Gun: %s   %s" % [p.hp, "loaded" if p.loaded else "empty", "HIDDEN" if p.stealth() < 0.5 else ""]
