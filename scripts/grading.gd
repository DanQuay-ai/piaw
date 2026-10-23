extends CanvasLayer
## Full-screen colour grade: contrast, saturation, warm highlights / cool shadows, vignette.
const SH := """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float contrast = 1.2;
uniform float saturation = 1.15;
uniform float vignette = 0.4;
void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	c = clamp((c - 0.5) * contrast + 0.5, 0.0, 1.0);
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	c *= mix(vec3(0.9, 0.98, 1.04), vec3(1.06, 1.0, 0.9), smoothstep(0.15, 0.85, l));
	float v = distance(SCREEN_UV, vec2(0.5));
	c *= 1.0 - vignette * smoothstep(0.35, 0.85, v);
	COLOR = vec4(c, 1.0);
}
"""
var rect: ColorRect
func _ready() -> void:
	rect = ColorRect.new(); rect.set_anchors_preset(Control.PRESET_FULL_RECT); rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := Shader.new(); s.code = SH
	var m := ShaderMaterial.new(); m.shader = s; rect.material = m
	add_child(rect)
func _process(_dt: float) -> void:
	rect.visible = Settings.grading
