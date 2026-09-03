@tool
extends RichTextEffect
class_name TitleTextEffect

var bbcode = "title_wave"

func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	# RichTextEffect is called for every glyph every frame. Unlike the button
	# effect, it must not create a Tween here: a stable time-based target avoids
	# overlapping animations and lets each letter return smoothly to its origin.
	var speed: float = float(char_fx.env.get("speed", 0.55))
	var amplitude: float = float(char_fx.env.get("amplitude", 7.0))
	var character_phase: float = char_fx.relative_index * 0.42
	var time: float = char_fx.elapsed_time * speed

	var vertical_wave := sin(time + character_phase) * amplitude
	var secondary_wave := sin(time * 0.53 + character_phase * 1.7) * amplitude * 0.28
	var horizontal_sway := sin(time * 0.71 + character_phase * 0.65) * 0.9

	char_fx.offset = Vector2(horizontal_sway, vertical_wave + secondary_wave)
	return true
