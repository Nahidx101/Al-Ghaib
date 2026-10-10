extends CanvasLayer

const COL_RED := Color("ff4d4d")
const COL_TEXT := Color("e8fbff")

var active := false
var frame: MarginContainer

func _ready() -> void:
	hide()
	# hide the old plain label from the scene, the styled one is built here
	var old := get_node_or_null("Backdrop/Message")
	if old != null:
		old.visible = false

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	frame = MarginContainer.new()
	frame.add_theme_constant_override("margin_left", 72)
	frame.add_theme_constant_override("margin_right", 72)
	frame.add_theme_constant_override("margin_top", 48)
	frame.add_theme_constant_override("margin_bottom", 48)
	frame.modulate.a = 0.0
	frame.draw.connect(_draw_brackets)
	center.add_child(frame)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	frame.add_child(box)

	var title := Label.new()
	title.text = "SIGNAL LOST"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", COL_RED)
	box.add_child(title)

	var sub := Label.new()
	sub.text = "Press ENTER to try again"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", COL_TEXT)
	box.add_child(sub)

func _draw_brackets() -> void:
	var sz := frame.size
	var n := 32.0
	var t := 3.0
	frame.draw_rect(Rect2(0, 0, n, t), COL_RED)
	frame.draw_rect(Rect2(0, 0, t, n), COL_RED)
	frame.draw_rect(Rect2(sz.x - n, 0, n, t), COL_RED)
	frame.draw_rect(Rect2(sz.x - t, 0, t, n), COL_RED)
	frame.draw_rect(Rect2(0, sz.y - t, n, t), COL_RED)
	frame.draw_rect(Rect2(0, sz.y - n, t, n), COL_RED)
	frame.draw_rect(Rect2(sz.x - n, sz.y - t, n, t), COL_RED)
	frame.draw_rect(Rect2(sz.x - t, sz.y - n, t, n), COL_RED)

func show_game_over() -> void:
	active = true
	show()
	get_tree().paused = true
	frame.modulate.a = 0.0
	create_tween().tween_property(frame, "modulate:a", 1.0, 1.2)

func _input(event: InputEvent) -> void:
	if active and event.is_action_pressed("ui_accept"):
		get_tree().paused = false
		get_tree().reload_current_scene()
