class_name PadBridge extends Node
## Safari/WebKit fix: Godot's web build never receives DualSense L2/R2 there.
## We read the browser's Gamepad API directly every frame and drive the "aim" / "fire" actions ourselves.
static var info := ""          # shown on the Controls screen as a live diagnostic
static var l2 := 0.0
static var r2 := 0.0
var _aim_on := false
var _fire_on := false
const JS := "(()=>{const ps=navigator.getGamepads?navigator.getGamepads():[];for(const g of ps){if(g){return JSON.stringify({id:g.id,m:g.mapping,b:Array.from(g.buttons,x=>x.value),a:Array.from(g.axes)});}}return '';})()"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_dt: float) -> void:
	if not OS.has_feature("web"): return
	var raw = JavaScriptBridge.eval(JS, true)
	if typeof(raw) != TYPE_STRING or raw == "":
		info = "Browser sees no controller (press a button on it)"; return
	var d = JSON.parse_string(raw)
	if typeof(d) != TYPE_DICTIONARY: return
	var b: Array = d.b; var a: Array = d.a
	if d.m == "standard" and b.size() > 7:
		l2 = float(b[6]); r2 = float(b[7])
	elif a.size() > 4:  # non-standard layout: triggers rest at -1 on axes 3 / 4
		l2 = (float(a[3]) + 1.0) / 2.0; r2 = (float(a[4]) + 1.0) / 2.0
	info = "%s  [%s]   L2 %.2f   R2 %.2f" % [str(d.id).left(38), d.m, l2, r2]
	var aim_now := l2 > 0.35
	var fire_now := r2 > 0.45
	if aim_now != _aim_on:
		_aim_on = aim_now
		if aim_now: Input.action_press("aim")
		else: Input.action_release("aim")
	if fire_now != _fire_on:
		_fire_on = fire_now
		if fire_now: Input.action_press("fire")
		else: Input.action_release("fire")
