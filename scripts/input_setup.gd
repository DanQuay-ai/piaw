class_name InputSetup
## Keyboard/mouse + PS5 (DualSense) bindings, created in code.
static func setup() -> void:
	var map := {
		"move_f": [_k(KEY_W), _ax(JOY_AXIS_LEFT_Y, -1)],
		"move_b": [_k(KEY_S), _ax(JOY_AXIS_LEFT_Y, 1)],
		"move_l": [_k(KEY_A), _ax(JOY_AXIS_LEFT_X, -1)],
		"move_r": [_k(KEY_D), _ax(JOY_AXIS_LEFT_X, 1)],
		"look_l": [_ax(JOY_AXIS_RIGHT_X, -1)], "look_r": [_ax(JOY_AXIS_RIGHT_X, 1)],
		"look_u": [_ax(JOY_AXIS_RIGHT_Y, -1)], "look_d": [_ax(JOY_AXIS_RIGHT_Y, 1)],
		"jump": [_k(KEY_SPACE), _b(JOY_BUTTON_A)],            # Cross
		"crouch": [_k(KEY_C), _b(JOY_BUTTON_B)],              # Circle
		"reload": [_k(KEY_R), _b(JOY_BUTTON_X)],              # Square
		"slash": [_k(KEY_F), _m(MOUSE_BUTTON_RIGHT), _b(JOY_BUTTON_RIGHT_SHOULDER)], # R1
		"fire": [_m(MOUSE_BUTTON_LEFT), _ax(JOY_AXIS_TRIGGER_RIGHT, 1)],             # R2
		"aim": [_k(KEY_Q), _ax(JOY_AXIS_TRIGGER_LEFT, 1)],                           # L2
		"sprint": [_k(KEY_SHIFT), _b(JOY_BUTTON_LEFT_STICK)],                        # L3
		"interact": [_k(KEY_E), _b(JOY_BUTTON_Y)],                                   # Triangle
		"pause": [_k(KEY_ESCAPE), _b(JOY_BUTTON_START)],
	}
	for a in map:
		if not InputMap.has_action(a): InputMap.add_action(a, 0.2)
		for e in map[a]: InputMap.action_add_event(a, e)
static func _k(c): var e := InputEventKey.new(); e.physical_keycode = c; return e
static func _m(c): var e := InputEventMouseButton.new(); e.button_index = c; return e
static func _b(c): var e := InputEventJoypadButton.new(); e.button_index = c; return e
static func _ax(a, v): var e := InputEventJoypadMotion.new(); e.axis = a; e.axis_value = v; return e
