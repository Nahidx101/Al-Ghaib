extends CanvasLayer

# How the cold is felt. Tune these.
const COLD_FAR := 500.0       # distance where the cold starts
const COLD_NEAR := 60.0       # distance where it is strongest
const COLD_MAX := 0.85        # strongest the screen frost gets
const GROW := 2.5             # how fast it creeps in
const MELT := 0.5             # how slowly it fades
const BREATH_SLOW := 3.2      # seconds between breaths when it is far
const BREATH_FAST := 0.9      # seconds between breaths when it is very close

const COLD_SHADER := """
shader_type canvas_item;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform vec2 aspect = vec2(1.78, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			   mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	float edge = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
	float n = fbm(uv * aspect * 6.0);
	float front = edge + (n - 0.5) * 0.30;
	float reach = amount * 0.42;
	float cover = 1.0 - smoothstep(reach - 0.08, reach, front);
	float grain = fbm(uv * aspect * 60.0);
	vec3 col = mix(vec3(0.45, 0.70, 0.85), vec3(0.88, 0.96, 1.0), grain);
	COLOR = vec4(col, cover * (0.25 + grain * 0.35) * amount);
}
"""

var cold_rect: ColorRect
var cold_mat: ShaderMaterial
var cold := 0.0

var breath: CPUParticles2D
var breath_timer := 2.0

func _ready() -> void:
	layer = 4  # under the HUD (5) and the tablet (10)
	_build_cold()
	_build_breath()

func _build_cold() -> void:
	var sh := Shader.new()
	sh.code = COLD_SHADER
	cold_mat = ShaderMaterial.new()
	cold_mat.shader = sh
	var vp := get_viewport().get_visible_rect().size
	cold_mat.set_shader_parameter("aspect", Vector2(vp.x / vp.y, 1.0))
	cold_mat.set_shader_parameter("amount", 0.0)

	cold_rect = ColorRect.new()
	cold_rect.color = Color.WHITE
	cold_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	cold_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cold_rect.material = cold_mat
	cold_rect.visible = false
	add_child(cold_rect)

func _build_breath() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	breath = CPUParticles2D.new()
	breath.emitting = false
	breath.one_shot = true
	breath.amount = 7
	breath.lifetime = 1.3
	breath.explosiveness = 0.85
	breath.local_coords = false
	breath.direction = Vector2(1, -0.25)
	breath.spread = 22.0
	breath.initial_velocity_min = 10.0
	breath.initial_velocity_max = 24.0
	breath.gravity = Vector2(0, -6)
	breath.scale_amount_min = 2.0
	breath.scale_amount_max = 4.0
	var g := Gradient.new()
	g.set_color(0, Color(0.85, 0.95, 1.0, 0.55))
	g.set_color(1, Color(0.85, 0.95, 1.0, 0.0))
	breath.color_ramp = g
	breath.position = Vector2(12, -10)
	player.add_child(breath)

func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	var anomaly := get_tree().current_scene.get_node_or_null("Anomaly")
	if player == null or anomaly == null:
		return

	var dist: float = anomaly.global_position.distance_to(player.global_position)
	var goal := clampf((COLD_FAR - dist) / (COLD_FAR - COLD_NEAR), 0.0, 1.0) * COLD_MAX
	var rate := GROW if goal > cold else MELT
	cold = lerpf(cold, goal, clampf(delta * rate, 0.0, 1.0))
	cold_mat.set_shader_parameter("amount", cold)
	cold_rect.visible = cold > 0.01

	if breath != null:
		var facing: float = float(player.get("facing"))
		breath.position = Vector2(12.0 * facing, -10.0)
		breath.direction = Vector2(facing, -0.25)
		breath_timer -= delta
		if breath_timer <= 0.0:
			breath.restart()
			var closeness := clampf(cold / COLD_MAX, 0.0, 1.0)
			breath_timer = lerpf(BREATH_SLOW, BREATH_FAST, closeness)
