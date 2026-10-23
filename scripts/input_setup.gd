class_name InputSetup
## Keyboard/mouse + PS5 (DualSense) / Xbox bindings, created in code. device = -1 matches every pad.
static func setup() -> void:
	var map := {
		"move_f": [_k(KEY_W), _k(KEY_UP), _ax(JOY_AXIS_LEFT_Y, -1)],
		"move_b": [_k(KEY_S), _k(KEY_DOWN), _ax(JOY_AXIS_LEFT_Y, 1)],
		"move_l": [_k(KEY_A), _k(KEY_LEFT), _ax(JOY_AXIS_LEFT_X, -1)],
		"move_r": [_k(KEY_D), _k(KEY_RIGHT), _ax(JOY_AXIS_LEFT_X, 1)],
		"look_l": [_ax(JOY_AXIS_RIGHT_X, -1)], "look_r": [_ax(JOY_AXIS_RIGHT_X, 1)],
		"look_u": [_ax(JOY_AXIS_RIGHT_Y, -1)], "look_d": [_ax(JOY_AXIS_RIGHT_Y, 1)],
		"jump": [_k(KEY_SPACE), _b(JOY_BUTTON_A)],                                   # Cross
		"crouch": [_k(KEY_C), _k(KEY_CTRL), _b(JOY_BUTTON_B)],                       # Circle
		"reload": [_k(KEY_R), _b(JOY_BUTTON_X)],                                     # Square
		"slash": [_k(KEY_F), _m(MOUSE_BUTTON_RIGHT), _b(JOY_BUTTON_RIGHT_SHOULDER)], # R1
		"fire": [_m(MOUSE_BUTTON_LEFT), _ax(JOY_AXIS_TRIGGER_RIGHT, 1)],             # R2
		"aim": [_k(KEY_Q), _m(MOUSE_BUTTON_MIDDLE), _ax(JOY_AXIS_TRIGGER_LEFT, 1)],  # L2
		"sprint": [_k(KEY_SHIFT), _b(JOY_BUTTON_LEFT_STICK)],                        # L3
		"whistle": [_k(KEY_G), _b(JOY_BUTTON_DPAD_UP), _b(JOY_BUTTON_Y)],           # D-pad up / Triangle
		"swap_gun": [_k(KEY_X), _m(MOUSE_BUTTON_WHEEL_UP), _b(JOY_BUTTON_DPAD_RIGHT), _b(JOY_BUTTON_LEFT_SHOULDER)], # L1
		"swap_blade": [_k(KEY_V), _b(JOY_BUTTON_DPAD_LEFT)],
		"map": [_k(KEY_M), _k(KEY_TAB), _b(JOY_BUTTON_BACK), _b(JOY_BUTTON_TOUCHPAD)],
		"pause": [_k(KEY_ESCAPE), _k(KEY_P), _b(JOY_BUTTON_START)],
	}
	for a in map:
		if not InputMap.has_action(a): InputMap.add_action(a, 0.25)
		for e in map[a]: InputMap.action_add_event(a, e)
	# make sure menus answer to the pad too
	for pair in [["ui_accept", _b(JOY_BUTTON_A)], ["ui_cancel", _b(JOY_BUTTON_B)], ["ui_up", _b(JOY_BUTTON_DPAD_UP)], ["ui_down", _b(JOY_BUTTON_DPAD_DOWN)],
			["ui_left", _b(JOY_BUTTON_DPAD_LEFT)], ["ui_right", _b(JOY_BUTTON_DPAD_RIGHT)], ["ui_up", _ax(JOY_AXIS_LEFT_Y, -1)], ["ui_down", _ax(JOY_AXIS_LEFT_Y, 1)]]:
		InputMap.action_add_event(pair[0], pair[1])

static func _k(c):
	var e := InputEventKey.new(); e.physical_keycode = c; return e
static func _m(c):
	var e := InputEventMouseButton.new(); e.button_index = c; return e
static func _b(c):
	var e := InputEventJoypadButton.new(); e.button_index = c; e.device = -1; return e
static func _ax(a, v):
	var e := InputEventJoypadMotion.new(); e.axis = a; e.axis_value = v; e.device = -1; return e
