extends CanvasLayer

signal tablet_toggled(is_open: bool)
signal code_accepted

const SIZE := 5
const PATTERNS := [
	{"name": "PIT BELOW, DON'T FALL", "rows": ["10001", "10001", "10001", "10001", "11111"]},
]

# Look
const COL_BG := Color("071a26")
const COL_BAR := Color("24404f")
const COL_BOX := Color("0a2230")
const COL_EDGE := Color("1d4a5e")
const COL_CYAN := Color("00b8e6")
const COL_TEXT := Color("8fe9ff")
const COL_DIM := Color("6fb7cc")
const COL_VALUE := Color("e8fbff")
const COL_WARN := Color("ff6a4d")
const COL_OFF := Color("35505c")

const OXY_MAX := 300.0  # keep equal to MAX_OXYGEN in hud.gd
const BASE_TEMP := 217.7

const SURVEY := [
	["Orbital period", "9.207540 days"],
	["Semi-major axis", "0.03849 au"],
	["Radius", "1.045 Earth radii"],
	["Mass", "1.039 Earth masses"],
	["Eccentricity", "0.01007"],
	["Equilibrium temp.", "217.7 K"],
	["Host star", "M8.0 V, 2566 K"],
	["Distance", "12.43 pc"],
	["Planets in system", "7"],
]

# Frost tuning
const FROST_FAR := 350.0     # distance where frost starts
const FROST_NEAR := 40.0     # distance where frost is at its distance maximum
const FROST_DIST_MAX := 0.9  # distance alone never fully seals the screen
const FROST_GROW := 3.0      # how fast frost spreads
const FROST_MELT := 0.4      # how slowly it melts back
const FREEZE_TIME := 2.5     # seconds to seal the screen when caught

const FROST_SHADER := """
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
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	float edge = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
	float n = fbm(uv * aspect * 7.0);
	float front = edge + (n - 0.5) * 0.36;
	float reach = amount * 0.78;
	float cover = 1.0 - smoothstep(reach - 0.05, reach, front);
	float grain = fbm(uv * aspect * 70.0);
	float thick = clamp((reach - front) * 4.0, 0.0, 1.0);
	vec3 col = mix(vec3(0.50, 0.72, 0.84), vec3(0.93, 0.98, 1.0), grain);
	float alpha = cover * clamp(0.30 + thick * 0.9 + grain * 0.2, 0.0, 0.97);
	alpha = max(alpha, cover * pow(amount, 3.0));
	COLOR = vec4(col, alpha);
}
"""

@onready var panel: Panel = $Panel
@onready var vbox: VBoxContainer = $Panel/VBoxContainer
@onready var telemetry: Label = $Panel/VBoxContainer/Telemetry
@onready var code_input: LineEdit = $Panel/VBoxContainer/CodeInput
@onready var status: Label = $Panel/VBoxContainer/Status

var message_index := 0
var can_decrypt := false
var decrypt_mode := false
var frozen := false
var solved := false

var sw := 1152.0
var sh := 648.0

var list_label: Label
var footer_label: Label
var table_box: Panel
var o2_label: Label
var o2_fill: ColorRect
var o2_bar_w := 0.0
var hp_label: Label
var hp_fill: ColorRect
var hp_bar_w := 0.0
var temp_label: Label
var signal_bars: Array[ColorRect] = []

var grid: Array = []
var target: Array = []
var buttons: Array = []
var row_labels: Array = []
var col_labels: Array = []

var frost_rect: ColorRect
var frost_mat: ShaderMaterial
var frost_amount := 0.0

func _ready() -> void:
	layer = 10  # above the HUD (layer 5) so the HUD bars are hidden while the tablet is open
	var vp := get_viewport().get_visible_rect().size
	sw = vp.x
	sh = vp.y

	panel.visible = false
	status.text = ""
	code_input.visible = false

	var bg := StyleBoxFlat.new()
	bg.bg_color = COL_BG
	panel.add_theme_stylebox_override("panel", bg)

	telemetry.add_theme_color_override("font_color", COL_TEXT)
	telemetry.add_theme_font_size_override("font_size", 22)
	telemetry.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_color_override("font_color", COL_DIM)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	vbox.custom_minimum_size = Vector2(460, 0)
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH

	_build_header()
	_build_left_column()
	_build_table()
	_build_right_column()
	_build_footer()
	_build_grid()
	_build_frost()  # last, so frost draws over everything

func set_sample_list(text: String) -> void:
	if list_label != null:
		list_label.text = text

# ---------- building blocks ----------

func _make_label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _rect(parent: Control, pos: Vector2, sz: Vector2, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.position = pos
	r.size = sz
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r

func _add_corners(p: Control, sz: Vector2) -> void:
	var n := 16.0
	var t := 3.0
	_rect(p, Vector2(0, 0), Vector2(n, t), COL_CYAN)
	_rect(p, Vector2(0, 0), Vector2(t, n), COL_CYAN)
	_rect(p, Vector2(sz.x - n, 0), Vector2(n, t), COL_CYAN)
	_rect(p, Vector2(sz.x - t, 0), Vector2(t, n), COL_CYAN)
	_rect(p, Vector2(0, sz.y - t), Vector2(n, t), COL_CYAN)
	_rect(p, Vector2(0, sz.y - n), Vector2(t, n), COL_CYAN)
	_rect(p, Vector2(sz.x - n, sz.y - t), Vector2(n, t), COL_CYAN)
	_rect(p, Vector2(sz.x - t, sz.y - n), Vector2(t, n), COL_CYAN)

func _make_frame(pos: Vector2, sz: Vector2, title: String) -> Panel:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_BOX
	sb.border_color = COL_EDGE
	sb.set_border_width_all(1)
	p.add_theme_stylebox_override("panel", sb)
	p.position = pos
	p.size = sz
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(p)

	_rect(p, Vector2(0, 0), Vector2(110, 5), COL_CYAN)
	_add_corners(p, sz)

	var tl := _make_label(title, 14, COL_CYAN)
	tl.position = Vector2(18, 14)
	p.add_child(tl)
	return p

func _make_bar(parent: Control, pos: Vector2, width: float) -> ColorRect:
	_rect(parent, pos, Vector2(width, 10), Color("14323f"))
	return _rect(parent, pos, Vector2(width, 10), COL_CYAN)

# ---------- layout ----------

func _build_header() -> void:
	var header := Control.new()
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.offset_bottom = 56
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(header)

	_rect(header, Vector2(0, 0), Vector2(sw, 56), COL_BAR)
	_rect(header, Vector2(0, 0), Vector2(sw, 5), COL_CYAN)

	var title := _make_label("TRAPPIST-1 f  //  SURVEY UNIT", 22, COL_TEXT)
	title.position = Vector2(32, 16)
	header.add_child(title)

	var sig := _make_label("SIGNAL", 14, COL_DIM)
	sig.position = Vector2(sw - 200, 22)
	header.add_child(sig)

	for i in 4:
		var h := 8.0 + i * 7.0
		var bar := _rect(header, Vector2(sw - 120 + i * 18, 46.0 - h), Vector2(12, h), COL_OFF)
		signal_bars.append(bar)

func _build_left_column() -> void:
	var box := _make_frame(Vector2(32, 84), Vector2(280, sh - 84 - 60), "SAMPLE + MESSAGE LOG")
	list_label = _make_label("", 16, COL_TEXT)
	list_label.position = Vector2(18, 48)
	list_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list_label.size = Vector2(244, box.size.y - 64)
	box.add_child(list_label)

func _build_table() -> void:
	var rx := sw - 32.0 - 260.0
	var cw := rx - 20.0 - 332.0
	table_box = _make_frame(Vector2(332, 84), Vector2(cw, sh - 84 - 60), "PLANETARY DATA  //  NASA EXOPLANET ARCHIVE")

	var gc := GridContainer.new()
	gc.columns = 2
	gc.add_theme_constant_override("h_separation", 50)
	gc.add_theme_constant_override("v_separation", 14)
	gc.position = Vector2(24, 54)
	table_box.add_child(gc)
	for row in SURVEY:
		gc.add_child(_make_label(row[0], 18, COL_DIM))
		gc.add_child(_make_label(row[1], 18, COL_VALUE))

func _build_right_column() -> void:
	var rw := 260.0
	var rx := sw - 32.0 - rw
	var bottom := sh - 60.0

	var o2_box := _make_frame(Vector2(rx, 84), Vector2(rw, 170), "SUIT OXYGEN")
	o2_label = _make_label("05:00", 56, COL_TEXT)
	o2_label.position = Vector2(18, 52)
	o2_box.add_child(o2_label)
	o2_bar_w = rw - 36.0
	o2_fill = _make_bar(o2_box, Vector2(18, 140), o2_bar_w)

	var hp_box := _make_frame(Vector2(rx, 270), Vector2(rw, 130), "VITALS")
	hp_label = _make_label("100 % HEALTH", 24, COL_VALUE)
	hp_label.position = Vector2(18, 48)
	hp_box.add_child(hp_label)
	hp_bar_w = rw - 36.0
	hp_fill = _make_bar(hp_box, Vector2(18, 92), hp_bar_w)

	var tmp_box := _make_frame(Vector2(rx, 416), Vector2(rw, bottom - 416.0), "EXTERNAL TEMP")
	temp_label = _make_label("217.7 K", 40, COL_TEXT)
	temp_label.position = Vector2(18, 50)
	tmp_box.add_child(temp_label)
	var note := _make_label("equilibrium: 217.7 K", 14, COL_DIM)
	note.position = Vector2(18, 108)
	tmp_box.add_child(note)

func _build_footer() -> void:
	var bar := Control.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -44
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(bar)
	_rect(bar, Vector2(0, 0), Vector2(sw, 44), COL_BAR)
	_rect(bar, Vector2(0, 39), Vector2(sw, 5), COL_CYAN)

	footer_label = _make_label("", 18, COL_TEXT)
	footer_label.position = Vector2(32, 8)
	bar.add_child(footer_label)

func _update_readouts() -> void:
	var hud := get_tree().current_scene.get_node_or_null("HUD")
	var oxy := 0.0
	var hp := 0.0
	if hud != null:
		oxy = float(hud.get("oxygen"))
		hp = float(hud.get("health"))

	var secs := int(oxy)
	o2_label.text = "%02d:%02d" % [int(secs / 60.0), secs % 60]
	o2_fill.size.x = o2_bar_w * clampf(oxy / OXY_MAX, 0.0, 1.0)
	o2_fill.color = COL_WARN if oxy < 60.0 else COL_CYAN

	hp_label.text = str(int(hp)) + " % HEALTH"
	hp_fill.size.x = hp_bar_w * clampf(hp / 100.0, 0.0, 1.0)
	hp_fill.color = COL_WARN if hp < 40.0 else COL_CYAN

	temp_label.text = "%.1f K" % (BASE_TEMP - frost_amount * 25.0)

	# signal strength: 1 bar normally, 4 bars at a signal spot with a message
	var lit := 4 if (decrypt_mode or can_decrypt) else 1
	for i in signal_bars.size():
		signal_bars[i].color = COL_CYAN if i < lit else COL_OFF

	var link := "LINK: STRONG - MESSAGE INCOMING" if decrypt_mode else "LINK: WEAK - NO INCOMING MESSAGE"
	footer_label.text = link + "          [TAB] close"

# ---------- grid ----------

func _build_grid() -> void:
	var gc := GridContainer.new()
	gc.columns = SIZE + 1
	gc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	gc.add_theme_constant_override("h_separation", 6)
	gc.add_theme_constant_override("v_separation", 6)
	vbox.add_child(gc)
	vbox.move_child(gc, 1)

	for r in SIZE:
		var row_buttons: Array = []
		for c in SIZE:
			var b := Button.new()
			b.custom_minimum_size = Vector2(60, 60)
			b.focus_mode = Control.FOCUS_NONE
			b.add_theme_font_size_override("font_size", 26)
			b.pressed.connect(_on_cell_pressed.bind(r, c))
			gc.add_child(b)
			row_buttons.append(b)
		buttons.append(row_buttons)
		var rl := Label.new()
		rl.add_theme_font_size_override("font_size", 26)
		rl.add_theme_color_override("font_color", COL_TEXT)
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rl.custom_minimum_size = Vector2(50, 60)
		rl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		gc.add_child(rl)
		row_labels.append(rl)

	for c in SIZE:
		var cl := Label.new()
		cl.add_theme_font_size_override("font_size", 26)
		cl.add_theme_color_override("font_color", COL_TEXT)
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cl.custom_minimum_size = Vector2(60, 40)
		gc.add_child(cl)
		col_labels.append(cl)
	gc.add_child(Control.new())

# ---------- frost ----------

func _build_frost() -> void:
	var sh_res := Shader.new()
	sh_res.code = FROST_SHADER
	frost_mat = ShaderMaterial.new()
	frost_mat.shader = sh_res
	frost_mat.set_shader_parameter("aspect", Vector2(sw / sh, 1.0))
	frost_mat.set_shader_parameter("amount", 0.0)

	frost_rect = ColorRect.new()
	frost_rect.color = Color.WHITE
	frost_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	frost_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frost_rect.material = frost_mat
	frost_rect.visible = false
	panel.add_child(frost_rect)

func _set_frost(a: float) -> void:
	frost_amount = clampf(a, 0.0, 1.0)
	frost_mat.set_shader_parameter("amount", frost_amount)
	frost_rect.visible = frost_amount > 0.01

func _process(delta: float) -> void:
	if frozen or not panel.visible:
		return
	var player := get_tree().get_first_node_in_group("player")
	var anomaly := get_tree().current_scene.get_node_or_null("Anomaly")
	if player != null and anomaly != null:
		var dist: float = anomaly.global_position.distance_to(player.global_position)
		var goal := clampf((FROST_FAR - dist) / (FROST_FAR - FROST_NEAR), 0.0, 1.0) * FROST_DIST_MAX
		var rate := FROST_GROW if goal > frost_amount else FROST_MELT
		_set_frost(lerpf(frost_amount, goal, clampf(delta * rate, 0.0, 1.0)))
	_update_readouts()

func _reset_frost() -> void:
	_set_frost(0.0)

# ---------- puzzle ----------

func _new_puzzle() -> void:
	solved = false
	var rows: Array = PATTERNS[message_index]["rows"]
	target = []
	grid = []
	for r in SIZE:
		var t_row: Array = []
		var g_row: Array = []
		for c in SIZE:
			var v := int(rows[r][c])
			t_row.append(v)
			g_row.append(v)
		target.append(t_row)
		grid.append(g_row)

	# flip exactly one random cell
	var fr := randi() % SIZE
	var fc := randi() % SIZE
	grid[fr][fc] = 1 - grid[fr][fc]

	for r in SIZE:
		var total := 0
		for c in SIZE:
			total += target[r][c]
		row_labels[r].text = str(total)
	for c in SIZE:
		var total := 0
		for r in SIZE:
			total += target[r][c]
		col_labels[c].text = str(total)

	telemetry.text = "SIGNAL " + str(message_index + 1) + ": MESSAGE CORRUPTED"
	status.text = "One bit is flipped. Every row and column must match the counts shown."
	_refresh_cells()

func _refresh_cells() -> void:
	for r in SIZE:
		for c in SIZE:
			var b: Button = buttons[r][c]
			var v: int = grid[r][c]
			b.text = str(v)
			if solved:
				b.modulate = Color(0.4, 1.0, 1.0) if v == 1 else Color(0.2, 0.3, 0.35)
			else:
				b.modulate = Color(1.0, 1.0, 1.0) if v == 1 else Color(0.55, 0.55, 0.6)

func _on_cell_pressed(r: int, c: int) -> void:
	if frozen or solved or not panel.visible or not decrypt_mode:
		return
	grid[r][c] = 1 - grid[r][c]
	_refresh_cells()
	if grid == target:
		_solve()

func _solve() -> void:
	solved = true
	_refresh_cells()
	telemetry.text = "MESSAGE: " + PATTERNS[message_index]["name"]
	status.text = "Signal repaired.   [TAB] close"
	code_accepted.emit()

func _input(event: InputEvent) -> void:
	if frozen:
		return
	if event.is_action_pressed("ui_focus_next"):
		get_viewport().set_input_as_handled()
		if panel.visible:
			_close()
		else:
			_open()

func _open() -> void:
	_reset_frost()
	solved = false
	decrypt_mode = can_decrypt and message_index >= 0 and message_index < PATTERNS.size()
	vbox.visible = decrypt_mode
	table_box.visible = not decrypt_mode
	if decrypt_mode:
		_new_puzzle()
	_update_readouts()
	panel.visible = true
	tablet_toggled.emit(true)

func _close() -> void:
	panel.visible = false
	solved = false
	_reset_frost()
	tablet_toggled.emit(false)

func freeze() -> void:
	if frozen:
		return
	frozen = true

	# frost seals the whole screen, slowing as it closes
	var tween := create_tween()
	tween.tween_method(_set_frost, frost_amount, 1.0, FREEZE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.8)
	tween.tween_callback(get_tree().current_scene.get_node("GameOverUI").show_game_over)
