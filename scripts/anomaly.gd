extends Area2D

@export var chase_speed := 150.0
@export var retreat_speed := 400.0
@export var retreat_time := 1.5
@export var hover_distance := 180.0
@export var speed_boost := 40.0
@export var orbit_speed := 1.6
@export var safe_angle := 55.0
@export var return_speed_bonus := 60.0
@export var return_orbit_factor := 0.5
@export var show_box := false  # tick in the Inspector to see the red box again for testing

var target: Node2D
var beam: Area2D
var flashlight: Node2D
var retreat_left := 0.0
var tablet_open := false
var caught := false
var return_mode := false
var shimmer: CPUParticles2D
var shimmer_cd := 0.0

func _ready() -> void:
	target = get_tree().get_first_node_in_group("player")
	flashlight = target.get_node("Flashlight")
	beam = target.get_node("Flashlight/BeamArea")

	for child in get_children():
		if child is ColorRect:
			child.visible = show_box

	_build_shimmer()

func _build_shimmer() -> void:
	shimmer = CPUParticles2D.new()
	shimmer.emitting = false
	shimmer.one_shot = true
	shimmer.amount = 14
	shimmer.lifetime = 0.8
	shimmer.explosiveness = 0.6
	shimmer.local_coords = false
	shimmer.direction = Vector2(0, -1)
	shimmer.spread = 180.0
	shimmer.initial_velocity_min = 8.0
	shimmer.initial_velocity_max = 34.0
	shimmer.gravity = Vector2(0, 14)
	shimmer.scale_amount_min = 1.5
	shimmer.scale_amount_max = 3.0
	var g := Gradient.new()
	g.set_color(0, Color(0.9, 0.98, 1.0, 0.9))
	g.set_color(1, Color(0.6, 0.85, 1.0, 0.0))
	shimmer.color_ramp = g
	add_child(shimmer)

func set_tablet_open(value: bool) -> void:
	tablet_open = value
	if value:
		retreat_left = 0.0

func speed_up() -> void:
	chase_speed += speed_boost

func start_return_mode() -> void:
	if return_mode:
		return
	return_mode = true
	chase_speed += return_speed_bonus
	orbit_speed *= return_orbit_factor

func _physics_process(delta: float) -> void:
	if target == null or caught:
		return

	if not tablet_open and beam.overlaps_area(self):
		retreat_left = retreat_time
		shimmer_cd -= delta
		if shimmer_cd <= 0.0:
			shimmer.restart()
			shimmer_cd = 0.4

	if retreat_left > 0.0:
		retreat_left -= delta
		var away := target.global_position.direction_to(global_position)
		global_position += away * retreat_speed * delta
		return

	var offset := global_position - target.global_position
	var distance := offset.length()

	if tablet_open:
		var toward := global_position.direction_to(target.global_position)
		global_position += toward * chase_speed * delta
		if overlaps_body(target):
			caught = true
			get_tree().current_scene.get_node("TabletUI").freeze()
		return

	# Tablet closed: stay out of the light by circling around Zayd
	if distance > hover_distance + 10.0:
		var toward := global_position.direction_to(target.global_position)
		global_position += toward * chase_speed * delta

	var beam_angle := flashlight.global_rotation
	var my_angle := offset.angle()
	var diff := angle_difference(beam_angle, my_angle)
	if absf(diff) < deg_to_rad(safe_angle):
		var side := 1.0 if diff >= 0.0 else -1.0
		var new_angle := my_angle + side * orbit_speed * delta
		global_position = target.global_position + Vector2.RIGHT.rotated(new_angle) * distance
