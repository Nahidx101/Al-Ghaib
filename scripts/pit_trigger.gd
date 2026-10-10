extends Area2D

const FALL_DAMAGE := 40.0
var used := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if used:
		return
	if body.is_in_group("player"):
		used = true
		get_tree().current_scene.get_node("HUD").damage(FALL_DAMAGE)
