extends CharacterBody2D

const SPEED := 200.0
const JUMP_VELOCITY := -520.0
const GRAVITY_UP := 2100.0     # while rising and holding jump (max jump about 64 px)
const GRAVITY_DOWN := 600.0    # while falling, or after releasing jump early
const MAX_FALL := 300.0

const FIRST_FRAME := 8         # first picture of the side-view row
const FRAME_COUNT := 8         # walking frames in that row
const ANIM_FPS := 10.0         # walking speed (higher = faster steps)
const AIR_FRAME := 9           # picture shown while in the air

var frozen := false
var shift_was_down := false
var facing := 1.0              # 1 = facing right, -1 = facing left
var anim_time := 0.0
var lamp_x := 0.0

@onready var flashlight: Node2D = $Flashlight
@onready var beam_shape: CollisionPolygon2D = $Flashlight/BeamArea/CollisionPolygon2D
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	lamp_x = absf(flashlight.position.x)
	sprite.frame = FIRST_FRAME
	beam_shape.polygon = PackedVector2Array([
		Vector2(0, 0),
		Vector2(400, -250),
		Vector2(400, 250),
	])

func _physics_process(delta: float) -> void:
	# Shift counts as a jump press only on the frame it goes down
	var shift_down := Input.is_physical_key_pressed(KEY_SHIFT)
	var shift_jump := shift_down and not shift_was_down
	shift_was_down = shift_down

	var jump_held := (Input.is_action_pressed("ui_accept") or shift_down) and not frozen

	if not is_on_floor():
		var rising_and_held := velocity.y < 0.0 and jump_held
		var g := GRAVITY_UP if rising_and_held else GRAVITY_DOWN
		velocity.y = minf(velocity.y + g * delta, MAX_FALL)

	if frozen:
		velocity.x = 0.0
	else:
		var mouse := get_global_mouse_position()
		flashlight.look_at(mouse)
		facing = 1.0 if mouse.x >= global_position.x else -1.0

		var dir := Input.get_axis("ui_left", "ui_right")
		if Input.is_physical_key_pressed(KEY_A):
			dir -= 1.0
		if Input.is_physical_key_pressed(KEY_D):
			dir += 1.0
		velocity.x = clampf(dir, -1.0, 1.0) * SPEED

		var jump_pressed := Input.is_action_just_pressed("ui_accept") or shift_jump
		if jump_pressed and is_on_floor():
			velocity.y = JUMP_VELOCITY

	move_and_slide()
	_update_visuals(delta)

func _update_visuals(delta: float) -> void:
	# face the way the light points, and keep the headlamp on his forehead
	sprite.flip_h = facing < 0.0
	flashlight.position.x = lamp_x * facing

	if not is_on_floor():
		sprite.frame = AIR_FRAME
		return

	if absf(velocity.x) > 1.0:
		# walking backwards (away from where he aims) plays the steps in reverse
		var direction := 1.0 if signf(velocity.x) == facing else -1.0
		anim_time += delta * direction
		var step := int(floor(anim_time * ANIM_FPS))
		sprite.frame = FIRST_FRAME + posmod(step, FRAME_COUNT)
	else:
		anim_time = 0.0
		sprite.frame = FIRST_FRAME

func set_frozen(value: bool) -> void:
	frozen = value
