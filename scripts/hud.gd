extends CanvasLayer

@export var zayd_portrait: Texture2D   # drag Zayd's face here
@export var nafis_portrait: Texture2D  # drag Nafis's face here

const MAX_HEALTH := 100.0
const MAX_OXYGEN := 300.0  # seconds of air; keep OXY_MAX in tablet.gd equal
const BAR_W := 240.0
const BAR_H := 10.0

const COL_BOX := Color("0a2230")
const COL_EDGE := Color("1d4a5e")
const COL_CYAN := Color("00b8e6")
const COL_TEXT := Color("8fe9ff")
const COL_DIM := Color("6fb7cc")
const COL_VALUE := Color("e8fbff")
const COL_WARN := Color("ff6a4d")
const COL_TRACK := Color("14323f")

const OBJ_W := 250.0
const OBJ_H := 112.0
const CARD_W := 250.0
const CARD_H := 112.0
const NAFIS_FACE := 52.0
const ZAYD_W := 92.0
const ZAYD_H := 100.0

var health := MAX_HEALTH
var oxygen := MAX_OXYGEN
var dead := false

var health_fill: ColorRect
var oxygen_fill: ColorRect
var health_value: Label
var oxygen_value: Label

var obj_ticks: Array[ColorRect] = []
var obj_labels: Array[Label] = []

var card_title: Label
var card_status: Label
var card_message: Label

func _ready() -> void:
	layer = 5
	var vp := get_viewport().get_visible_rect().size
	_build_zayd_face(Vector2(24.0, vp.y - 18.0 - ZAYD_H))
	_build_vitals(Vector2(24.0 + ZAYD_W + 8.0, vp.y - 118.0))
	_build_objectives(Vector2(vp.x - OBJ_W - 24.0, 24.0))
	_build_card(Vector2(vp.x - CARD_W - 24.0, 24.0 + OBJ_H + 12.0))

	var hint := _make_label("R: restart", 16, COL_DIM)
	hint.position = Vector2(vp.x - 120.0, vp.y - 36.0)
	hint.modulate.a = 0.7
	add_child(hint)

	_update_bars()
	_update_objectives()
	_update_card()

# ---------- helpers ----------

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
	var n := 12.0
	var t := 2.0
	_rect(p, Vector2(0, 0), Vector2(n, t), COL_CYAN)
	_rect(p, Vector2(0, 0), Vector2(t, n), COL_CYAN)
	_rect(p, Vector2(sz.x - n, 0), Vector2(n, t), COL_CYAN)
	_rect(p, Vector2(sz.x - t, 0), Vector2(t, n), COL_CYAN)
	_rect(p, Vector2(0, sz.y - t), Vector2(n, t), COL_CYAN)
	_rect(p, Vector2(0, sz.y - n), Vector2(t, n), COL_CYAN)
	_rect(p, Vector2(sz.x - n, sz.y - t), Vector2(n, t), COL_CYAN)
	_rect(p, Vector2(sz.x - t, sz.y - n), Vector2(t, n), COL_CYAN)

func _make_panel(pos: Vector2, sz: Vector2) -> Panel:
	var box := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_BOX
	sb.bg_color.a = 0.88
	sb.border_color = COL_EDGE
	sb.set_border_width_all(1)
	box.add_theme_stylebox_override("panel", sb)
	box.position = pos
	box.size = sz
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_add_corners(box, sz)
	return box

# Portrait: placeholder bust, replaced by the texture when one is assigned
func _add_portrait(parent: Control, pos: Vector2, sz: Vector2, tex: Texture2D) -> void:
	_rect(parent, pos, sz, COL_EDGE)
	var inner_pos := pos + Vector2(2, 2)
	var inner_sz := sz - Vector2(4, 4)
	_rect(parent, inner_pos, inner_sz, COL_TRACK)
	_rect(parent, inner_pos + Vector2(inner_sz.x * 0.3, inner_sz.y * 0.12), Vector2(inner_sz.x * 0.4, inner_sz.y * 0.4), COL_DIM)
	_rect(parent, inner_pos + Vector2(inner_sz.x * 0.15, inner_sz.y * 0.62), Vector2(inner_sz.x * 0.7, inner_sz.y * 0.34), COL_DIM)
	if tex != null:
		var face := TextureRect.new()
		face.texture = tex
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		face.clip_contents = true
		face.position = inner_pos
		face.size = inner_sz
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(face)

# ---------- Zayd portrait (bottom-left, name on top) ----------

func _build_zayd_face(pos: Vector2) -> void:
	var box := _make_panel(pos, Vector2(ZAYD_W, ZAYD_H))

	var name_label := _make_label("ZAYD", 14, COL_VALUE)
	name_label.position = Vector2(10, 3)
	box.add_child(name_label)

	_add_portrait(box, Vector2(8, 24), Vector2(ZAYD_W - 16.0, ZAYD_H - 32.0), zayd_portrait)

# ---------- vitals ----------

func _build_vitals(pos: Vector2) -> void:
	var box := _make_panel(pos, Vector2(BAR_W + 36.0, 100.0))

	var title := _make_label("VITALS", 12, COL_CYAN)
	title.position = Vector2(18, 6)
	box.add_child(title)

	var h_name := _make_label("HEALTH", 13, COL_DIM)
	h_name.position = Vector2(18, 26)
	box.add_child(h_name)
	health_value = _make_label("100 %", 13, COL_TEXT)
	health_value.position = Vector2(18.0 + BAR_W - 80.0, 26)
	health_value.size = Vector2(80, 18)
	health_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(health_value)
	_rect(box, Vector2(18, 46), Vector2(BAR_W, BAR_H), COL_TRACK)
	health_fill = _rect(box, Vector2(18, 46), Vector2(BAR_W, BAR_H), COL_CYAN)

	var o_name := _make_label("O2", 13, COL_DIM)
	o_name.position = Vector2(18, 62)
	box.add_child(o_name)
	oxygen_value = _make_label("05:00", 13, COL_TEXT)
	oxygen_value.position = Vector2(18.0 + BAR_W - 80.0, 62)
	oxygen_value.size = Vector2(80, 18)
	oxygen_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(oxygen_value)
	_rect(box, Vector2(18, 82), Vector2(BAR_W, BAR_H), COL_TRACK)
	oxygen_fill = _rect(box, Vector2(18, 82), Vector2(BAR_W, BAR_H), COL_CYAN)

# ---------- objectives (top-right) ----------

func _build_objectives(pos: Vector2) -> void:
	var box := _make_panel(pos, Vector2(OBJ_W, OBJ_H))

	var title := _make_label("MAIN MISSION", 12, COL_CYAN)
	title.position = Vector2(16, 6)
	box.add_child(title)

	for i in 3:
		var y := 32.0 + i * 25.0
		_rect(box, Vector2(16, y + 3), Vector2(14, 14), COL_EDGE)
		_rect(box, Vector2(18, y + 5), Vector2(10, 10), COL_BOX)
		var tick := _rect(box, Vector2(20, y + 7), Vector2(6, 6), COL_CYAN)
		tick.visible = false
		obj_ticks.append(tick)

		var l := _make_label("", 14, COL_TEXT)
		l.position = Vector2(40, y)
		box.add_child(l)
		obj_labels.append(l)

func _scene_count(prop: String) -> int:
	var v: Variant = get_tree().current_scene.get(prop)
	if v is Array:
		return v.size()
	if v == null:
		return 0
	return int(v)

func _update_objectives() -> void:
	var scene := get_tree().current_scene
	var total_n := _scene_count("total")
	var got := _scene_count("collected")
	var msgs := _scene_count("decrypted")
	var finished: bool = scene.get("mission_done") == true

	var texts := [
		"Collect sample  (" + str(got) + " / " + str(total_n) + ")",
		"Decrypt Nafis's message",
		"Return to the pod",
	]
	var done := [
		total_n > 0 and got >= total_n,
		msgs >= 1,
		finished,
	]
	for i in 3:
		obj_labels[i].text = texts[i]
		obj_ticks[i].visible = done[i]
		obj_labels[i].add_theme_color_override("font_color", COL_DIM if done[i] else COL_TEXT)

# ---------- Nafis comm card (portrait, link status, decrypted message) ----------

func _build_card(pos: Vector2) -> void:
	var box := _make_panel(pos, Vector2(CARD_W, CARD_H))

	card_title = _make_label("COMM  //  MOTHER SHIP", 12, COL_CYAN)
	card_title.position = Vector2(16, 6)
	box.add_child(card_title)

	_add_portrait(box, Vector2(16, 28), Vector2(NAFIS_FACE, NAFIS_FACE), nafis_portrait)

	var name_label := _make_label("NAFIS", 20, COL_VALUE)
	name_label.position = Vector2(80, 30)
	box.add_child(name_label)

	card_status = _make_label("LINK: WEAK", 13, COL_DIM)
	card_status.position = Vector2(80, 58)
	box.add_child(card_status)

	card_message = _make_label("", 15, COL_VALUE)
	card_message.position = Vector2(16, 86)
	card_message.size = Vector2(CARD_W - 32.0, 20)
	card_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_message.visible = false
	box.add_child(card_message)

func _last_message() -> String:
	var d: Variant = get_tree().current_scene.get("decrypted")
	if d is Array and d.size() > 0:
		var line: String = str(d[d.size() - 1])
		var i := line.find(": ")
		if i >= 0:
			return line.substr(i + 2)
		return line
	return ""

func _update_card() -> void:
	var spot: Variant = get_tree().current_scene.get("current_signal")
	var in_area: bool = spot is Node
	var unread: bool = in_area and not spot.has_meta("done")

	if unread:
		var pulse := 0.55 + 0.45 * sin(Time.get_ticks_msec() / 160.0)
		card_title.text = "INCOMING TRANSMISSION"
		card_status.text = "LINK: STRONG - NEW MSG"
		card_status.add_theme_color_override("font_color", COL_CYAN)
		card_status.modulate.a = pulse
	elif in_area:
		card_title.text = "COMM  //  MOTHER SHIP"
		card_status.text = "LINK: STRONG"
		card_status.add_theme_color_override("font_color", COL_CYAN)
		card_status.modulate.a = 1.0
	else:
		card_title.text = "COMM  //  MOTHER SHIP"
		card_status.text = "LINK: WEAK"
		card_status.add_theme_color_override("font_color", COL_DIM)
		card_status.modulate.a = 1.0

	var msg := _last_message()
	card_message.visible = msg != ""
	card_message.text = "> " + msg

# ---------- logic ----------

func _process(delta: float) -> void:
	_update_objectives()
	_update_card()
	if dead:
		return
	var scene := get_tree().current_scene
	if scene.get("mission_done") == true:
		return
	oxygen = maxf(oxygen - delta, 0.0)
	_update_bars()
	if oxygen <= 0.0:
		_die()

func damage(amount: float) -> void:
	if dead:
		return
	health = maxf(health - amount, 0.0)
	_update_bars()
	if health <= 0.0:
		_die()

func _update_bars() -> void:
	health_fill.size.x = BAR_W * health / MAX_HEALTH
	health_fill.color = COL_WARN if health < 40.0 else COL_CYAN
	health_value.text = str(int(health)) + " %"

	oxygen_fill.size.x = BAR_W * oxygen / MAX_OXYGEN
	oxygen_fill.color = COL_WARN if oxygen < 60.0 else COL_CYAN
	var secs := int(oxygen)
	oxygen_value.text = "%02d:%02d" % [int(secs / 60.0), secs % 60]

func _die() -> void:
	dead = true
	get_tree().current_scene.get_node("GameOverUI").show_game_over()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		get_tree().paused = false
		get_tree().reload_current_scene()
