extends Node2D

const COLLECT_TIME := 2.0
const NAMES := {
	"SamplePoint": "BACILLUS SUBTILIS",
	"SamplePoint2": "ESCHERICHIA COLI",
	"SamplePoint3": "ARABIDOPSIS THALIANA",
	"SamplePoint4": "CAENORHABDITIS ELEGANS",
	"SamplePoint5": "SACCHAROMYCES CEREVISIAE",
}
const STUDIES := {
	"SamplePoint": "NASA OSD-185 - BRIC-21 - ISS",
	"SamplePoint2": "NASA EcAMSat",
	"SamplePoint3": "NASA OSD-37",
	"SamplePoint4": "NASA OSD-42 - STS-116",
	"SamplePoint5": "NASA OSD-58 - STS-135",
}
const MESSAGES := ["PIT BELOW, DON'T FALL"]

const COL_BOX := Color("0a2230")
const COL_EDGE := Color("1d4a5e")
const COL_CYAN := Color("00b8e6")
const COL_TEXT := Color("8fe9ff")
const COL_BRIGHT := Color("e8fbff")

var current_point: Area2D = null
var current_signal: Area2D = null
var collected: Array[String] = []
var decrypted: Array[String] = []
var total := 0
var hold := 0.0
var label: Label
var prompt_box: Panel
var corners: Array[ColorRect] = []
var in_pod := false
var mission_done := false

func _ready() -> void:
	$TabletUI.tablet_toggled.connect($Zayd.set_frozen)
	$TabletUI.tablet_toggled.connect($Anomaly.set_tablet_open)
	$TabletUI.code_accepted.connect($Anomaly.speed_up)
	$TabletUI.code_accepted.connect(_on_message_decrypted)

	$Pod.body_entered.connect(_on_pod_entered)
	$Pod.body_exited.connect(_on_pod_exited)

	var points := get_tree().get_nodes_in_group("sample")
	total = points.size()
	for point in points:
		point.body_entered.connect(_on_sample_entered.bind(point))
		point.body_exited.connect(_on_sample_exited.bind(point))

	for spot in get_tree().get_nodes_in_group("signal"):
		spot.body_entered.connect(_on_signal_entered.bind(spot))
		spot.body_exited.connect(_on_signal_exited.bind(spot))

	_build_prompt()
	_refresh_list()
	_show_idle_text()

# ---------- prompt panel ----------

func _build_prompt() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)

	prompt_box = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_BOX
	sb.bg_color.a = 0.9
	sb.border_color = COL_EDGE
	sb.set_border_width_all(1)
	prompt_box.add_theme_stylebox_override("panel", sb)
	prompt_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_box.visible = false
	layer.add_child(prompt_box)

	for i in 8:
		var c := ColorRect.new()
		c.color = COL_CYAN
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		prompt_box.add_child(c)
		corners.append(c)

	label = Label.new()
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", COL_TEXT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_box.add_child(label)

func _place_corners(sz: Vector2) -> void:
	var n := 10.0
	var t := 2.0
	var spec := [
		[Vector2(0, 0), Vector2(n, t)],
		[Vector2(0, 0), Vector2(t, n)],
		[Vector2(sz.x - n, 0), Vector2(n, t)],
		[Vector2(sz.x - t, 0), Vector2(t, n)],
		[Vector2(0, sz.y - t), Vector2(n, t)],
		[Vector2(0, sz.y - n), Vector2(t, n)],
		[Vector2(sz.x - n, sz.y - t), Vector2(n, t)],
		[Vector2(sz.x - t, sz.y - n), Vector2(t, n)],
	]
	for i in 8:
		corners[i].position = spec[i][0]
		corners[i].size = spec[i][1]

func _say(text: String) -> void:
	label.text = text
	prompt_box.visible = text != ""
	if text == "":
		return
	var ms := label.get_minimum_size()
	var vp := get_viewport().get_visible_rect().size
	var w := ms.x + 56.0
	var h := ms.y + 24.0
	prompt_box.size = Vector2(w, h)
	prompt_box.position = Vector2((vp.x - w) / 2.0, vp.y - 40.0 - h)
	label.position = Vector2(28.0, 12.0)
	_place_corners(Vector2(w, h))

# ---------- tablet log ----------

func _refresh_list() -> void:
	var text := "SAMPLES COLLECTED\n"
	if collected.is_empty():
		text += "-- none yet\n"
	for s in collected:
		text += "-- " + s + "\n"
	text += "\nMESSAGES\n"
	if decrypted.is_empty():
		text += "-- no messages decrypted"
	for m in decrypted:
		text += "-- " + m + "\n"
	$TabletUI.set_sample_list(text)

func _update_tablet_access() -> void:
	$TabletUI.can_decrypt = current_signal != null and not current_signal.has_meta("done")

# ---------- prompts ----------

func _show_idle_text() -> void:
	if mission_done:
		return
	if current_signal != null:
		if current_signal.has_meta("done"):
			_say("No new messages")
		else:
			_say("Incoming message from Nafis - press TAB")
		return
	if in_pod:
		if collected.size() >= total:
			_say("Press E to board the pod")
		else:
			_say("Collect all samples first  (" + str(collected.size()) + " / " + str(total) + ")")
	elif current_point != null:
		if current_point.has_meta("done"):
			var pname := str(current_point.name)
			_say("SAMPLE COLLECTED: " + NAMES.get(pname, "UNKNOWN") + "  (" + STUDIES.get(pname, "") + ")")
		else:
			_say("Hold E to collect sample  (" + str(collected.size()) + " / " + str(total) + ")")
	elif collected.size() >= total:
		_say("ALL SAMPLES COLLECTED - RETURN TO THE POD")
	else:
		_say("")

func _on_pod_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		in_pod = true
		_show_idle_text()

func _on_pod_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		in_pod = false
		_show_idle_text()

func _on_sample_entered(body: Node2D, point: Area2D) -> void:
	if body.is_in_group("player"):
		current_point = point
		_show_idle_text()

func _on_sample_exited(body: Node2D, point: Area2D) -> void:
	if body.is_in_group("player") and current_point == point:
		current_point = null
		_show_idle_text()

func _on_signal_entered(body: Node2D, spot: Area2D) -> void:
	if body.is_in_group("player"):
		current_signal = spot
		var idx := str(spot.name).trim_prefix("SignalSpot").to_int() - 1
		$TabletUI.message_index = idx
		_update_tablet_access()
		_show_idle_text()

func _on_signal_exited(body: Node2D, spot: Area2D) -> void:
	if body.is_in_group("player") and current_signal == spot:
		current_signal = null
		_update_tablet_access()
		_show_idle_text()

func _on_message_decrypted() -> void:
	if current_signal == null:
		return
	current_signal.set_meta("done", true)
	var idx := str(current_signal.name).trim_prefix("SignalSpot").to_int() - 1
	var m: String = MESSAGES[idx] if idx >= 0 and idx < MESSAGES.size() else "UNKNOWN"
	decrypted.append("SIGNAL " + str(idx + 1) + ": " + m)
	for child in current_signal.get_children():
		if child is ColorRect:
			child.color = Color(0.1, 0.3, 0.3, 0.6)
	_update_tablet_access()
	_refresh_list()
	_show_idle_text()

func _input(event: InputEvent) -> void:
	if mission_done:
		if event.is_action_pressed("ui_accept"):
			get_tree().reload_current_scene()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if in_pod and collected.size() >= total and not $Zayd.frozen:
			_complete_mission()

func _process(delta: float) -> void:
	if mission_done:
		return
	var can_collect: bool = current_point != null and not current_point.has_meta("done") and not $Zayd.frozen
	if can_collect and Input.is_key_pressed(KEY_E):
		hold += delta
		var pct := int(clampf(hold / COLLECT_TIME, 0.0, 1.0) * 100.0)
		_say("Collecting sample...  " + str(pct) + "%")
		if hold >= COLLECT_TIME:
			_finish_collect()
	elif hold > 0.0:
		hold = 0.0
		_show_idle_text()

func _finish_collect() -> void:
	hold = 0.0
	current_point.set_meta("done", true)
	var pname := str(current_point.name)
	var n: String = NAMES.get(pname, "UNKNOWN SAMPLE")
	var study: String = STUDIES.get(pname, "")
	collected.append(n + "\n      " + study)
	for child in current_point.get_children():
		if child is ColorRect:
			child.visible = false
	if collected.size() >= total:
		$Anomaly.start_return_mode()
	_refresh_list()
	_show_idle_text()

# ---------- mission complete screen ----------

func _draw_frame_brackets(c: Control) -> void:
	var sz := c.size
	var n := 32.0
	var t := 3.0
	c.draw_rect(Rect2(0, 0, n, t), COL_CYAN)
	c.draw_rect(Rect2(0, 0, t, n), COL_CYAN)
	c.draw_rect(Rect2(sz.x - n, 0, n, t), COL_CYAN)
	c.draw_rect(Rect2(sz.x - t, 0, t, n), COL_CYAN)
	c.draw_rect(Rect2(0, sz.y - t, n, t), COL_CYAN)
	c.draw_rect(Rect2(0, sz.y - n, t, n), COL_CYAN)
	c.draw_rect(Rect2(sz.x - n, sz.y - t, n, t), COL_CYAN)
	c.draw_rect(Rect2(sz.x - t, sz.y - n, t, n), COL_CYAN)

func _complete_mission() -> void:
	mission_done = true
	$Zayd.set_frozen(true)
	$Anomaly.set_physics_process(false)

	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)

	var backdrop := ColorRect.new()
	backdrop.color = Color.BLACK
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)

	var frame := MarginContainer.new()
	frame.add_theme_constant_override("margin_left", 72)
	frame.add_theme_constant_override("margin_right", 72)
	frame.add_theme_constant_override("margin_top", 48)
	frame.add_theme_constant_override("margin_bottom", 48)
	frame.modulate.a = 0.0
	frame.draw.connect(_draw_frame_brackets.bind(frame))
	center.add_child(frame)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	frame.add_child(box)

	var headline := Label.new()
	headline.text = "MISSION COMPLETE"
	headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	headline.add_theme_font_size_override("font_size", 64)
	headline.add_theme_color_override("font_color", COL_CYAN)
	box.add_child(headline)

	var sub := Label.new()
	sub.text = "Press ENTER to play again"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", COL_BRIGHT)
	box.add_child(sub)

	create_tween().tween_property(frame, "modulate:a", 1.0, 1.2)
