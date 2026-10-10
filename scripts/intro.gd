extends CanvasLayer

static var shown := false  # remembers the intro was seen, so R / restart skips it

const COL_TEXT := Color("e8fbff")
const COL_DIM := Color("8fe9ff")
const COL_CYAN := Color("00b8e6")

@export var background: Texture2D  # art pass: drag an image here
@export var lines: Array[String] = [
	"The pilgrimage was meant to end at TRAPPIST-1 f.",
	"12.43 parsecs from home. Orbit: 9.2075 days. Radius: 1.045 Earth. Equilibrium temperature: 217.7 K.",
	"Then the crew began to change.",
	"They still walk. They still answer. But the words are fewer each day.",
	"Only Zayd and Nafis are untouched.",
	"There is a month before the Takeover is complete.",
	"The cure is somewhere in the dark below.",
]
@export var line_fade := 1.5
@export var line_hold := 1.5

var labels: Array[Label] = []
var prompt: Label
var frame: MarginContainer
var tween: Tween
var ready_to_start := false

func _ready() -> void:
	if shown:
		queue_free()
		return
	shown = true
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true

	var backdrop := ColorRect.new()
	backdrop.color = Color.BLACK
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var bg := TextureRect.new()
	bg.texture = background
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# frame with cyan corner brackets around the text block
	frame = MarginContainer.new()
	frame.add_theme_constant_override("margin_left", 48)
	frame.add_theme_constant_override("margin_right", 48)
	frame.add_theme_constant_override("margin_top", 36)
	frame.add_theme_constant_override("margin_bottom", 36)
	frame.modulate.a = 0.0
	frame.draw.connect(_draw_brackets)
	center.add_child(frame)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(800, 0)
	box.add_theme_constant_override("separation", 24)
	frame.add_child(box)

	for text in lines:
		var l := Label.new()
		l.text = text
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 28)
		l.add_theme_color_override("font_color", COL_TEXT)
		l.modulate.a = 0.0
		box.add_child(l)
		labels.append(l)

	prompt = Label.new()
	prompt.text = "Press ENTER to begin"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 20)
	prompt.add_theme_color_override("font_color", COL_DIM)
	prompt.modulate.a = 0.0
	box.add_child(prompt)

	tween = create_tween()
	tween.tween_property(frame, "modulate:a", 1.0, 1.0)
	for l in labels:
		tween.tween_property(l, "modulate:a", 1.0, line_fade)
		tween.tween_interval(line_hold)
	tween.tween_callback(_show_prompt)

func _draw_brackets() -> void:
	var sz := frame.size
	var n := 28.0
	var t := 3.0
	frame.draw_rect(Rect2(0, 0, n, t), COL_CYAN)
	frame.draw_rect(Rect2(0, 0, t, n), COL_CYAN)
	frame.draw_rect(Rect2(sz.x - n, 0, n, t), COL_CYAN)
	frame.draw_rect(Rect2(sz.x - t, 0, t, n), COL_CYAN)
	frame.draw_rect(Rect2(0, sz.y - t, n, t), COL_CYAN)
	frame.draw_rect(Rect2(0, sz.y - n, t, n), COL_CYAN)
	frame.draw_rect(Rect2(sz.x - n, sz.y - t, n, t), COL_CYAN)
	frame.draw_rect(Rect2(sz.x - t, sz.y - n, t, n), COL_CYAN)

func _show_prompt() -> void:
	ready_to_start = true
	create_tween().tween_property(prompt, "modulate:a", 0.8, 1.0)

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode != KEY_ENTER and event.keycode != KEY_KP_ENTER:
		return
	get_viewport().set_input_as_handled()
	if ready_to_start:
		get_tree().paused = false
		queue_free()
	else:
		# first Enter skips the fade and shows everything
		tween.kill()
		frame.modulate.a = 1.0
		for l in labels:
			l.modulate.a = 1.0
		_show_prompt()
