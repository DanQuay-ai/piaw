class_name Settings
## Persistent options (user://settings.cfg): audio, controls, graphics, pad remaps.
const PATH := "user://settings.cfg"
static var master := 0.9
static var music := 0.6
static var sfx := 0.9
static var voice := 1.0
static var mouse_sens := 1.0
static var pad_sens := 1.0
static var invert_y := false
static var quality := -1        # -1 auto, 0 low, 1 high
static var grading := true
static var shake := 1.0
static var touch_scale := 1.0
static var pad_binds := {}      # action -> {"type": "button"/"axis", "index": int, "dir": float}

static func load_cfg() -> void:
	var c := ConfigFile.new()
	if c.load(PATH) != OK: return
	for k in ["master", "music", "sfx", "voice", "mouse_sens", "pad_sens", "invert_y", "quality", "grading", "shake", "touch_scale", "pad_binds"]:
		if c.has_section_key("s", k): set_value(k, c.get_value("s", k))

static func set_value(k: String, v) -> void:
	match k:
		"master": master = v
		"music": music = v
		"sfx": sfx = v
		"voice": voice = v
		"mouse_sens": mouse_sens = v
		"pad_sens": pad_sens = v
		"invert_y": invert_y = v
		"quality": quality = v
		"grading": grading = v
		"shake": shake = v
		"touch_scale": touch_scale = v
		"pad_binds": pad_binds = v

static func save_cfg() -> void:
	var c := ConfigFile.new()
	for k in ["master", "music", "sfx", "voice", "mouse_sens", "pad_sens", "invert_y", "quality", "grading", "shake", "touch_scale", "pad_binds"]:
		c.set_value("s", k, value(k))
	c.save(PATH)
	apply()

static func value(k: String):
	match k:
		"master": return master
		"music": return music
		"sfx": return sfx
		"voice": return voice
		"mouse_sens": return mouse_sens
		"pad_sens": return pad_sens
		"invert_y": return invert_y
		"quality": return quality
		"grading": return grading
		"shake": return shake
		"touch_scale": return touch_scale
		"pad_binds": return pad_binds
	return null

static func setup_buses() -> void:
	for b in ["Music", "SFX", "Voice"]:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus(); var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b); AudioServer.set_bus_send(i, "Master")

static func apply() -> void:
	setup_buses()
	for pair in [["Master", master], ["Music", music], ["SFX", sfx], ["Voice", voice]]:
		var i := AudioServer.get_bus_index(pair[0])
		AudioServer.set_bus_volume_db(i, linear_to_db(max(pair[1], 0.0001)))
	for a in pad_binds: bind_pad(a, pad_binds[a], false)

## Replace the pad events of an action with a captured button/axis.
static func bind_pad(action: String, b: Dictionary, store := true) -> void:
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton or e is InputEventJoypadMotion: InputMap.action_erase_event(action, e)
	var ev: InputEvent
	if b.type == "button":
		ev = InputEventJoypadButton.new(); ev.button_index = b.index
	else:
		ev = InputEventJoypadMotion.new(); ev.axis = b.index; ev.axis_value = b.dir
	ev.device = -1
	InputMap.action_add_event(action, ev)
	if store: pad_binds[action] = b
