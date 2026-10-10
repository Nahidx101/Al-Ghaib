extends PointLight2D

func _ready() -> void:
	var size := 512
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size / 2.0, size / 2.0)
	var half_angle := deg_to_rad(35.0)
	for x in size:
		for y in size:
			var d := Vector2(x, y) - center
			var dist := d.length() / (size / 2.0)
			var angle := absf(d.angle())
			var v := 0.0
			if dist < 1.0 and angle < half_angle:
				# curved falloff: strong near the torch, long soft tail
				var along := pow(1.0 - dist, 1.7)
				# soft sides: fades smoothly toward the edge of the cone
				var side := smoothstep(0.0, 1.0, 1.0 - angle / half_angle)
				v = along * side
			img.set_pixel(x, y, Color(v, v, v, 1.0))
	texture = ImageTexture.create_from_image(img)
